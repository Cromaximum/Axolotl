import SwiftUI

/// Two-finger zoom into a photo, up to 4x around where the pinch started. It springs back when
/// the fingers lift, so the feed never gets stuck zoomed in. `isZooming` lets the card fade its
/// chips while the animal fills the screen (D-010: species first).
struct PinchToZoom: ViewModifier {
    @Binding var isZooming: Bool
    static let maxScale: CGFloat = 4

    private struct Zoom: Equatable {
        var scale: CGFloat = 1
        var anchor: UnitPoint = .center
    }

    @GestureState(resetTransaction: Transaction(animation: Theme.Motion.settle))
    private var zoom = Zoom()

    func body(content: Content) -> some View {
        content
            .scaleEffect(zoom.scale, anchor: zoom.anchor)
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($zoom) { value, zoom, _ in
                        zoom = Zoom(scale: min(max(value.magnification, 1), Self.maxScale),
                                    anchor: value.startAnchor)
                    }
            )
            .onChange(of: zoom.scale > 1.01) { _, zoomed in isZooming = zoomed }
    }
}

extension View {
    func pinchToZoom(isZooming: Binding<Bool>) -> some View {
        modifier(PinchToZoom(isZooming: isZooming))
    }
}
