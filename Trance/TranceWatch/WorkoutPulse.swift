//
//  WorkoutPulse.swift
//  TranceWatch
//

import Foundation
@preconcurrency import HealthKit
import Observation
@preconcurrency import WatchConnectivity

/// Kører en workout under sessionen, så uret måler pulsen med få sekunders mellemrum
/// i stedet for hvert par minutter, og sender hver måling til iPhonen.
@Observable
final class WorkoutPulse: NSObject {
    static let shared = WorkoutPulse()

    private(set) var running = false
    private(set) var bpm: Double?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var lastAnswer = Date.distantPast
    @ObservationIgnored private var watchdog: Task<Void, Never>?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func requestAccess() async {
        do {
            try await store.requestAuthorization(
                toShare: [HKObjectType.workoutType()], read: [HKQuantityType(.heartRate)])
        } catch {
            print("Trance Watch HealthKit authorization: \(error)")
        }
    }

    func start(_ configuration: HKWorkoutConfiguration) {
        guard session == nil else { return }
        let session: HKWorkoutSession
        do {
            session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        } catch {
            print("Trance Watch workout: \(error)")
            return
        }
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: store, workoutConfiguration: configuration)
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        running = true
        lastAnswer = .now

        Task {
            await requestAccess()
            guard self.session === session else { return }
            let start = Date()
            session.startActivity(with: start)
            do {
                try await builder.beginCollection(at: start)
            } catch {
                print("Trance Watch workout: \(error)")
                stop()
            }
        }
        // iPhonen svarer på hver måling; hører uret ikke fra den i et minut, stopper workouten
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard let self, self.running else { return }
                if Date.now.timeIntervalSince(self.lastAnswer) > 60 { self.stop() }
            }
        }
    }

    func stop() {
        guard let session else { return }
        if session.state == .notStarted || session.state == .ended {
            reset()
        } else {
            // resten sker i workoutSession(_:didChangeTo:from:date:)
            session.end()
        }
    }

    private func finish(_ id: ObjectIdentifier, at date: Date) {
        guard let session, ObjectIdentifier(session) == id, let builder else { return }
        reset()
        Task {
            // Trance bruger kun pulsen, så workouten gemmes ikke i Fitness
            try? await builder.endCollection(at: date)
            builder.discardWorkout()
        }
    }

    private func reset() {
        watchdog?.cancel()
        watchdog = nil
        session = nil
        builder = nil
        running = false
        bpm = nil
    }

    private func send(bpm: Double, time: Double) {
        guard running else { return }
        self.bpm = bpm
        let phone = WCSession.default
        guard phone.activationState == .activated, phone.isReachable else { return }
        phone.sendMessage(
            ["bpm": bpm, "tid": time],
            replyHandler: { @Sendable [weak self] answer in
                let keepGoing = answer["fortsæt"] as? Bool ?? false
                DispatchQueue.main.async { self?.answered(keepGoing) }
            },
            errorHandler: { @Sendable error in print("Trance Watch: \(error)") })
    }

    private func answered(_ keepGoing: Bool) {
        guard running else { return }
        if keepGoing { lastAnswer = .now } else { stop() }
    }
}

extension WorkoutPulse: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState, date: Date
    ) {
        guard toState == .ended else { return }
        let id = ObjectIdentifier(workoutSession)
        DispatchQueue.main.async { [weak self] in self?.finish(id, at: date) }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Trance Watch workout: \(error)")
        DispatchQueue.main.async { [weak self] in self?.stop() }
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let type = HKQuantityType(.heartRate)
        guard collectedTypes.contains(type),
            let statistics = workoutBuilder.statistics(for: type),
            let quantity = statistics.mostRecentQuantity(),
            let interval = statistics.mostRecentQuantityDateInterval()
        else { return }
        let bpm = quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        let time = interval.end.timeIntervalSince1970
        DispatchQueue.main.async { [weak self] in self?.send(bpm: bpm, time: time) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}

extension WorkoutPulse: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        if let error { print("Trance Watch WatchConnectivity: \(error)") }
    }
}
