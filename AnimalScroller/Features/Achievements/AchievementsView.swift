import SwiftUI

/// "Awards": tiered achievements for species met, per tree branch and per IUCN status.
/// Badges are SF Symbols and typography only, no artwork (D-011).
struct AchievementsView: View {
    let model: AchievementsViewModel
    @Environment(AchievementsStore.self) private var store

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your awards").font(Theme.body(13)).foregroundStyle(Theme.mist)
                    Text("Tiers reached · \(model.totalTiers)").font(Theme.heading(30))
                        .foregroundStyle(Theme.parchment)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(model.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title.uppercased()).font(Theme.label(12)).foregroundStyle(Theme.amber)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(section.items) { item in
                            AchievementRow(progress: item, isNew: model.highlightedIDs.contains(item.id))
                        }
                    }
                }
                Text("Every species you meet in the feed counts towards its branches of the tree and its conservation status. Tiers keep going, so there is always a next one.")
                    .font(Theme.body(12)).foregroundStyle(Theme.mist)
            }
            .padding(16)
        }
        .background(Theme.forest)
        .onAppear { model.tabOpened(store: store) }
    }
}

/// One achievement: medal with its tier, the group name, and progress to the next target.
private struct AchievementRow: View {
    let progress: AchievementProgress
    let isNew: Bool

    var body: some View {
        HStack(spacing: 12) {
            AchievementMedal(tier: progress.tier)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(AchievementText.title(progress.achievement))
                        .font(Theme.body(16, weight: .bold)).foregroundStyle(Theme.parchment)
                        .lineLimit(1)
                    if let sci = progress.achievement.scientificName, sci != progress.achievement.name {
                        Text(sci).font(Theme.scientific(13)).foregroundStyle(Theme.mist).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if isNew {
                        Text("NEW").font(Theme.label(10)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.amber, in: Capsule())
                    }
                }
                ProgressView(value: progress.fractionToNext).tint(Theme.amber)
                Text(AchievementText.progressLine(progress))
                    .font(Theme.body(12)).foregroundStyle(Theme.mist)
            }
        }
        .padding(12)
        .background(Theme.boardGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(isNew ? Theme.amber : Theme.wood, lineWidth: 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AchievementText.accessibilityLabel(progress, isNew: isNew))
    }
}

/// A rosette with the tier number. Bronze, silver and gold for tiers 1 to 3, amber after that.
struct AchievementMedal: View {
    let tier: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Image(systemName: tier > 0 ? "rosette" : "circle.dashed")
                .font(.system(size: size * 0.8))
                .foregroundStyle(AchievementText.medalColor(tier: tier))
            if tier > 0 {
                Text("\(tier)").font(Theme.label(size * 0.27)).foregroundStyle(Theme.ink)
                    .offset(y: -size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// UI wording for achievements. Names come from the model (taxonomy names or status labels).
enum AchievementText {
    static func title(_ a: Achievement) -> String {
        if case .overall = a.kind { return "Every species" }
        return a.name
    }

    static func progressLine(_ p: AchievementProgress) -> String {
        let tier = p.tier > 0 ? "Tier \(p.tier) · " : ""
        return "\(tier)\(p.metCount) of \(p.nextTarget) met for the next tier"
    }

    static func accessibilityLabel(_ p: AchievementProgress, isNew: Bool) -> String {
        var parts = [title(p.achievement), p.tier > 0 ? "Tier \(p.tier)" : "No tier yet",
                     "\(p.metCount) of \(p.nextTarget) species met for the next tier"]
        if isNew { parts.append("New") }
        return parts.joined(separator: ", ")
    }

    static func medalColor(tier: Int) -> Color {
        switch tier {
        case ..<1: Theme.mist.opacity(0.5)
        case 1: Color(hex: 0xC07A3E)  // bronze
        case 2: Color(hex: 0xC9D1D3)  // silver
        case 3: Color(hex: 0xF2C94C)  // gold
        default: Theme.amber
        }
    }
}

/// The banner shown over the tabs for a few seconds when a tier is reached. Tap to dismiss.
struct AchievementToastView: View {
    let progress: AchievementProgress
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 10) {
                AchievementMedal(tier: progress.tier, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tier \(progress.tier) reached").font(Theme.label(12)).foregroundStyle(Theme.amber)
                    Text("\(AchievementText.title(progress.achievement)) · \(progress.previousTarget) species met")
                        .font(Theme.body(14, weight: .bold)).foregroundStyle(Theme.parchment).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.boardGreen, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.wood, lineWidth: 3))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel("Tier \(progress.tier) reached, \(AchievementText.title(progress.achievement)), "
                            + "\(progress.previousTarget) species met")
        .accessibilityHint("Dismisses")
    }
}
