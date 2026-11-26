import SwiftUI

/// 点の多い時系列。上限つきのリングバッファで、足すたびに一番古い点が消える
@MainActor @Observable
public final class KodouSeries {
    @ObservationIgnored public private(set) var values: [Float]
    @ObservationIgnored public private(set) var head = 0   // 一番古い点
    /// 描き直しの合図。値そのものは観測しない（配列を写さないため）
    public private(set) var version = 0
    public init(_ values: [Float]) { self.values = values }
    public var count: Int { values.count }
    public var last: Float { values[(head + values.count - 1) % values.count] }
    public subscript(i: Int) -> Float { values[(head + i) % values.count] }
    public func push(_ v: Float) { values[head] = v; head = (head + 1) % values.count }
    /// 足し終えたら呼ぶ。frame でまとめると 1 フレームに 1 回になる
    public func commit() { version &+= 1 }
}

/// 折れ線の代わりに、描く幅の 1 列に 1 本（その列の最小から最大まで）を立てる。
/// 何万点あっても描く量は幅の px 数で決まる。threshold を超えた列は warn の色にする
public struct KodouLineChart: View {
    let series: KodouSeries
    var range: ClosedRange<Float> = 0...100
    var threshold: Float? = 80
    var label: String
    public init(_ series: KodouSeries, range: ClosedRange<Float> = 0...100, threshold: Float? = 80, label: String) {
        self.series = series; self.range = range; self.threshold = threshold; self.label = label
    }
    public var body: some View {
        let _ = series.version
        Canvas(rendersAsynchronously: false) { ctx, size in
            let w = max(1, Int(size.width)), h = size.height, n = series.count
            let lo = range.lowerBound, span = range.upperBound - lo
            var normal = Path(), warn = Path()
            for c in 0..<w {
                let a = c * n / w, b = max(a + 1, (c + 1) * n / w)
                var mn = Float.greatestFiniteMagnitude, mx = -Float.greatestFiniteMagnitude
                for i in a..<min(b, n) { let x = series[i]; if x < mn { mn = x }; if x > mx { mx = x } }
                let y1 = (h - CGFloat((mx - lo) / span) * h).rounded(), y2 = (h - CGFloat((mn - lo) / span) * h).rounded()
                let r = CGRect(x: CGFloat(c), y: y1, width: 1, height: max(2, y2 - y1))
                if let t = threshold, mx > t { warn.addRect(r) } else { normal.addRect(r) }
            }
            ctx.fill(normal, with: .color(KD.blue))
            ctx.fill(warn, with: .color(KD.red))
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(summary)
    }
    private var summary: String {
        var mn = Float.greatestFiniteMagnitude, mx = -Float.greatestFiniteMagnitude, sum: Float = 0, over = 0
        for i in 0..<series.count { let v = series[i]; mn = min(mn, v); mx = max(mx, v); sum += v; if let t = threshold, v > t { over += 1 } }
        let avg = sum / Float(max(1, series.count))
        return "\(series.count) 点。最小 \(Int(mn))、最大 \(Int(mx))、平均 \(Int(avg))" + (threshold.map { "。\(Int($0)) を超えたのは \(over) 点" } ?? "")
    }
}
