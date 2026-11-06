import SwiftUI

/// A small credit chip hugging the edge of a photo. Tap for author, licence and source,
/// which CC BY and CC BY-SA require us to give.
struct CreditChip: View {
    let attribution: Attribution
    var label: String = "Photo"
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            Text(attribution.shortCredit)
                .lineLimit(1)
                .font(Theme.label(11))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.55), in: Capsule())
                .foregroundStyle(Theme.parchment)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) credit: \(attribution.shortCredit)")
        .sheet(isPresented: $showing) {
            AttributionDetail(attribution: attribution, label: label)
                .presentationDetents([.medium])
        }
    }
}

struct AttributionDetail: View {
    let attribution: Attribution
    let label: String

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Work", value: attribution.title)
                if let author = attribution.author { LabeledContent("Author", value: author) }
                LabeledContent("Licence", value: attribution.license)
                Link("View source", destination: attribution.sourceURL)
                if let licenseURL = attribution.licenseURL {
                    Link("Read the licence", destination: licenseURL)
                }
                Section {
                    Text("Shown unmodified except for resizing and cropping to fit the screen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("\(label) credit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// "Historical photo", "Real fossil" (parchment) or "Reconstruction" (amber).
struct MediaTagChip: View {
    let tag: MediaTag
    var body: some View {
        Text(tag == .reconstruction ? "RECONSTRUCTION IN FRAME" : tag.label.uppercased())
            .font(Theme.label(10))
            .tracking(0.8)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(tag == .reconstruction ? Theme.amber : Theme.parchment,
                        in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(Theme.ink)
    }
}

/// "Okapi · 2 of 6"
struct NamePill: View {
    let name: String
    let position: Int
    let count: Int
    var body: some View {
        (Text(name).font(Theme.label(12)) + Text("  ·  \(position) of \(count)").font(Theme.body(11)))
            .lineLimit(1)
            .accessibilityLabel("\(name), card \(position) of \(count)")
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.55), in: Capsule())
            .foregroundStyle(Theme.parchment)
    }
}

/// Progress through the current species set.
struct ProgressDashes: View {
    let position: Int
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(count, 1), id: \.self) { i in
                Capsule()
                    .fill(i == position ? Theme.parchment : Theme.parchment.opacity(0.35))
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: 140)
        .accessibilityHidden(true)
    }
}

/// Heart button. Liked species steer the feed toward their relatives (see `LikeAffinity`).
struct LikeButton: View {
    let isLiked: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var hitSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: isLiked ? "heart.fill" : "heart")
                .font(.system(size: iconSize, weight: .semibold))
                .frame(width: hitSize, height: hitSize)
                .background(.black.opacity(0.5), in: Circle())
                .foregroundStyle(isLiked ? Theme.amber : Theme.parchment)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: isLiked)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLiked ? "Unlike" : "Like")
        .accessibilityHint("Likes show you more animals like this one")
    }
}

/// The heart that pops up after a double-tap like. Under Reduce Motion it fades in place.
struct LikeBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 96))
            .foregroundStyle(Theme.amber)
            .shadow(color: .black.opacity(0.4), radius: 10)
            .scaleEffect(shown || reduceMotion ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(reduceMotion ? Theme.Motion.fade : Theme.Motion.pop) { shown = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Like, save, info and share on the right edge of photo cards.
struct ActionRail: View {
    let isLiked: Bool
    let isSaved: Bool
    let shareURL: URL
    let onLike: () -> Void
    let onSave: () -> Void
    let onInfo: () -> Void
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var hitSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 14) {
            LikeButton(isLiked: isLiked, action: onLike)
            railButton(isSaved ? "bookmark.fill" : "bookmark", label: isSaved ? "Unsave" : "Save", action: onSave)
            railButton("info.circle", label: "Species details", action: onInfo)
            ShareLink(item: shareURL) {
                railIcon("square.and.arrow.up")
            }
            .accessibilityLabel("Share")
        }
    }

    private func railButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { railIcon(icon) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    private func railIcon(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .semibold))
            .frame(width: hitSize, height: hitSize)
            .background(.black.opacity(0.5), in: Circle())
            .foregroundStyle(Theme.parchment)
            .contentTransition(.symbolEffect(.replace))
    }
}

struct DidYouKnowBox: View {
    let text: String
    /// Fewer lines at accessibility text sizes so the board stays below the animal (D-010).
    /// The full fact is in the species detail sheet.
    var lineLimit = 4
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DID YOU KNOW?")
                .font(Theme.label(13)).tracking(1.2)
                .foregroundStyle(Theme.wood)
                .accessibilityLabel("Did you know?")
            Text(text)
                .font(Theme.body(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(lineLimit)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.parchment, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// The IUCN Red List bar found on most zoo signs: LC NT VU EN CR EW EX.
struct ConservationScale: View {
    let status: ConservationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(ConservationStatus.scale, id: \.self) { step in
                    Text(step.rawValue)
                        .font(Theme.label(10))
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .foregroundStyle(step == status ? Theme.ink : Theme.mist.opacity(0.7))
                        .background(step == status ? Theme.amber : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 4))
                }
            }
            HStack {
                Text(status.label).font(Theme.label(12)).foregroundStyle(Theme.parchment)
                Spacer()
                Text("IUCN Red List").font(Theme.body(11)).foregroundStyle(Theme.mist)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Conservation status: \(status.label)")
    }
}

/// Dark gradient for text in the lower third of a photo.
struct LowerThirdScrim: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0.55),
                               .init(color: .black.opacity(0.85), location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

/// Top-of-card spacing below the status bar, since the feed draws under it.
enum CardInsets {
    static let top: CGFloat = 58
    static let side: CGFloat = 16
    static let bottom: CGFloat = 18
    /// The most of a card's height a board may take, so text never grows over the animal
    /// (D-010). Boards drop detail at accessibility text sizes to fit under it.
    static let maxBoardShare: CGFloat = 0.5
}
