//
//  RelaxationBorder.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//

import SwiftUI

struct RelaxationBorder: View {
    let score: Double
    let bpm: Double

    @State private var level = 0.0
    @State private var beats = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        KeyframeAnimator(initialValue: 0.0, trigger: beats) { pulse in
            // Med bevægelse blinker kanten i stedet for at vokse. se animatios.dev
            LevelBorder(level: level, pulse: reduceMotion ? 0 : pulse)
                .opacity(reduceMotion ? 0.7 + 0.3 * pulse : 1)
        } keyframes: { _ in
            // normalt hjerteslag; et kraftigt slag og et mindre lige efter, så hvile til næste slag.
            LinearKeyframe(1, duration: 0.08, timingCurve: easeOut)
            LinearKeyframe(0.3, duration: 0.14, timingCurve: easeOut)
            LinearKeyframe(0.6, duration: 0.08, timingCurve: easeOut)
            LinearKeyframe(0, duration: 0.3, timingCurve: easeOut)
        }
        .onChange(of: score, initial: true) {
            withAnimation(reduceMotion ? nil : .spring(duration: 1.2, bounce: 0)) {
                level = score
            }
        }
        .task(id: bpm) {
            guard bpm > 0 else { return }
            let interval = Duration.seconds(60 / bpm)
            var next = ContinuousClock.now
            while !Task.isCancelled {
                next += interval
                try? await Task.sleep(until: next)
                beats += 1
            }
        }
    }
}

private let easeOut = UnitCurve.bezier(
    startControlPoint: UnitPoint(x: 0.23, y: 1), endControlPoint: UnitPoint(x: 0.32, y: 1))

@Animatable
private struct LevelBorder: View {
    var level: Double
    @AnimatableIgnored var pulse: Double

    var body: some View {
        let color = Color(hue: 0.08 + 0.42 * level, saturation: 0.65, brightness: 0.85)
        ConcentricRectangle()
            .stroke(color, lineWidth: 1 + 12 * level + 6 * pulse)
            .shadow(color: color, radius: 12)
    }
}

#Preview {
    RelaxationBorder(score: 0.7, bpm: 60)
        .ignoresSafeArea()
}
