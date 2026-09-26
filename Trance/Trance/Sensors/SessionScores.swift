import Foundation

public nonisolated struct TranceScore: Sendable {
    public var available = false
    public var value: Double = 0
    public var coverage: Double = 0
}

public nonisolated struct TranceSessionScores: Sendable {
    public var afslapningsscore = TranceScore()
    public var fokusscore = TranceScore()
}

@discardableResult
public nonisolated func configureRelaxationScore(
    startBpm: Double,
    relaxedBpm: Double
) -> Bool {
    trance.setRelaxationReference(startBpm, relaxedBpm)
}

@discardableResult
public nonisolated func configureFocusScore(
    target: TranceVector3,
    toleranceDegrees: Double
) -> Bool {
    trance.setFocusTarget(scoreVector(target), toleranceDegrees * .pi / 180)
}

public nonisolated func clearScoreCalibration() {
    trance.clearScoreCalibration()
}

public nonisolated func startScoreSession() {
    trance.startScores(Date().timeIntervalSince1970)
}

public nonisolated func stopScoreSession() {
    trance.stopScores()
}

public nonisolated func copySessionScores() -> TranceSessionScores {
    let scores = trance.copyScores(Date().timeIntervalSince1970)

    return TranceSessionScores(
        afslapningsscore: TranceScore(
            available: scores.afslapningsscore.available,
            value: scores.afslapningsscore.value,
            coverage: scores.afslapningsscore.coverage
        ),

        fokusscore: TranceScore(
            available: scores.fokusscore.available,
            value: scores.fokusscore.value,
            coverage: scores.fokusscore.coverage
        )
    )
}

private nonisolated func scoreVector(_ value: TranceVector3) -> trance.ScoreVector3 {
    var result = trance.ScoreVector3()

    result.x = Double(value.x)
    result.y = Double(value.y)
    result.z = Double(value.z)

    return result
}

nonisolated func updateScoreHeartRate(_ value: TranceHeartRate) {
    trance.recordScoreHeartRate(
        value.available,
        value.bpm,
        value.timestamp,
        Date().timeIntervalSince1970
    )
}

nonisolated func updateScoreFace(_ value: TranceFaceData) {
    var sample = trance.ScoreFaceSample()

    sample.available = value.available
    sample.timestamp = value.timestamp

    sample.leftEyeClosure = Double(value.leftEyeClosure)
    sample.rightEyeClosure = Double(value.rightEyeClosure)

    sample.leftOrigin = scoreVector(value.leftEyeOrigin)
    sample.rightOrigin = scoreVector(value.rightEyeOrigin)

    sample.leftDirection = scoreVector(value.leftEyeDirection)
    sample.rightDirection = scoreVector(value.rightEyeDirection)

    trance.recordScoreFace(sample, Date().timeIntervalSince1970)
}
