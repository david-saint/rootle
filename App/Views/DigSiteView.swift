import SwiftUI

/// The learning path: a cross-section of earth. Each unit is a layer; the deeper you dig, the further you've come.
struct DigSiteView: View {
    @Environment(GameStore.self) private var store
    let onStart: (PathNode, Bool) -> Void
    let onLocked: (String) -> Void

    var body: some View {
        let lex = store.lexicon
        VStack(spacing: 0) {
            GrassEdge()
                .fill(Palette.moss)
                .frame(height: 26)
                .overlay(alignment: .bottom) { Rectangle().fill(Palette.mossShade).frame(height: 5) }
            ForEach(Array(lex.units.enumerated()), id: \.element.id) { i, unit in
                StratumView(unit: unit, index: i, onStart: onStart, onLocked: onLocked)
            }
            Bedrock()
        }
    }
}

private struct StratumView: View {
    @Environment(GameStore.self) private var store
    let unit: Unit
    let index: Int
    let onStart: (PathNode, Bool) -> Void
    let onLocked: (String) -> Void

    private let rowHeight: CGFloat = 124

    var body: some View {
        let nodes = store.lexicon.nodes(forUnit: index)
        let locked = store.isUnitLocked(index)
        let progress = store.unitProgress(index)
        let side: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        let layer = Palette.layer(index)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Overline("Layer \(index + 1)", color: locked ? layer.accent.opacity(0.6) : layer.accent)
                    Text(unit.title)
                        .font(.serif(27, .bold))
                        .foregroundStyle(Palette.ink.opacity(locked ? 0.6 : 1))
                    Text(unit.subtitle)
                        .font(.ui(14, .medium))
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if progress.done > 0 {
                    Text("\(progress.done)/\(progress.total)")
                        .font(.ui(13, .heavy)).monospacedDigit()
                        .foregroundStyle(progress.done == progress.total ? Palette.mossShade : Palette.inkSoft)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)

            GeometryReader { geo in
                let w = geo.size.width
                let points = nodes.indices.map { k -> CGPoint in
                    let swing: [CGFloat] = [-0.12, 0.16, -0.04]
                    return CGPoint(x: w / 2 + side * swing[k % 3] * min(w, 520), y: rowHeight * (CGFloat(k) + 0.5))
                }
                ZStack(alignment: .topLeading) {
                    Tunnel(points: points)
                        .stroke(layer.deep.opacity(0.55), style: StrokeStyle(lineWidth: 26, lineCap: .round, lineJoin: .round))
                    Tunnel(points: points)
                        .stroke(layer.deep, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 12]))

                    Pebbles(seed: index, size: geo.size, color: layer.deep)

                    Image(unit.emblem)
                        .resizable().scaledToFit()
                        .frame(width: min(150, w * 0.32))
                        .rotationEffect(.degrees(side * -8))
                        .saturation(locked ? 0.3 : 1)
                        .opacity(locked ? 0.5 : 1)
                        .position(x: w / 2 - side * min(w * 0.3, 190), y: rowHeight * 1.5)
                        .accessibilityHidden(true)

                    ForEach(Array(nodes.enumerated()), id: \.element.id) { k, node in
                        let status = store.status(of: node)
                        NodeButton(node: node, status: status, layer: layer) {
                            switch status {
                            case .current: onStart(node, false)
                            case .done: onStart(node, true)
                            case .locked: onLocked("Finish the layers above to dig this deep.")
                            }
                        }
                        .position(points[k])

                        if status == .current {
                            Image("digby_dig")
                                .resizable().scaledToFit()
                                .frame(width: 78)
                                .position(x: points[k].x + (points[k].x > w / 2 ? -96 : 96), y: points[k].y + 6)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .frame(height: rowHeight * CGFloat(nodes.count))
            .padding(.top, 40)
            .padding(.bottom, 24)
        }
        .pageWidth(620)
        .background(layer.fill)
        .overlay(alignment: .top) {
            if index > 0 {
                SedimentEdge(seed: index).fill(layer.fill).frame(height: 18).offset(y: -17)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct Tunnel: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for i in 1..<max(1, points.count) {
            let a = points[i - 1], b = points[i]
            let mid = (a.y + b.y) / 2
            p.addCurve(to: b, control1: CGPoint(x: a.x, y: mid), control2: CGPoint(x: b.x, y: mid))
        }
        return p
    }
}

/// Scattered stones in the soil, deterministic per layer.
private struct Pebbles: View {
    let seed: Int
    let size: CGSize
    let color: Color
    var body: some View {
        Canvas { ctx, sz in
            var rng = SplitMix64(seed: UInt64(seed * 7919 + 17))
            for _ in 0..<14 {
                let x = CGFloat.random(in: 8...(sz.width - 8), using: &rng)
                let y = CGFloat.random(in: 8...(sz.height - 8), using: &rng)
                let r = CGFloat.random(in: 2.5...7, using: &rng)
                let rect = CGRect(x: x, y: y, width: r * 1.6, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.5)))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

private struct NodeButton: View {
    let node: PathNode
    let status: NodeStatus
    let layer: Palette.Layer
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        let isReview = node.kind == .review
        let (fill, shade, icon, iconColor): (Color, Color, String, Color) = {
            switch status {
            case .done: return (Palette.ochre, Palette.ochreShade, "checkmark", .white)
            case .current: return (layer.accent, layer.accentShade, isReview ? "shippingbox.fill" : "book.fill", .white)
            case .locked: return (layer.deep, layer.accentShade.opacity(0.45), isReview ? "shippingbox.fill" : "lock.fill", .white.opacity(0.92))
            }
        }()
        let size: CGFloat = isReview ? 84 : 74

        Button(action: action) {
            ZStack {
                if status == .current {
                    Circle()
                        .stroke(layer.accent.opacity(0.4), lineWidth: 6)
                        .frame(width: size + 22, height: size + 22)
                        .scaleEffect(pulse ? 1.12 : 0.96)
                        .opacity(pulse ? 0 : 1)
                }
                Circle().fill(shade).frame(width: size, height: size).offset(y: 6)
                Circle().fill(fill).frame(width: size, height: size)
                    .overlay(alignment: .top) {
                        Ellipse().fill(.white.opacity(0.22)).frame(width: size * 0.55, height: size * 0.2).offset(y: size * 0.12)
                    }
                Image(systemName: icon)
                    .font(.system(size: isReview ? 30 : 27, weight: .heavy))
                    .foregroundStyle(iconColor)
            }
            .frame(width: size + 24, height: size + 24)
            .contentShape(Circle())
        }
        .buttonStyle(NodePress())
        .overlay(alignment: .top) {
            if status == .current {
                Text(isReview ? "OPEN" : "START")
                    .font(.ui(13, .black)).tracking(1.2)
                    .foregroundStyle(layer.accent)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.line, lineWidth: 1.5))
                    .offset(y: -34)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel(accessibility)
        .onAppear {
            guard status == .current else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private var accessibility: String {
        let kind = node.kind == .review ? "Treasure review" : "Lesson"
        switch status {
        case .done: return "\(kind), complete. Replay."
        case .current: return "\(kind), start"
        case .locked: return "\(kind), locked"
        }
    }
}

private struct NodePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

/// The bottom of the dig: where Claude digs out the next layer.
private struct Bedrock: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let busy = store.digging == .layer
        VStack(spacing: 12) {
            Image(busy ? "digby_dig" : "digby_sleep")
                .resizable().scaledToFit().frame(width: 140)
                .accessibilityHidden(true)
            Text(busy ? "Digging a new layer…" : "Dig deeper")
                .font(.serif(26, .bold)).foregroundStyle(Palette.ink)
            Text(busy ? "Digby is unearthing eight fresh words. This takes about a minute."
                 : "Every layer below this one is new. Dig one out whenever you like — it never runs dry.")
                .font(.ui(15, .medium)).foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            if busy {
                ProgressView().controlSize(.large).tint(Palette.ember).padding(.top, 6)
            } else {
                Button {
                    Task { await store.digNewLayer() }
                } label: {
                    Label("Dig a new layer", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.chunky)
                .frame(maxWidth: 280)
                .padding(.top, 6)
                .disabled(store.digging != .idle)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 52)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity)
        .background(Palette.bedrock)
        .overlay(alignment: .top) {
            SedimentEdge(seed: 99).fill(Palette.bedrock).frame(height: 18).offset(y: -17)
                .allowsHitTesting(false)
        }
    }
}

/// A gently wavy boundary between two sediment layers.
struct SedimentEdge: Shape {
    var seed: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var rng = SplitMix64(seed: UInt64(seed * 104_729 + 7))
        let waves = max(4, Int(rect.width / 140))
        let w = rect.width / CGFloat(waves)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        for i in 0..<waves {
            let x0 = rect.minX + CGFloat(i) * w
            let up = CGFloat.random(in: 0...0.5, using: &rng) * rect.height
            let down = rect.height - CGFloat.random(in: 0...0.35, using: &rng) * rect.height
            p.addCurve(to: CGPoint(x: x0 + w, y: rect.midY),
                       control1: CGPoint(x: x0 + w * 0.3, y: up),
                       control2: CGPoint(x: x0 + w * 0.7, y: down))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
