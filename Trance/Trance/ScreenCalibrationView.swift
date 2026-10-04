import SwiftUI

#if os(iOS)
import UIKit
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
import ARKit
#endif

@MainActor
@Observable
private final class ScreenCalibrationModel {
    private(set) var pointIndex = 0
    private(set) var error = ""

    func calibrate(size: CGSize) async -> Bool {
        pointIndex = 0
        error = ""
        trance.resetScreenCalibration()
        guard let resolution = screenResolution(size: size) else {
            return fail("Kalibrering kræver en iPhone med ansigtssporing og kameraadgang.")
        }
        trance.beginScreenCalibration(Int32(resolution.width), Int32(resolution.height))
        SensorAccess.start()
        do {
            for index in 0..<5 {
                pointIndex = index
                try await Task.sleep(for: .seconds(1))
                let start = Date().timeIntervalSince1970
                let target = targetPosition(index: index, size: size)
                var count = 0
                while count < 45 {
                    try Task.checkCancellation()
                    let now = Date().timeIntervalSince1970
                    count = Int(trance.addScreenCalibrationSample(
                        Int32(index), target.x / size.width, target.y / size.height,
                        eyeTrackingSample(copySensorSnapshot().face), now))
                    if now - start > 15 {
                        return fail("Hold begge øjne åbne og telefonen stille, og prøv igen.")
                    }
                    try await Task.sleep(for: .milliseconds(25))
                }
            }
            try Task.checkCancellation()
            guard trance.finishScreenCalibration() else {
                return fail("Kalibreringen var ustabil. Hold telefonen stille, og prøv igen.")
            }
            return true
        } catch {
            return false
        }
    }

    private func fail(_ text: String) -> Bool {
        error = text
        trance.resetScreenCalibration()
        return false
    }

    private func screenResolution(size: CGSize) -> (width: Int, height: Int)? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              UIDevice.current.userInterfaceIdiom == .phone,
              ARFaceTrackingConfiguration.isSupported,
              size.width > 0, size.height > 0 else { return nil }
        let bounds = scene.screen.nativeBounds
        let shorter = Int(min(bounds.width, bounds.height))
        let longer = Int(max(bounds.width, bounds.height))
        return size.width < size.height ? (shorter, longer) : (longer, shorter)
        #else
        return nil
        #endif
    }
}

struct ScreenCalibrationView: View {
    let onCancel: () -> Void
    let onFinish: () -> Void

    @State private var model = ScreenCalibrationModel()
    @State private var attempt = 0
    @State private var showError = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(Color.black)
                        .frame(width: index == model.pointIndex ? 22 : 8,
                               height: index == model.pointIndex ? 22 : 8)
                        .position(targetPosition(index: index, size: geometry.size))
                }
            }
            .task(id: CalibrationLayout(size: geometry.size, attempt: attempt)) {
                showError = false
                let finished = await model.calibrate(size: geometry.size)
                guard !Task.isCancelled else { return }
                if finished {
                    onFinish()
                } else {
                    showError = true
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .alert("Kalibrering mislykkedes", isPresented: $showError) {
            Button("Prøv igen") { attempt += 1 }
            Button("Annuller", role: .cancel, action: onCancel)
        } message: {
            Text(model.error)
        }
        .onAppear {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }
}

private func targetPosition(index: Int, size: CGSize) -> CGPoint {
    let inset: CGFloat = 24
    switch index {
    case 1: return CGPoint(x: inset, y: inset)
    case 2: return CGPoint(x: size.width - inset, y: inset)
    case 3: return CGPoint(x: size.width - inset, y: size.height - inset)
    case 4: return CGPoint(x: inset, y: size.height - inset)
    default: return CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

private struct CalibrationLayout: Equatable {
    let size: CGSize
    let attempt: Int
}
