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
public nonisolated func configureFocusScore(x: Double, y: Double, radius: Double) -> Bool {
    trance.setFocusTarget(x, y, radius)
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

nonisolated func updateScoreHeartRate(_ value: TranceHeartRate) {
    trance.recordScoreHeartRate(
        value.available,
        value.bpm,
        value.timestamp,
        Date().timeIntervalSince1970
    )
}
