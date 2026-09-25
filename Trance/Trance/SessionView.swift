//
//  SessionView.swift
//  Trance
//
//  Created by Chresten Soelberg on 25/09/2026.
//

import SwiftUI

struct SessionView: View {
    let duration: Duration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Circle()
            .frame(width: 16, height: 16)
            .padding(.bottom, 128)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            // skærmen skal ikke låse, man skal fokusere ikke pille ved skærmen
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .task {
                try? await Task.sleep(for: duration)
                guard !Task.isCancelled else { return }
                dismiss()
            }
    }
}

#Preview {
    SessionView(duration: .seconds(60))
}
