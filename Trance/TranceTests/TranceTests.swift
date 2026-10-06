//
//  TranceTests.swift
//  TranceTests
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import Testing
@testable import Trance

struct TranceTests {

    @Test func faceSamplesKeepLatestValue() {
        let samples = FaceSampleMailbox()
        for index in 1...1000 {
            var face = TranceFaceData()
            face.available = true
            face.timestamp = Double(index)
            #expect(samples.offer(face) == (index == 1))
        }
        #expect(samples.take()?.timestamp == 1000)
        #expect(samples.take() == nil)

        var face = TranceFaceData()
        face.available = true
        #expect(samples.offer(face))
        #expect(!samples.offer(TranceFaceData()))
        #expect(samples.take()?.available == false)
        #expect(samples.offer(face))
        #expect(samples.take()?.available == true)
    }

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
