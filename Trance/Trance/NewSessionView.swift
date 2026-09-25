//
//  NewSessionView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//


import SwiftUI

struct NewSessionView: View {
    var body: some View {
            VStack(alignment: .center) {
                VStack {
                    Circle()
                        .frame(width: 80, height: 80)
                }
                .padding(.bottom, 160)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
}

#Preview {
    NavigationStack {
        NewSessionView()
    }
}
