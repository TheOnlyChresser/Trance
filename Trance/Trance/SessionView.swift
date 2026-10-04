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
    @State private var focusPoint: CGPoint?

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
                    // prikken vokser i 4 sekunder, mens man ånder ind, og krymper i 6 sekunder, mens man ånder ud
                    .phaseAnimator([false, true]) { dot, indaending in
                        dot.scaleEffect(indaending ? 2.5 : 1)
                    } animation: { indaending in
                        .easeInOut(duration: indaending ? 4 : 6)
                    }
                    .onGeometryChange(for: CGPoint.self) { geometry in
                        let frame = geometry.frame(in: .global)

                        return CGPoint(x: frame.midX, y: frame.midY)
                    } action: { point in
                        focusPoint = point
                    }
                    .onChange(of: focusPoint) { _, _ in configureScreenFocus() }
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
                        clearScoreCalibration()
                        configureScreenFocus()
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

    private func configureScreenFocus() {
        #if os(iOS)
        let screen = copyCalibratedScreen()
        guard screen.available, let focusPoint else { return }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
        guard let scene else { return }

        let bounds = scene.screen.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let scaleX = Double(screen.pixelWidth - 1) / Double(bounds.width)
        let scaleY = Double(screen.pixelHeight - 1) / Double(bounds.height)

        let x = Double(focusPoint.x - bounds.minX) * scaleX
        let y = Double(focusPoint.y - bounds.minY) * scaleY

        configureFocusScore(x: x, y: y, radius: 32 * scaleX)
        #endif
    }
}

#Preview {
    SessionView(duration: .seconds(2)) {}
}
