import SwiftUI

// MARK: - Chunky 3D buttons

struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Palette.ember
    var shade: Color = Palette.emberShade
    var foreground: Color = .white
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        ChunkyBody(configuration: configuration, fill: fill, shade: shade, foreground: foreground, height: height)
    }

    private struct ChunkyBody: View {
        let configuration: Configuration
        let fill, shade, foreground: Color
        let height: CGFloat
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let pressed = configuration.isPressed
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            configuration.label
                .font(.ui(17, .bold))
                .tracking(0.4)
                .foregroundStyle(enabled ? foreground : Palette.inkSoft.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: height)
                .background(shape.fill(enabled ? fill : Palette.line))
                .offset(y: pressed && enabled ? 4 : 0)
                .background(shape.fill(enabled ? shade : Palette.line.opacity(0.6)).offset(y: 4))
                .padding(.bottom, 4)
                .animation(.spring(duration: 0.12), value: pressed)
                .contentShape(Rectangle())
        }
    }
}

extension ButtonStyle where Self == ChunkyButtonStyle {
    static var chunky: ChunkyButtonStyle { ChunkyButtonStyle() }
    static var chunkyMoss: ChunkyButtonStyle { ChunkyButtonStyle(fill: Palette.moss, shade: Palette.mossShade) }
    static var chunkyTeal: ChunkyButtonStyle { ChunkyButtonStyle(fill: Palette.teal, shade: Palette.tealShade) }
    static var chunkyQuiet: ChunkyButtonStyle { ChunkyButtonStyle(fill: Palette.card, shade: Palette.line, foreground: Palette.ink) }
}

enum TileState { case normal, correct, wrong, disabled }

/// A selectable answer with a raised bottom edge.
struct OptionTile<Label: View>: View {
    var selected = false
    var state: TileState = .normal
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 15)
        }
        .buttonStyle(OptionStyle(selected: selected, state: state))
        .disabled(state == .disabled)
    }
}

private struct OptionStyle: ButtonStyle {
    let selected: Bool
    let state: TileState

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let (edge, wash): (Color, Color) = {
            switch state {
            case .correct: return (Palette.moss, Palette.correctWash)
            case .wrong: return (Palette.ember, Palette.wrongWash)
            case .disabled: return (Palette.line, Palette.sunk)
            case .normal: return selected ? (Palette.teal, Palette.tealWash) : (Palette.line, Palette.card)
            }
        }()
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return configuration.label
            .foregroundStyle(state == .disabled ? Palette.inkSoft.opacity(0.5)
                             : state == .correct ? Palette.mossShade
                             : state == .wrong ? Palette.emberShade
                             : (selected ? Palette.teal : Palette.ink))
            .background(shape.fill(wash))
            .overlay(shape.strokeBorder(edge, lineWidth: 2))
            .offset(y: pressed ? 3 : 0)
            .background(shape.fill(edge).offset(y: 3))
            .padding(.bottom, 3)
            .animation(.spring(duration: 0.12), value: pressed)
            .animation(.easeOut(duration: 0.15), value: selected)
    }
}

// MARK: - Chips & bits

struct LanguageLabel: View {
    let language: String
    var body: some View {
        HStack(spacing: 6) {
            LanguageDot(language: language)
            Text(language).font(.ui(13, .bold)).foregroundStyle(Palette.language(language))
        }
    }
}

struct ThickProgressBar: View {
    var value: Double
    var fill: Color = Palette.moss
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line)
                Capsule().fill(fill)
                    .frame(width: max(height, geo.size.width * value))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.3)).frame(height: height * 0.28)
                            .padding(.horizontal, height * 0.5).padding(.top, height * 0.2)
                    }
                    .opacity(value <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.45, bounce: 0.3), value: value)
    }
}

struct GoalRing: View {
    var progress: Double
    var lineWidth: CGFloat = 5
    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: lineWidth)
            Circle().trim(from: 0, to: progress)
                .stroke(Palette.ochre, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(duration: 0.6), value: progress)
    }
}

/// Wraps children onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth { y += lineHeight + lineSpacing; x = 0; lineHeight = 0 }
            x += s.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, s.height)
        }
        return CGSize(width: min(widest, maxWidth), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { y += lineHeight + lineSpacing; x = bounds.minX; lineHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}

/// Wavy grass edge for the top of the dig site.
struct GrassEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let bumps = max(8, Int(rect.width / 26))
        let w = rect.width / CGFloat(bumps)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        for i in 0..<bumps {
            let x0 = rect.minX + CGFloat(i) * w
            let peak = i.isMultiple(of: 3) ? rect.minY : rect.minY + rect.height * 0.3
            p.addQuadCurve(to: CGPoint(x: x0 + w, y: rect.midY), control: CGPoint(x: x0 + w / 2, y: peak - rect.height * 0.2))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Presentation helpers

extension View {
    /// Full-screen on iPhone, a roomy sheet on Mac.
    @ViewBuilder
    func immersiveCover<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(iOS)
        fullScreenCover(item: item, content: content)
        #else
        sheet(item: item) { content($0).frame(minWidth: 560, idealWidth: 640, minHeight: 680, idealHeight: 760) }
        #endif
    }

    func pageWidth(_ max: CGFloat = 640) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
}

/// Markdown-aware text (supports **bold** and *italic*).
func md(_ s: String) -> Text {
    Text((try? AttributedString(markdown: s)) ?? AttributedString(s))
}
