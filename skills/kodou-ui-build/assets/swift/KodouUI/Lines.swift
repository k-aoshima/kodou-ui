import Charts
import SwiftUI

/// 点の少ない折れ線（系列ごとに数十点まで）。系列は色に加えて点の形（● ◆）と線の種類（実線・破線）で分け、
/// 線の端に系列の名前を書く。境目の線は赤の破線に文字を添える。触れると縦の線と値を出す。
/// 何千点もあるときは Swift Charts に渡さず、KodouLineChart（描く幅の 1 列に 1 本）を使う
public struct KodouLines: View {
    public struct Series: Identifiable {
        public let id: String
        let values: [Double]
        let dashed: Bool
        let color: Color
        let diamond: Bool
        public init(_ name: String, values: [Double], color: Color = KD.blue, dashed: Bool = false, diamond: Bool = false) {
            id = name; self.values = values; self.color = color; self.dashed = dashed; self.diamond = diamond
        }
    }
    let title: String
    let labels: [String]
    let series: [Series]
    let range: ClosedRange<Double>
    let threshold: (Double, String)?
    @StateObject private var hover = KState<Int?>(nil)
    public init(_ title: String, labels: [String], series: [Series], range: ClosedRange<Double>, threshold: (Double, String)? = nil) {
        self.title = title; self.labels = labels; self.series = series; self.range = range; self.threshold = threshold
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                ForEach(series) { s in
                    HStack(spacing: 6) {
                        Rectangle().stroke(s.color, style: StrokeStyle(lineWidth: 2, dash: s.dashed ? [4, 3] : [])).frame(width: 18, height: 0.5)
                        Text(s.diamond ? "◆" : "●").foregroundStyle(s.color)
                        Text(s.id)
                    }
                }
            }
            .font(.kdMono(12)).foregroundStyle(KD.dim)
            Chart {
                ForEach(series) { s in
                    ForEach(s.values.indices, id: \.self) { i in
                        LineMark(x: .value("x", i), y: .value(s.id, s.values[i]), series: .value("s", s.id))
                            .foregroundStyle(s.color)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: s.dashed ? [4, 3] : []))
                        PointMark(x: .value("x", i), y: .value(s.id, s.values[i]))
                            .foregroundStyle(s.color)
                            .symbol(s.diamond ? .diamond : .circle).symbolSize(30)
                    }
                    if let last = s.values.indices.last {
                        PointMark(x: .value("x", last), y: .value(s.id, s.values[last])).opacity(0)
                            .annotation(position: .trailing, spacing: 4) { Text(s.id).font(.kdMono(12, weight: .bold)).foregroundStyle(s.color) }
                    }
                }
                if let (v, label) = threshold {
                    RuleMark(y: .value("境目", v)).foregroundStyle(KD.red).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .annotation(position: .top, alignment: .trailing) { Text(label).font(.kdMono(12)).foregroundStyle(KD.red) }
                }
                if let h = hover.v {
                    RuleMark(x: .value("x", h)).foregroundStyle(KD.fg).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .annotation(position: .top) {
                            Text(([labels[h]] + series.map { "\($0.id) \(fmt($0.values[h]))" }).joined(separator: "  "))
                                .font(.kdMono(12)).foregroundStyle(KD.selFg).padding(.horizontal, 6).background(KD.selBg)
                        }
                }
            }
            .chartYScale(domain: range)
            .chartXAxis {
                AxisMarks(values: Array(labels.indices)) { v in
                    AxisValueLabel { if let i = v.as(Int.self), labels.indices.contains(i) { Text(labels[i]).font(.kdMono(12)).foregroundStyle(KD.faint) } }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [1, 2])).foregroundStyle(KD.ruleSoft)
                    AxisValueLabel().font(.kdMono(12)).foregroundStyle(KD.faint)
                }
            }
            .chartOverlay { proxy in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { p in
                        if case .active(let pt) = p, let x: Int = proxy.value(atX: pt.x) { hover.v = min(labels.count - 1, max(0, x)) } else { hover.v = nil }
                    }
            }
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityValue(series.map { s in "\(s.id)：" + s.values.indices.map { "\(labels[$0]) \(fmt(s.values[$0]))" }.joined(separator: "、") }.joined(separator: "。"))
        }
    }
    private func fmt(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }
}
