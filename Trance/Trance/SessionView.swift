//
//  SessionView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//

import SwiftUI

struct SessionView: View {
    let duration: Duration
    @Environment(\.dismiss) private var dismiss

    // hardcodet indtil scoren kommer fra sensorerne
    private let relaxation = 0.7
    // bruges indtil HealthKit har en pulsmåling
    @State private var bpm = 60.0

    var body: some View {
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
            .task {
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                dismiss()
            }
            .task {
                // pulsen fra HealthKit skifter sjældent, så det er nok at kigge hvert 5. sekund
                while !Task.isCancelled {
                    let heartRate = copySensorSnapshot().heartRate
                    if heartRate.available, heartRate.bpm > 0 { bpm = heartRate.bpm }
                    try? await Task.sleep(for: .seconds(5))
                }
            }
    }
}

#Preview {
    SessionView(duration: .seconds(60))
}
