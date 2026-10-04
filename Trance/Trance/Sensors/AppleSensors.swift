import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
    @preconcurrency import HealthKit
    @preconcurrency import ARKit
    @preconcurrency import AVFoundation
    @preconcurrency import WatchConnectivity

    @MainActor
    private final class AppleSensorReader: NSObject, ARSessionDelegate, WCSessionDelegate {
        private var running = false
        private var healthStore: HKHealthStore?
        private var observer: HKObserverQuery?
        private var pendingQueries: [Int: HKSampleQuery] = [:]
        private var requestNumber = 0
        private var faceSession: ARSession?
        private var lastPulse = TranceHeartRate()
        private var faceAvailable = false
        private var hardware = TranceHardware()
        private var watchPulse = false

        func start() {
            running = true
            hardware.healthKit = HKHealthStore.isHealthDataAvailable()
            hardware.faceTracking = ARFaceTrackingConfiguration.isSupported
            hardware.trueDepthCamera =
                AVCaptureDevice.default(
                    .builtInTrueDepthCamera, for: .video, position: .front) != nil
            updateHardware(hardware)
            updateHeartRate(TranceHeartRate())
            updateFace(TranceFaceData())

            if WCSession.isSupported() {
                WCSession.default.delegate = self
                WCSession.default.activate()
            }
            if hardware.healthKit {
                let store = HKHealthStore()
                healthStore = store
                let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                store.requestAuthorization(toShare: [], read: [type]) {
                    [weak self] success, error in
                    DispatchQueue.main.async {
                        guard let self, self.running else { return }
                        guard success else {
                            print("Trance HealthKit authorization: \(String(describing: error))")
                            return
                        }
                        self.observePulse(type)
                    }
                }
            }
            if hardware.faceTracking {
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self, self.running, granted else { return }
                        let session = ARSession()
                        self.faceSession = session
                        session.delegate = self
                        session.delegateQueue = .main
                        session.run(ARFaceTrackingConfiguration())
                    }
                }
            }
        }

        private func observePulse(_ type: HKQuantityType) {
            let query = HKObserverQuery(sampleType: type, predicate: nil) {
                [weak self] _, done, error in
                DispatchQueue.main.async {
                    defer { done() }
                    guard let self, self.running else { return }
                    if let error {
                        print("Trance HealthKit observer: \(error)")
                        return
                    }
                    self.readPulse(type)
                }
            }
            observer = query
            healthStore?.execute(query)
            readPulse(type)
        }

        private func readPulse(_ type: HKQuantityType) {
            requestNumber += 1
            let request = requestNumber
            let query = HKSampleQuery(
                sampleType: type, predicate: nil, limit: 1,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                ]
            ) {
                [weak self] _, samples, error in
                var value = TranceHeartRate()
                if error == nil, let sample = samples?.first as? HKQuantitySample {
                    value.available = true
                    value.bpm = sample.quantity.doubleValue(
                        for: HKUnit.count().unitDivided(by: .minute()))
                    value.timestamp = sample.endDate.timeIntervalSince1970
                }
                let copy = value
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.pendingQueries.removeValue(forKey: request)
                    guard self.running, request == self.requestNumber else { return }
                    if let error { print("Trance HealthKit: \(error)") }
                    self.publishPulse(copy)
                }
            }
            pendingQueries[request] = query
            healthStore?.execute(query)
        }

        // pulsen kommer både fra HealthKit og direkte fra uret, så kun nyere målinger bruges
        private func publishPulse(_ value: TranceHeartRate) {
            guard value.timestamp > lastPulse.timestamp else { return }
            lastPulse = value
            updateHeartRate(value)
        }

        func startWatchPulse() {
            watchPulse = true
            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .mindAndBody
            configuration.locationType = .indoor
            healthStore?.startWatchApp(with: configuration) { _, error in
                if let error { print("Trance Watch workout: \(error)") }
            }
        }

        // uret får svaret ved sin næste måling og stopper så selv sin workout
        func stopWatchPulse() {
            watchPulse = false
        }

        private func receiveWatchPulse(bpm: Double, time: Double) -> Bool {
            guard running, watchPulse else { return false }
            if bpm > 0 {
                // urets ur kan gå en smule foran, og scoren tæller ikke målinger fra fremtiden
                let now = Date().timeIntervalSince1970
                publishPulse(TranceHeartRate(available: true, bpm: bpm, timestamp: min(time, now)))
            }
            return true
        }

        func stop() {
            running = false
            if let observer { healthStore?.stop(observer) }
            for query in pendingQueries.values { healthStore?.stop(query) }
            pendingQueries.removeAll()
            observer = nil
            faceSession?.pause()
            faceSession?.delegate = nil
            faceSession = nil
            if WCSession.isSupported(), WCSession.default.delegate === self {
                WCSession.default.delegate = nil
            }
            updateHeartRate(TranceHeartRate())
            updateFace(TranceFaceData())
        }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            var value = TranceFaceData()
            if let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first(where: {
                $0.isTracked
            }) {
                value.available = true
                value.timestamp =
                    Date().timeIntervalSince1970
                    - (ProcessInfo.processInfo.systemUptime - frame.timestamp)
                let head = simd_inverse(frame.camera.transform) * face.transform
                let left = head * face.leftEyeTransform
                let right = head * face.rightEyeTransform
                value.leftEyeOrigin = Self.vector3(left.columns.3)
                value.rightEyeOrigin = Self.vector3(right.columns.3)
                value.leftEyeDirection = Self.vector3(left.columns.2)
                value.rightEyeDirection = Self.vector3(right.columns.2)
                value.leftEyeTransform = Self.matrix4(left)
                value.rightEyeTransform = Self.matrix4(right)
                value.leftEyeClosure = face.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
                value.rightEyeClosure = face.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
                value.headTransform = TranceMatrix4(
                    c0: Self.vector4(head.columns.0), c1: Self.vector4(head.columns.1),
                    c2: Self.vector4(head.columns.2), c3: Self.vector4(head.columns.3))
            }
            let copy = value
            DispatchQueue.main.async { [weak self] in
                guard let self, self.running else { return }
                if copy.available || self.faceAvailable {
                    self.faceAvailable = copy.available
                    updateFace(copy)
                }
            }
        }
        nonisolated private static func vector3(_ v: SIMD4<Float>) -> TranceVector3 {
            TranceVector3(x: v.x, y: v.y, z: v.z)
        }
        nonisolated private static func matrix4(_ value: simd_float4x4) -> TranceMatrix4 {
            TranceMatrix4(
                c0: vector4(value.columns.0), c1: vector4(value.columns.1),
                c2: vector4(value.columns.2), c3: vector4(value.columns.3))
        }
        nonisolated private static func vector4(_ v: SIMD4<Float>) -> TranceVector4 {
            TranceVector4(x: v.x, y: v.y, z: v.z, w: v.w)
        }
        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.running else { return }
                self.faceAvailable = false
                updateFace(TranceFaceData())
            }
        }
        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.running else { return }
                self.faceSession?.run(
                    ARFaceTrackingConfiguration(),
                    options: [.resetTracking, .removeExistingAnchors])
            }
        }
        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            print("Trance ARKit: \(error)")
            sessionWasInterrupted(session)
        }
        nonisolated private func publishWatchPairing(_ paired: Bool) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.running else { return }
                self.hardware.watchPaired = paired
                updateHardware(self.hardware)
            }
        }
        nonisolated func session(
            _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
            error: Error?
        ) {
            if let error { print("Trance WatchConnectivity: \(error)") }
            publishWatchPairing(state == .activated && session.isPaired)
        }
        nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
            publishWatchPairing(session.isPaired)
        }
        nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
            publishWatchPairing(false)
        }
        nonisolated func session(
            _ session: WCSession, didReceiveMessage message: [String: Any],
            replyHandler: @escaping ([String: Any]) -> Void
        ) {
            let bpm = message["bpm"] as? Double ?? 0
            let time = message["tid"] as? Double ?? 0
            DispatchQueue.main.async { [weak self] in
                replyHandler(["fortsæt": self?.receiveWatchPulse(bpm: bpm, time: time) ?? false])
            }
        }
        nonisolated func sessionDidDeactivate(_ session: WCSession) {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.running else { return }
                WCSession.default.activate()
            }
        }
    }
#endif

@MainActor
enum SensorAccess {
    #if os(iOS) && !targetEnvironment(macCatalyst)
        private static var reader: AppleSensorReader?
        // overlever at appen er i baggrunden midt i en session
        private static var watchPulse = false
    #endif
    static func start() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
            guard reader == nil else { return }
            let source = AppleSensorReader()
            reader = source
            source.start()
            if watchPulse { source.startWatchPulse() }
        #else
            updateHardware(TranceHardware())
            updateHeartRate(TranceHeartRate())
            updateFace(TranceFaceData())
        #endif
    }
    static func stop() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
            reader?.stop()
            reader = nil
        #endif
    }
    static func startWatchPulse() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
            watchPulse = true
            reader?.startWatchPulse()
        #endif
    }
    static func stopWatchPulse() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
            watchPulse = false
            reader?.stopWatchPulse()
        #endif
    }
}
