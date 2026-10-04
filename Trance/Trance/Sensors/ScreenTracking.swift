import Foundation

public nonisolated struct TranceScreenHit: Sendable {
    public var available = false
    public var onScreen = false
    public var x: Double = 0, y: Double = 0
    public var column: Int = -1, row: Int = -1
    public var position = TranceVector3()
}

public nonisolated struct TranceScreenPlane: Sendable {
    public var available = false
    public var topLeft = TranceVector3()
    public var horizontal = TranceVector3(), vertical = TranceVector3()
    public var pixelWidth: Int = 0, pixelHeight: Int = 0
    public var calibrationError: Double = 0
}

public nonisolated struct TranceScreenGaze: Sendable {
    public var timestamp: Double = 0
    public var leftEye = TranceScreenHit(), rightEye = TranceScreenHit()
    public var combined = TranceScreenHit()
    public var screenInLeftEye = TranceScreenPlane(), screenInRightEye = TranceScreenPlane()
}

public nonisolated func copyScreenGaze() -> TranceScreenGaze {
    let gaze = trance.copyScreenGaze(Date().timeIntervalSince1970)
    return TranceScreenGaze(
        timestamp: gaze.timestamp,
        leftEye: screenHit(gaze.leftEye), rightEye: screenHit(gaze.rightEye),
        combined: screenHit(gaze.combined),
        screenInLeftEye: screenPlane(gaze.screenInLeftEye),
        screenInRightEye: screenPlane(gaze.screenInRightEye))
}

public nonisolated func copyCalibratedScreen() -> TranceScreenPlane {
    screenPlane(trance.copyCalibratedScreen())
}

nonisolated func updateScreenTracking(_ face: TranceFaceData) {
    trance.recordScreenGaze(eyeTrackingSample(face), Date().timeIntervalSince1970)
}

nonisolated func eyeTrackingSample(_ face: TranceFaceData) -> trance.EyeTrackingSample {
    var sample = trance.EyeTrackingSample()
    sample.available = face.available
    sample.timestamp = face.timestamp
    sample.leftEyeClosure = Double(face.leftEyeClosure)
    sample.rightEyeClosure = Double(face.rightEyeClosure)
    sample.leftEye = eyePose(face.leftEyeTransform)
    sample.rightEye = eyePose(face.rightEyeTransform)
    return sample
}

private nonisolated func eyePose(_ transform: TranceMatrix4) -> trance.EyePose {
    var pose = trance.EyePose()
    pose.origin = screenVector(transform.c3)
    pose.xAxis = screenVector(transform.c0)
    pose.yAxis = screenVector(transform.c1)
    pose.zAxis = screenVector(transform.c2)
    return pose
}

private nonisolated func screenVector(_ vector: TranceVector4) -> trance.ScreenVector3 {
    var result = trance.ScreenVector3()
    result.x = Double(vector.x)
    result.y = Double(vector.y)
    result.z = Double(vector.z)
    return result
}

private nonisolated func swiftVector(_ vector: trance.ScreenVector3) -> TranceVector3 {
    TranceVector3(x: Float(vector.x), y: Float(vector.y), z: Float(vector.z))
}

private nonisolated func screenHit(_ hit: trance.ScreenHit) -> TranceScreenHit {
    TranceScreenHit(
        available: hit.available, onScreen: hit.onScreen, x: hit.x, y: hit.y,
        column: Int(hit.column), row: Int(hit.row), position: swiftVector(hit.position))
}

private nonisolated func screenPlane(_ screen: trance.ScreenRectangle) -> TranceScreenPlane {
    TranceScreenPlane(
        available: screen.available, topLeft: swiftVector(screen.topLeft),
        horizontal: swiftVector(screen.horizontal), vertical: swiftVector(screen.vertical),
        pixelWidth: Int(screen.pixelWidth), pixelHeight: Int(screen.pixelHeight),
        calibrationError: screen.calibrationError)
}
