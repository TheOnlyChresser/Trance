//
//  Session.swift
//  Trance
//

import Foundation

/// En gennemført session.
struct Session: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
    /// gennemsnitlig afslapning fra 0 til 1, hvor 0.7 betyder 70 %
    let relaxation: Double

    /// fx "I dag", "I går" eller "man. 22. sep."
    var dateText: String {
        if Calendar.current.isDateInToday(date) { return "I dag" }
        if Calendar.current.isDateInYesterday(date) { return "I går" }
        // appen er ikke oversat endnu, så dansk skal vælges her, ellers bliver datoen engelsk
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "da_DK")))
    }
}

extension Session {
    /// Eksempeldata indtil sessioner bliver gemt rigtigt.
    static let mockData: [Session] = [
        Session(date: .now.addingTimeInterval(-2 * hour), minutes: 10, relaxation: 0.72),
        Session(date: .now.addingTimeInterval(-1 * day), minutes: 30, relaxation: 0.84),
        Session(date: .now.addingTimeInterval(-2 * day), minutes: 5, relaxation: 0.41),
        Session(date: .now.addingTimeInterval(-3 * day), minutes: 10, relaxation: 0.65),
        Session(date: .now.addingTimeInterval(-5 * day), minutes: 60, relaxation: 0.91),
        Session(date: .now.addingTimeInterval(-6 * day), minutes: 2, relaxation: 0.28),
        Session(date: .now.addingTimeInterval(-8 * day), minutes: 10, relaxation: 0.58),
        Session(date: .now.addingTimeInterval(-11 * day), minutes: 1, relaxation: 0.35),
    ]

    private static let hour: TimeInterval = 60 * 60
    private static let day: TimeInterval = 24 * hour
}
