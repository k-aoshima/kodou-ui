import SwiftUI

/// 棒グラフ。ブロックを積んだ棒で、目盛りは値と同じ縮尺。上限を超えた分は、色だけでなく斜線と「+n」の文字でも示す。
/// 棒に触れるかフォーカスを当てると値を出す。棒は Tab で移れ、VoiceOver は 1 本ずつ読む。
/// 棒の数が多い（数百本）ときは KodouLineChart（Canvas）を使う
public struct KodouBarChart: View {
    public struct Bar { let label: String; let value: Double
        public init(_ label: String, _ value: Double) { self.label = label; self.value = value } }
    let bars: [Bar]
    let max: Double
    let step: Double
    let limit: Double?
    let unit: String
    let title: String
    @StateObject private var hot = KState<Int?>(nil)
    @FocusState private var focus: Int?
    public init(_ title: String, bars: [Bar], max: Double, step: Double, limit: Double? = nil, unit: String = "") {
        self.title = title; self.bars = bars; self.max = max; self.step = step; self.limit = limit; self.unit = unit
    }
    private let plotH: CGFloat = 160

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if limit != nil {
                HStack(spacing: 16) {
                    HStack(spacing: 6) { swatch(blocks: true); Text("上限まで（横縞）") }
                    HStack(spacing: 6) { swatch(blocks: false); Text("上限を超えた分（斜線と +\(unit)）") }
                }.font(.kdMono(12)).foregroundStyle(KD.dim)
            }
            HStack(alignment: .top, spacing: 8) {
                // 縦の目盛り
                ZStack(alignment: .topTrailing) {
                    ForEach(Array(stride(from: 0, through: max, by: step)), id: \.self) { v in
                        Text(fmt(v)).font(.kdMono(12)).foregroundStyle(KD.faint)
                            .alignmentGuide(.top) { d in d.height / 2 - (plotH - CGFloat(v / max) * plotH) }
                    }
                }.frame(width: 28, height: plotH, alignment: .topTrailing)
                VStack(spacing: 4) {
                    GeometryReader { g in
                        ZStack(alignment: .bottomLeading) {
                            grid(g.size)
                            HStack(alignment: .bottom, spacing: 0) {
                                ForEach(bars.indices, id: \.self) { i in barView(i, g.size).frame(maxWidth: .infinity) }
                            }
                            .padding(.horizontal, g.size.width * 0.02)
                            if let limit { limitLine(limit, g.size) }
                        }
                    }
                    .frame(height: plotH)
                    .overlay(alignment: .leading) { Rectangle().fill(KD.rule).frame(width: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(KD.rule).frame(height: 1) }
                    HStack(spacing: 0) { ForEach(bars.indices, id: \.self) { i in Text(bars[i].label).frame(maxWidth: .infinity) } }
                        .font(.kdMono(12)).foregroundStyle(KD.faint).padding(.horizontal, 6)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }

    private func grid(_ s: CGSize) -> some View {
        Canvas { ctx, size in
            for v in stride(from: step, through: max, by: step) {
                let y = size.height - CGFloat(v / max) * size.height
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(KD.ruleSoft), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
            }
        }
    }

    private func limitLine(_ l: Double, _ s: CGSize) -> some View {
        let y = s.height - CGFloat(l / max) * s.height
        return ZStack(alignment: .topTrailing) {
            Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: s.width, y: y)) }
                .stroke(KD.red, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            Text("上限 \(fmt(l))").font(.kdMono(12)).foregroundStyle(KD.red).padding(.horizontal, 4).background(KD.panel)
                .offset(y: y - 18)
        }
        .frame(width: s.width, height: s.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func barView(_ i: Int, _ s: CGSize) -> some View {
        let b = bars[i]
        let h = CGFloat(b.value / max) * s.height
        let over = limit.map { Swift.max(0, b.value - $0) } ?? 0
        let overH = CGFloat(over / max) * s.height
        let lit = hot.v == i || focus == i
        return Button { hot.v = i } label: {
            VStack(spacing: 0) {
                if over > 0 { Text("+\(fmt(over))").font(.kdMono(12)).foregroundStyle(KD.red).padding(.bottom, 2) }
                ZStack(alignment: .top) {
                    KodouBlocks(color: lit ? KD.fg : KD.blue).frame(height: h)
                    if over > 0 {
                        KodouHatch(color: KD.red).frame(height: overH)
                            .overlay(alignment: .top) { Rectangle().fill(KD.red).frame(height: 2) }
                    }
                }
            }
            .frame(width: s.width * 0.09)
            .overlay(alignment: .top) {
                if lit {
                    Text("\(b.label) \(fmt(b.value))\(unit)").font(.kdMono(12)).foregroundStyle(KD.selFg)
                        .padding(.horizontal, 6).padding(.vertical, 1).background(KD.selBg).fixedSize()
                        .offset(y: -24)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focus, equals: i)
        .focusEffectDisabled()
        .kodouFocusRing(focus == i)
        .onHover { hot.v = $0 ? i : (hot.v == i ? nil : hot.v) }
        .zIndex(lit ? 2 : 0)
        .accessibilityLabel(b.label)
        .accessibilityValue("\(fmt(b.value))\(unit)" + (over > 0 ? "、上限を \(fmt(over))\(unit) 超え" : ""))
    }

    private func swatch(blocks: Bool) -> some View {
        Group { if blocks { KodouBlocks(color: KD.blue, block: 3, gap: 1) } else { KodouHatch(color: KD.red).overlay(Rectangle().strokeBorder(KD.red, lineWidth: 1)) } }
            .frame(width: 10, height: 10)
    }
}

/// 下から積んだブロック（6pt の段を 2pt あけて）
struct KodouBlocks: View {
    let color: Color
    var block: CGFloat = 6
    var gap: CGFloat = 2
    var body: some View {
        Canvas { ctx, size in
            var p = Path(), y = size.height
            while y > 0 { let hh = Swift.min(block, y); p.addRect(CGRect(x: 0, y: y - hh, width: size.width, height: hh)); y -= block + gap }
            ctx.fill(p, with: .color(color))
        }
    }
}

/// 斜線
struct KodouHatch: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            ctx.clip(to: Path(CGRect(origin: .zero, size: size)))
            var p = Path(), x = -size.height
            while x < size.width { p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 6 }
            ctx.stroke(p, with: .color(color), lineWidth: 3)
        }
    }
}

/// ヒストグラム。8 分の 1 ブロックで端数まで描き、件数を横に出す。遅い区間は色に加えて ▲ の印を付ける
public struct KodouHistogram: View {
    public struct Bin { let label: String; let count: Int; let hot: Bool
        public init(_ label: String, _ count: Int, hot: Bool = false) { self.label = label; self.count = count; self.hot = hot } }
    let title: String
    let bins: [Bin]
    let scaleMax: Int
    let ticks: [Int]
    let legend: String?
    let width: Int
    public init(_ title: String, bins: [Bin], scaleMax: Int, ticks: [Int], legend: String? = nil, width: Int = 40) {
        self.title = title; self.bins = bins; self.scaleMax = scaleMax; self.ticks = ticks; self.legend = legend; self.width = width
    }
    static func blocks(_ v: Double) -> String {
        let eighths = Int((v * 8).rounded()), full = eighths / 8, rest = eighths % 8
        return String(repeating: "█", count: full) + (rest > 0 ? String(Array("▏▎▍▌▋▊▉")[rest - 1]) : "")
    }
    public var body: some View {
        let lw = bins.map(\.label.count).max() ?? 4
        let cw = ("0" as NSString).size(withAttributes: [.font: KodouFont.mono(13)]).width
        VStack(alignment: .leading, spacing: 1) {
            ForEach(bins.indices, id: \.self) { i in
                let b = bins[i]
                HStack(spacing: cw) {
                    Text(b.label).foregroundStyle(KD.dim).frame(width: CGFloat(lw) * cw, alignment: .trailing)
                    // 8 分の 1 の刻みで端数まで描く（Web は █▉▊… の文字。ここは隙間が出ないよう四角で描く）
                    Rectangle().fill(b.hot ? KD.yellow : KD.blue)
                        .frame(width: (CGFloat(Double(b.count) / Double(scaleMax) * Double(width) * 8).rounded() / 8) * cw, height: 13)
                        .frame(width: CGFloat(width) * cw, alignment: .leading)
                    Spacer(minLength: 0)
                    Text("\(b.count)\(b.hot ? " ▲" : "  ")").foregroundStyle(KD.dim)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(b.label)
                .accessibilityValue("\(b.count) 件" + (b.hot ? "、遅い" : ""))
            }
            HStack(spacing: cw) {
                Color.clear.frame(width: CGFloat(lw) * cw, height: 1)
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(KD.rule).frame(height: 1)
                    ForEach(ticks, id: \.self) { t in
                        Text(t == ticks.last ? "\(t)件" : "\(t)").font(.kdMono(12)).foregroundStyle(KD.faint).fixedSize()
                            .offset(x: CGFloat(t) / CGFloat(scaleMax) * CGFloat(width) * cw, y: 3)
                    }
                }.frame(width: CGFloat(width) * cw, height: 20, alignment: .topLeading)
            }
            if let legend { Text(legend).font(.kdMono(12)).foregroundStyle(KD.dim).padding(.leading, CGFloat(lw + 1) * cw) }
        }
        .font(.kdMono(13))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// スパークライン。文字だけで書く小さな推移。高さが低く値を比べにくいので、今の値と最大を必ず数字で横に添える
public struct KodouSparkline: View {
    let label: String
    let values: [Double]
    let now: String
    let max: String
    public init(_ label: String, values: [Double], now: String, max: String) { self.label = label; self.values = values; self.now = now; self.max = max }
    static func text(_ v: [Double]) -> String {
        let hi = v.max() ?? 1, lo = Swift.min(0, v.min() ?? 0), bars = Array("▁▂▃▄▅▆▇█")
        return String(v.map { bars[Swift.min(7, Int((($0 - lo) / Swift.max(1e-9, hi - lo)) * 7.999))] })
    }
    public var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.kdMono(13)).foregroundStyle(KD.fg).frame(width: 96, alignment: .leading)
            Text(Self.text(values)).font(.kdMono(15)).foregroundStyle(KD.blue).lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 6) { Text(now).fontWeight(.bold); Text("最大 \(max)").foregroundStyle(KD.dim) }.font(.kdMono(13))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("今 \(now)、最大 \(max)")
    }
}
