//
//  TranceTests.swift
//  TranceTests
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import Testing
@testable import Trance

struct TranceTests {

    @Test @MainActor func unavailableSensors() {
        clearScoreCalibration()
        startScoreSession()
        defer { stopScoreSession() }

        var face = TranceFaceData()
        face.focusPointAvailable = true
        face.focusPoint = TranceVector3(x: 1, y: 2, z: 3)
        updateFace(face)

        let stored = copySensorSnapshot().face
        #expect(!stored.focusPointAvailable)
        #expect(stored.focusPoint.x == 0 && stored.focusPoint.y == 0 && stored.focusPoint.z == 0)

        let scores = copySessionScores()
        #expect(!scores.fokusscore.available)
        #expect(!scores.afslapningsscore.available)
    }

}
