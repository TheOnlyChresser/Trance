import Foundation

public nonisolated struct TranceVector3: Sendable {
    public var x: Float = 0, y: Float = 0, z: Float = 0
}
public nonisolated struct TranceVector4: Sendable {
    public var x: Float = 0, y: Float = 0, z: Float = 0, w: Float = 0
}
public nonisolated struct TranceMatrix4: Sendable {
    public var c0 = TranceVector4(), c1 = TranceVector4()
    public var c2 = TranceVector4(), c3 = TranceVector4()
}
public nonisolated struct TranceHeartRate: Sendable {
    public var available = false
    public var bpm: Double = 0
    public var timestamp: Double = 0
}
public nonisolated struct TranceFaceData: Sendable {
    public var available = false
    public var timestamp: Double = 0
    public var leftEyeOrigin = TranceVector3(), rightEyeOrigin = TranceVector3()
    public var leftEyeDirection = TranceVector3(), rightEyeDirection = TranceVector3()
    public var leftEyeClosure: Float = 0, rightEyeClosure: Float = 0
    public var headTransform = TranceMatrix4()
    public var focusPoint = TranceVector3()
}
public nonisolated struct TranceHardware: Sendable {
    public var healthKit = false, faceTracking = false
    public var trueDepthCamera = false, watchPaired = false
}
public nonisolated struct SensorSnapshot: Sendable {
    public var heartRate = TranceHeartRate()
    public var face = TranceFaceData()
    public var hardware = TranceHardware()
}

private nonisolated final class SensorStore: @unchecked Sendable {
    private let lock = NSLock()
    private var latest = SensorSnapshot()

    func copy() -> SensorSnapshot { lock.withLock { latest } }
    func update(_ change: (inout SensorSnapshot) -> Void) {
        lock.withLock { change(&latest) }
    }
}
private nonisolated let sensorStore = SensorStore()

public nonisolated func copySensorSnapshot() -> SensorSnapshot { sensorStore.copy() }

public nonisolated func receiveFokusPunkt(_ x: Float, _ y: Float, _ z: Float) {
    sensorStore.update { snapshot in snapshot.face.focusPoint = TranceVector3(x: x, y: y, z: z) }
}

@MainActor func updateHeartRate(_ value: TranceHeartRate) {
    sensorStore.update { $0.heartRate = value }
    updateScoreHeartRate(value)
    trance.sensorDataChanged(.heartRate)
}
@MainActor func updateFace(_ value: TranceFaceData) {
    sensorStore.update { $0.face = value }
    updateScoreFace(value)
    trance.sensorDataChanged(.face)
}
@MainActor func updateHardware(_ value: TranceHardware) {
    sensorStore.update { $0.hardware = value }
    trance.sensorDataChanged(.hardware)
}
