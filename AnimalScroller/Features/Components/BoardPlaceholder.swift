import SwiftUI

/// A board-green fill with a slow light band sweeping across, for anything still loading
/// (photos, the next species). Static under Reduce Motion. W1's `FullBleedImage` uses it for
/// its loading phase.
struct ShimmerFill: View {
    var base: Color = Theme.boardGreen
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            base.overlay {
                if !reduceMotion {
                    LinearGradient(colors: [.clear, Theme.parchment.opacity(0.10), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width)
                }
            }
            .clipped()
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Theme.Motion.shimmer) { phase = 1.4 }
        }
        .accessibilityHidden(true)
    }
}

/// The intro card's zoo board drawn as empty bars, shown while the next species loads, so the
/// feed never shows a bare spinner. Matches the real board's frame, padding and corner radius.
struct BoardPlaceholder: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ShimmerFill(base: Theme.forest)
            VStack(alignment: .leading, spacing: 12) {
                bar(width: 0.65, height: 30, color: Theme.parchment)
                bar(width: 0.4, height: 14, color: Theme.amber)
                bar(width: 0.55, height: 10, color: Theme.mist)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.parchment.opacity(0.18))
                    .frame(height: 84)
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)).frame(height: 22)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.boardGreen, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.wood, lineWidth: 6))
            .padding(.horizontal, 10)
            .padding(.bottom, CardInsets.bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading the next animal")
    }

    private func bar(width: CGFloat, height: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2)
                .fill(color.opacity(0.28))
                .frame(width: geo.size.width * width, height: height)
        }
        .frame(height: height)
    }
}
