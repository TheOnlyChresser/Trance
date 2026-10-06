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
    private(set) var progress = 0.0
    private(set) var isRepeatingPoint = false
    private(set) var error = ""
    private var calibrationSize: CGSize?
    private var pixelWidth = 0
    private var pixelHeight = 0
    private var pendingPoints: [Int] = []
    private var visitedPoints: Set<Int> = []

    func calibrate(size: CGSize) async -> Bool {
        error = ""
        guard let resolution = screenResolution(size: size) else {
            calibrationSize = nil
            trance.resetScreenCalibration()
            return fail("Kalibrering kræver en iPhone med ansigtssporing og kameraadgang.")
        }
        if calibrationSize != size || pixelWidth != resolution.width || pixelHeight != resolution.height {
            trance.beginScreenCalibration(Int32(resolution.width), Int32(resolution.height))
            calibrationSize = size
            pixelWidth = resolution.width
            pixelHeight = resolution.height
            pendingPoints = Array(0..<5)
            visitedPoints = []
        }
        let sampleCount = Int(trance.screenCalibrationSampleCount())
        var retries = Array(repeating: 0, count: 5)
        var automaticRetries = 0
        SensorAccess.start()
        do {
            while true {
                while let index = pendingPoints.first {
                    pointIndex = index
                    progress = 0
                    isRepeatingPoint = visitedPoints.contains(index)
                    visitedPoints.insert(index)
                    try await Task.sleep(for: .seconds(1))
                    let start = Date().timeIntervalSince1970
                    let target = targetPosition(index: index, size: size)
                    var count = 0
                    while count < sampleCount {
                        try Task.checkCancellation()
                        let now = Date().timeIntervalSince1970
                        count = Int(trance.addScreenCalibrationSample(
                            Int32(index), target.x / size.width, target.y / size.height,
                            eyeTrackingSample(copySensorSnapshot().face), now))
                        progress = Double(count) / Double(sampleCount)
                        if count < sampleCount && now - start > 15 {
                            _ = trance.finishScreenCalibration()
                            return fail(screenCalibrationFailureMessage() + " De gennemførte punkter er gemt.")
                        }
                        try await Task.sleep(for: .milliseconds(25))
                    }
                    pendingPoints.removeFirst()
                }
                try Task.checkCancellation()
                if trance.finishScreenCalibration() {
                    return true
                }
                let status = trance.copyScreenCalibrationStatus()
                let message = screenCalibrationFailureMessage()
                let suggestedIndex = Int(status.retryPointIndex)
                guard (status.failure == .pointError || status.failure == .meanError),
                      (0..<5).contains(suggestedIndex) else {
                    calibrationSize = nil
                    return fail(message)
                }
                let candidates = [suggestedIndex] + (0..<5).filter {
                    $0 != suggestedIndex && (Int(status.retryPointMask) & (1 << $0)) != 0
                }
                let index = candidates.min { retries[$0] < retries[$1] } ?? suggestedIndex
                guard trance.restartScreenCalibrationPoint(Int32(index)) else {
                    calibrationSize = nil
                    return fail(message)
                }
                pendingPoints = [index]
                guard automaticRetries < 5, retries[index] < 2 else {
                    return fail("Punkt \(index + 1) skal måles igen. De øvrige punkter er gemt. Kig på den store prik, og tryk på Prøv igen.")
                }
                retries[index] += 1
                automaticRetries += 1
            }
        } catch {
            return false
        }
    }

    private func fail(_ text: String) -> Bool {
        error = text
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
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    Text(model.isRepeatingPoint ? "Vi måler punktet igen" : "Kig på den store prik")
                    Text("Punkt \(model.pointIndex + 1) af 5")
                        .font(.caption)
                    ProgressView(value: model.progress)
                        .tint(.black)
                }
                .foregroundStyle(.black)
                .frame(width: 190)
                .padding(.bottom, 64)
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
