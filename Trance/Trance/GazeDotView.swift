import SwiftUI

struct GazeDotView: View {
    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                let gaze = copyScreenGaze().combined
                let screen = copyCalibratedScreen()
                if let point = gazeDotPosition(gaze, screen: screen, size: geometry.size) {
                    Circle()
                        .fill(.red)
                        .overlay { Circle().stroke(.white, lineWidth: 2) }
                        .frame(width: 14, height: 14)
                        .position(point)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
