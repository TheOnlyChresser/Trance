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
                    if copy.available != self.lastPulse.available || copy.bpm != self.lastPulse.bpm
                        || copy.timestamp != self.lastPulse.timestamp
                    {
                        self.lastPulse = copy
                        updateHeartRate(copy)
                    }
                }
            }
            pendingQueries[request] = query
            healthStore?.execute(query)
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
    #endif
    static func start() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
            guard reader == nil else { return }
            let source = AppleSensorReader()
            reader = source
            source.start()
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
}
