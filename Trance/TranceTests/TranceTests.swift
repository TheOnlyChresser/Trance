//
//  TranceTests.swift
//  TranceTests
//
//  Created by Chresten Soelberg on 01/09/2026.
//

import Foundation
import Testing
@testable import Trance

struct TranceTests {

    @Test func gazeDotMapsNativePixels() {
        var screen = TranceScreenPlane()
        screen.available = true
        screen.pixelWidth = 1080
        screen.pixelHeight = 2340
        let size = CGSize(width: 375, height: 812)

        var gaze = TranceScreenHit()
        gaze.available = true
        gaze.onScreen = true
        #expect(gazeDotPosition(gaze, screen: screen, size: size) == .zero)

        gaze.x = 539.5
        gaze.y = 1169.5
        #expect(gazeDotPosition(gaze, screen: screen, size: size)
                == CGPoint(x: 187.5, y: 406))

        gaze.x = 1079
        gaze.y = 2339
        #expect(gazeDotPosition(gaze, screen: screen, size: size)
                == CGPoint(x: 375, y: 812))

        #expect(gazeDotPosition(gaze, screen: screen, size: .zero) == nil)
        #expect(gazeDotPosition(gaze, screen: screen,
                                size: CGSize(width: 812, height: 375)) == nil)
        gaze.onScreen = false
        #expect(gazeDotPosition(gaze, screen: screen, size: size) == nil)
        gaze.onScreen = true
        gaze.available = false
        #expect(gazeDotPosition(gaze, screen: screen, size: size) == nil)
        gaze.available = true
        gaze.x = .nan
        #expect(gazeDotPosition(gaze, screen: screen, size: size) == nil)
        gaze.x = 0
        screen.available = false
        #expect(gazeDotPosition(gaze, screen: screen, size: size) == nil)

        screen.available = true
        screen.pixelWidth = 2340
        screen.pixelHeight = 1080
        gaze.x = 1169.5
        gaze.y = 539.5
        #expect(gazeDotPosition(gaze, screen: screen,
                                size: CGSize(width: 812, height: 375))
                == CGPoint(x: 406, y: 187.5))
    }

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
