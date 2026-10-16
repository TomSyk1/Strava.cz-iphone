import SwiftUI

struct LogoBadge: View {
    let size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(Theme.primaryContainer)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "fork.knife")
                    .font(.system(size: size * 0.46))
                    .foregroundStyle(Theme.onPrimaryContainer)
            )
    }
}

struct SurfaceCard<Content: View>: View {
    var radius: CGFloat = 24
    var fill: Color = Theme.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
    }
}

struct ErrorCard: View {
    let text: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text).foregroundStyle(Theme.onErrorContainer)
            if let onRetry {
                Button("Zkusit znovu", action: onRetry).font(.subheadline.weight(.semibold))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.errorContainer))
    }
}

struct RadioMark: View {
    let selected: Bool
    var body: some View {
        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .font(.title3)
            .foregroundStyle(selected ? Theme.primary : Theme.outline)
    }
}

struct LabeledField<Content: View>: View {
    let icon: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.onSurfaceVariant)
                .frame(width: 24)
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
    }
}
