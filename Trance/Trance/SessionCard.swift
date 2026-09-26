//
//  SessionCard.swift
//  Trance
//

import SwiftUI

/// En farverig flise i gitteret af sessioner på Hjem.
struct SessionCard: View {
    let session: Session

    var body: some View {
        let mood = Mood(session.relaxation)
        // To kort oven på hinanden: det farvede ligger øverst og dækker toppen af datokortet.
        VStack(spacing: -24) {
            // det farvede kort
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(mood.emoji)
                        .font(.system(size: 40))

                    Spacer()

                    // minutterne som et lille skævt mærkat i hjørnet
                    Text("\(session.minutes) min")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.25), in: .capsule)
                        .rotationEffect(.degrees(12))
                }

                Spacer()

                Text(mood.title)
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .background(mood.color.gradient, in: .rect(cornerRadius: 24))
            // en svag skygge, så man kan se at det ligger oven på datokortet
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .zIndex(1)

            // datokortet bagved
            Text(session.dateText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal)
                // ekstra luft i toppen, fordi den øverste del er gemt under det farvede kort
                .padding(.top, 24 + 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                // kun de nederste hjørner er runde; toppen ligger inde under det farvede kort
                .background(Color(.secondarySystemBackground), in: .rect(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
        }
    }
}

#Preview {
    SessionCard(session: Session.mockData[0])
        .frame(width: 180, height: 160)
}
