//
//  TranceWatchApp.swift
//  TranceWatch
//

@preconcurrency import HealthKit
import SwiftUI
import WatchKit

@main
struct TranceWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchDelegate

    var body: some Scene {
        WindowGroup {
            WatchView()
        }
    }
}

/// iPhonen starter appen på uret med en workout, når en session begynder.
final class WatchDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        WorkoutPulse.shared.start(workoutConfiguration)
    }
}

struct WatchView: View {
    private let pulse = WorkoutPulse.shared

    var body: some View {
        VStack(spacing: 8) {
            if pulse.running {
                Text(pulse.bpm.map { "\(Int($0.rounded())) BPM" } ?? "Måler puls…")
                    .font(.title2.bold())
                Button("Stop", role: .destructive) { pulse.stop() }
            } else {
                Text("Start en session på din iPhone")
                    .multilineTextAlignment(.center)
            }
        }
        // spørg om adgang første gang appen åbnes, så uret kan måle når iPhonen starter den i baggrunden
        .task { await pulse.requestAccess() }
    }
}

#Preview {
    WatchView()
}
