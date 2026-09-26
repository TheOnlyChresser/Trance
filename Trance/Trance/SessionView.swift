//
//  SessionView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//

import SwiftUI

struct SessionView: View {
    let duration: Duration
    let onFinish: () -> Void

    // hardcodet indtil scoren kommer fra sensorerne
    private let relaxation = 0.7
    // bruges indtil HealthKit har en pulsmåling
    @State private var bpm = 60.0
    @State private var relaxationSamples: [Double] = []
    @State private var result: Double?

    var body: some View {
        Group {
            if let result {
                SessionSummaryView(relaxation: result, onDone: onFinish)
            } else {
                Circle()
                    .frame(width: 16, height: 16)
                    .padding(.bottom, 128)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        RelaxationBorder(score: relaxation, bpm: bpm)
                            .ignoresSafeArea()
                    }
                    .statusBarHidden()
                    .persistentSystemOverlays(.hidden)
                    // skærmen skal ikke låse, man skal fokusere ikke pille ved skærmen
                    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
                    // når tiden er gået, vis resume
                    .task {
                        try? await Task.sleep(for: duration)
                        relaxationSamples.append(relaxation)
                        result = relaxationSamples.reduce(0, +) / Double(relaxationSamples.count)
                    }
                    // pulsen fra HealthKit skifter sjældent, så det er nok at kigge hvert 5. sekund
                    .task {
                        while !Task.isCancelled {
                            let heartRate = copySensorSnapshot().heartRate
                            if heartRate.available, heartRate.bpm > 0 { bpm = heartRate.bpm }
                            relaxationSamples.append(relaxation)
                            try? await Task.sleep(for: .seconds(5))
                        }
                    }
            }
        }
        // haptic feedback når tiden er gået
        .sensoryFeedback(.impact(flexibility: .soft), trigger: result)
    }
}

#Preview {
    SessionView(duration: .seconds(60)) {}
}
