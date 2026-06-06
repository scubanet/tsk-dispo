import SwiftUI

// ═══════════════════════════════════════
// MARK: - Depth Profile Shape
// ═══════════════════════════════════════

struct DepthProfileShape: Shape {
    let data: [Double]; let maxDepth: Double
    func path(in rect: CGRect) -> Path {
        guard data.count > 1 else { return Path() }
        var p = Path()
        let stepX = rect.width / CGFloat(data.count - 1)
        let ceil = maxDepth * 1.1
        for (i, depth) in data.enumerated() {
            let pt = CGPoint(x: CGFloat(i) * stepX, y: CGFloat(depth / ceil) * rect.height)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        return p
    }
}

struct DepthProfileFill: Shape {
    let data: [Double]; let maxDepth: Double
    func path(in rect: CGRect) -> Path {
        guard data.count > 1 else { return Path() }
        var p = Path()
        let stepX = rect.width / CGFloat(data.count - 1)
        let ceil = maxDepth * 1.1
        p.move(to: .zero)
        for (i, depth) in data.enumerated() {
            p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: CGFloat(depth / ceil) * rect.height))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

struct DepthProfileChart: View {
    let data: [Double]; let maxDepth: Double
    var height: CGFloat = 160
    var compact: Bool = false

    var body: some View {
        ZStack {
            DepthProfileFill(data: data, maxDepth: maxDepth)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appAccent.opacity(0.28),
                            Color.appAccent.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            DepthProfileShape(data: data, maxDepth: maxDepth)
                .stroke(Color.appAccent,
                        style: StrokeStyle(lineWidth: compact ? 1.2 : 1.8,
                                           lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
        .clipped()
    }
}

// ═══════════════════════════════════════
// MARK: - Stat Card
// ═══════════════════════════════════════

struct StatCard: View {
    let label: String; let value: String
    var unit: String = ""; var sub: String? = nil; var accent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(accent ? Color.appAccent : .primary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            if let sub {
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.l)
        .glassCard(cornerRadius: DSRadius.l)
    }
}

// ═══════════════════════════════════════
// MARK: - Info Chip
// ═══════════════════════════════════════

struct InfoChip: View {
    let systemIcon: String; let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemIcon)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value.capitalized)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.m)
        .solidCard(cornerRadius: DSRadius.m)
    }
}

// ═══════════════════════════════════════
// MARK: - Pill Tab Bar
// ═══════════════════════════════════════

struct PillTabBar: View {
    @Binding var selected: String; let tabs: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selected = tab }
                } label: {
                    Text(tab)
                        .font(.system(size: 13, weight: selected == tab ? .semibold : .medium))
                        .foregroundStyle(selected == tab ? Color.appAccent : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: DSRadius.s, style: .continuous)
                                .fill(selected == tab ? Color.appAccent.opacity(0.15) : .clear)
                        )
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.m, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.m, style: .continuous)
                .stroke(Color.hairline.opacity(0.4), lineWidth: 0.5)
        )
    }
}

// ═══════════════════════════════════════
// MARK: - Segment Picker
// ═══════════════════════════════════════

struct SegmentPicker: View {
    let label: String; let options: [(value: String, display: String)]; @Binding var selected: String
    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s) {
            if !label.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(options, id: \.value) { opt in
                    Button { selected = opt.value } label: {
                        Text(opt.display)
                            .font(.system(size: 12, weight: selected == opt.value ? .semibold : .medium))
                            .foregroundStyle(selected == opt.value ? Color.white : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: DSRadius.s, style: .continuous)
                                    .fill(selected == opt.value
                                          ? AnyShapeStyle(Color.appAccent)
                                          : AnyShapeStyle(Color.surfaceCard))
                            )
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Section Title & Divider
// ═══════════════════════════════════════

struct SectionTitle: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(0.5)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DSSpacing.l)
            .padding(.bottom, DSSpacing.xs)
    }
}

struct SectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.hairline.opacity(0.6))
            .frame(height: 0.5)
            .padding(.vertical, DSSpacing.l)
    }
}

// ═══════════════════════════════════════
// MARK: - Buddy & Marine Life Chips
// ═══════════════════════════════════════

struct BuddyChip: View {
    let name: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.fill").font(.system(size: 10))
            Text(name).font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.appAccent)
        .padding(.horizontal, DSSpacing.m + 2).padding(.vertical, 7)
        .background(Capsule().fill(Color.appAccent.opacity(0.12)))
    }
}

struct MarineLifeChip: View {
    let species: String
    var body: some View {
        HStack(spacing: 4) {
            Text("🐠").font(.system(size: 10))
            Text(species).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.primary.opacity(0.75))
        .padding(.horizontal, DSSpacing.m).padding(.vertical, 5)
        .background(Capsule().fill(Color.surfaceCard))
        .overlay(Capsule().strokeBorder(Color.hairline.opacity(0.5), lineWidth: 0.5))
    }
}

// ═══════════════════════════════════════
// MARK: - Form Field
// ═══════════════════════════════════════

struct FormField: View {
    let label: String; @Binding var text: String
    var placeholder: String = ""; var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs + 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .padding(DSSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.m, style: .continuous)
                        .fill(Color.surfaceCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.m, style: .continuous)
                        .strokeBorder(Color.hairline.opacity(0.5), lineWidth: 0.5)
                )
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Star Rating
// ═══════════════════════════════════════

struct StarRating: View {
    @Binding var rating: Int; var maxStars: Int = 5
    var body: some View {
        HStack(spacing: DSSpacing.s) {
            ForEach(1...maxStars, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 24))
                    .foregroundStyle(star <= rating ? Color.appEmphasis : Color.hairline)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            rating = rating == star ? 0 : star
                        }
                    }
            }
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Flow Layout
// ═══════════════════════════════════════

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layoutResult(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = layoutResult(proposal: proposal, subviews: subviews)
        for (i, sv) in subviews.enumerated() {
            sv.place(at: CGPoint(x: bounds.minX + r.positions[i].x, y: bounds.minY + r.positions[i].y), proposal: .unspecified)
        }
    }
    private func layoutResult(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxW = proposal.width ?? .infinity
        var pos: [CGPoint] = []; var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            pos.append(CGPoint(x: x, y: y)); rowH = max(rowH, s.height); x += s.width + spacing
        }
        return (CGSize(width: maxW, height: y + rowH), pos)
    }
}

// ═══════════════════════════════════════
// MARK: - DS Section Label
// ═══════════════════════════════════════

struct DSSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// ═══════════════════════════════════════
// MARK: - Glass Card Modifier
// ═══════════════════════════════════════

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DSRadius.m

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.hairline.opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = DSRadius.m) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

// ═══════════════════════════════════════
// MARK: - Solid Card Modifier
// ═══════════════════════════════════════

struct SolidCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DSRadius.m

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.hairline.opacity(0.4), lineWidth: 0.5)
            )
    }
}

extension View {
    func solidCard(cornerRadius: CGFloat = DSRadius.m) -> some View {
        modifier(SolidCardModifier(cornerRadius: cornerRadius))
    }
}

// ═══════════════════════════════════════
// MARK: - Hero Background
// ═══════════════════════════════════════

struct HeroBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.appAccent.opacity(0.08),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }
}

// ═══════════════════════════════════════
// MARK: - FAB Button
// ═══════════════════════════════════════

struct FABButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.appAccent, .appAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .appAccent.opacity(0.35), radius: 10, y: 4)
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Language Observer
// ═══════════════════════════════════════

struct LanguageObserverModifier: ViewModifier {
    @AppStorage("appLanguage") private var language = "en"

    func body(content: Content) -> some View {
        content
            .id(language)
    }
}

extension View {
    func observeLanguage() -> some View {
        modifier(LanguageObserverModifier())
    }
}
