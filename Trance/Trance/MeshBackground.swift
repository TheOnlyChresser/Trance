//
//  MeshBackground.swift
//  Trance
//

import SwiftUI

/// En let farvegradient fra skærmens kant ind mod midten, bag Hjem og bag resumeet efter en session.
/// Midten har baggrundens farve og ligger samme sted som teksten, så den er let at læse.
struct MeshBackground: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.44], [0.5, 0.44], [1, 0.44],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                .orange, .yellow, .orange,
                .pink, Color(.systemBackground), .mint,
                .teal, .cyan, .blue,
            ]
        )
        .opacity(0.35)
        .ignoresSafeArea()
    }
}

#Preview {
    MeshBackground()
}
