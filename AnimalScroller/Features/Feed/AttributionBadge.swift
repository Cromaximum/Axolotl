import SwiftUI

/// A small credit chip. Tapping it shows the full author, licence and source links,
/// which CC BY and CC BY-SA require us to give.
struct AttributionBadge: View {
    let attribution: Attribution
    var label: String = "Credit"
    @State private var showing = false

    var body: some View {
        Button { showing = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "c.circle")
                Text(attribution.shortCredit).lineLimit(1)
            }
            .font(Theme.label(11))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.black.opacity(0.35), in: Capsule())
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
