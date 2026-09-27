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

    // nil indtil scoren kan regnes ud. hele TranceSessionScores i @State crashede appen på iOS 27.2,
    // når sessionen blev vist, så der gemmes kun små værdier
    @State private var afslapningsscore: Double?
    @State private var fokusscore: Double?

    private var afslapning: Double { afslapningsscore ?? 0.7 }

    private var fokus: Double { fokusscore ?? 0.7 }

    // bruges indtil HealthKit har en pulsmåling
    @State private var bpm = 60.0
    @State private var afslapningSamples: [Double] = []
    @State private var resultat: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let resultat {
                // samme gradient som på Hjem, så man lander blødt tilbage, når man trykker Færdig
                MeshBackground()
                    // starter forstørret, så farverne glider ind fra kanten mod teksten
                    .transition(.scale(1.4, anchor: UnitPoint(x: 0.5, y: 0.44)).combined(with: .opacity))

                SessionSummaryView(relaxation: resultat)
                    .padding(.horizontal, 32)
                    // samme sted som prikken
                    .padding(.bottom, 128)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        Button("Færdig", action: onFinish)
                            .buttonStyle(.glassProminent)
                            .controlSize(.extraLarge)
                            .font(.headline)
                            // fylder hele bredden
                            .buttonSizing(.flexible)
                            .padding(.horizontal)
                    }
            } else {
                RelaxationBorder(score: afslapning, bpm: bpm)
                    .ignoresSafeArea()
                    // kanten trækker sig ind og bliver sløret, mens gradienten kommer frem
                    .transition(.blurReplace(.downUp))

                Circle()
                    .frame(width: 16, height: 16)
                    .padding(.bottom, 128)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // prikken forsvinder hurtigt, så den ikke ligger oven på teksten der kommer frem
                    .transition(.opacity.animation(.smooth(duration: 0.25)))
                    .persistentSystemOverlays(.hidden)
                    // skærmen skal ikke låse, man skal fokusere ikke pille ved skærmen
                    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
                    // når tiden er gået, vis resume
                    .task {
                        try? await Task.sleep(for: duration)
                        afslapningSamples.append(afslapning)
                        withAnimation(reduceMotion ? nil : .spring(duration: 1.2, bounce: 0)) {
                            resultat = afslapningSamples.reduce(0, +) / Double(afslapningSamples.count)
                        }
                    }
                    // scoren regnes ud i c++; her startes den, og pulsen og scoren hentes hvert 5. sekund
                    .task {
                        let start = Date().timeIntervalSince1970
                        var afslapningKalibreret = false
                        clearScoreCalibration()
                        // prikken sidder lige under kameraet, så blikket tæller som fokus inden for 20° af kameraet
                        configureFocusScore(target: TranceVector3(), toleranceDegrees: 20)
                        startScoreSession()
                        // uret måler kun pulsen ofte nok til scoren, mens det kører en workout
                        SensorAccess.startWatchPulse()
                        defer {
                            stopScoreSession()
                            SensorAccess.stopWatchPulse()
                        }
                        while !Task.isCancelled {
                            let heartRate = copySensorSnapshot().heartRate
                            if heartRate.available, heartRate.bpm > 0 { bpm = heartRate.bpm }
                            // den første måling fra sessionen er udgangspunktet, og 10 % lavere puls er helt afslappet
                            if !afslapningKalibreret, heartRate.available, heartRate.timestamp >= start {
                                afslapningKalibreret = configureRelaxationScore(
                                    startBpm: heartRate.bpm, relaxedBpm: heartRate.bpm * 0.9)
                            }
                            let scores = copySessionScores()
                            afslapningsscore = scores.afslapningsscore.available ? scores.afslapningsscore.value : nil
                            fokusscore = scores.fokusscore.available ? scores.fokusscore.value : nil
                            afslapningSamples.append(afslapning)
                            try? await Task.sleep(for: .seconds(5))
                        }
                    }
            }
        }
        .statusBarHidden()
        // haptic feedback når tiden er gået
        .sensoryFeedback(.impact(flexibility: .soft), trigger: resultat)
    }
}

#Preview {
    SessionView(duration: .seconds(2)) {}
}
