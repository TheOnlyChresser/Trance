//
//  Mood.swift
//  Trance
//

import SwiftUI

enum Mood {
    case restless, settling, relaxed, deep

    /// finder trinnet ud fra en afslapning fra 0 til 1
    init(_ relaxation: Double) {
        if relaxation >= 0.8 {
            self = .deep
        } else if relaxation >= 0.6 {
            self = .relaxed
        } else if relaxation >= 0.4 {
            self = .settling
        } else {
            self = .restless
        }
    }

    var emoji: String {
        switch self {
        case .restless: return "🫨"
        case .settling: return "🙂"
        case .relaxed: return "😌"
        case .deep: return "🫠"
        }
    }

    var title: String {
        switch self {
        case .restless: return "En urolig session"
        case .settling: return "På vej mod ro"
        case .relaxed: return "Godt afslappet"
        case .deep: return "Dybt afslappet"
        }
    }

    var message: String {
        switch self {
        case .restless: return "Nogle dage er sværere end andre. Hver session tæller."
        case .settling: return "Du gav dig selv en pause, og det kan mærkes."
        case .relaxed: return "Din krop fandt roen undervejs. Godt gået."
        case .deep: return "Du fandt helt ned i roen. Tag den med dig resten af dagen."
        }
    }

    var color: Color {
        switch self {
        case .restless: return .pink
        case .settling: return .orange
        case .relaxed: return .green
        case .deep: return .indigo
        }
    }
}
