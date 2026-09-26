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
            Text(session.dateText)
                .font(.caption)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .background(mood.color.gradient, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    SessionCard(session: Session.mockData[0])
        .frame(width: 180)
}
