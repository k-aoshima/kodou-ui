// 手当てをした SwiftUI（Web の react-tuned に当たる）。SwiftUI の普通の範囲でよく勧められる手当てだけを入れ、AppKit には逃げない。
//   1. @Observable を行ごとに分け、変わった行だけが描き直されるようにする（RowBox）
//   2. List の行は Equatable な View にし、id は行番号で固定する
//   3. ログの追記は溜めておき、50ms ごとにまとめて配列へ反映する。末尾の追従は defaultScrollAnchor(.bottom) に任せる
//   4. Swift Charts に渡す点は、描く幅の 1 列に最小と最大の 2 点まで間引く（1,200 列）
//   5. タイマーは .task の中の 1 本のループにまとめ、窓が見えていないあいだは止める
import AppKit
import SwiftUI
import Charts

@MainActor @Observable
final class TunedModel {
    @ObservationIgnored let rows = (0..<SCN.rows).map { RowBox(row($0)) }
    var selection: Int? = 0
    var visible = true
    private(set) var lines: [LogLine] = []
    private(set) var chart: [Point] = []
    @ObservationIgnored private var pending: [LogLine] = []
    @ObservationIgnored private var pts: [Float]
    @ObservationIgnored private var head = 0
    @ObservationIgnored private var n = SCN.points
    @ObservationIgnored private let rr = Rng(11)
    @ObservationIgnored private let r2 = Rng(7)
    @ObservationIgnored private var k = 0
    @ObservationIgnored private var last: [Double] = [0, 0, 0, 0]

    // 切り分け用: TUNED_ABLATE=chart で間引きを外す（全点を渡す）、=log でログを 20ms ごとに 1 行ずつ反映する
    @ObservationIgnored private let ablate = ProcessInfo.processInfo.environment["TUNED_ABLATE"] ?? ""

    init() { pts = makeSeries(SCN.points, r2); chart = decimated() }

    /// 1 本のループから呼ぶ。期限が来た流れだけを進める
    func step(_ now: Double) {
        func due(_ i: Int, _ ms: Double) -> Int {
            if last[i] == 0 { last[i] = now; return 1 }
            let c = Int((now - last[i]) / ms); last[i] += Double(c) * ms; return min(c, 10)
        }
        for _ in 0..<due(0, SCN.rowEveryMs) { let i = Int(rr.next() * 40); rows[i].row.state = nextState(rows[i].row.state) }
        for _ in 0..<due(1, SCN.logEveryMs) { pending.append(logLine(k)); k += 1 }
        var pushed = false
        for _ in 0..<due(2, SCN.pointEveryMs) {
            pts[head] = nextPoint(pts[(head + SCN.points - 1) % SCN.points], r2); head = (head + 1) % SCN.points; n += 1; pushed = true
        }
        if pushed { chart = decimated() }
        if (ablate == "log" || due(3, 50) > 0), !pending.isEmpty {
            var next = lines; next.append(contentsOf: pending); pending.removeAll(keepingCapacity: true)
            if next.count > SCN.logCap { next.removeFirst(next.count - SCN.logCap) }
            lines = next
        }
    }
    func pause() { last = [0, 0, 0, 0] }

    /// 描く幅の 1 列に、その列の最小と最大の 2 点（react-tuned の decimate と同じ）
    private func decimated(cols: Int = 1200) -> [Point] {
        let N = SCN.points
        if ablate == "chart" { return (0..<N).map { Point(x: n - N + $0, v: pts[(head + $0) % N]) } }; var out: [Point] = []; out.reserveCapacity(cols * 2)
        let base = n - N
        for c in 0..<cols {
            let a = c * N / cols, b = max(a + 1, (c + 1) * N / cols)
            var mn = a, mx = a
            for i in a..<b { let v = pts[(head + i) % N]; if v < pts[(head + mn) % N] { mn = i }; if v > pts[(head + mx) % N] { mx = i } }
            let p1 = Point(x: base + min(mn, mx), v: pts[(head + min(mn, mx)) % N]), p2 = Point(x: base + max(mn, mx), v: pts[(head + max(mn, mx)) % N])
            out.append(p1); if mn != mx { out.append(p2) }
        }
        return out
    }
}

private func tunedColor(_ s: String) -> Color {
    switch s { case "run": Color(red: 0.12, green: 0.37, blue: 0.66); case "wait", "error": Color(red: 0.76, green: 0.25, blue: 0.05); case "warn": Color(red: 0.54, green: 0.35, blue: 0); default: .primary }
}

private struct TunedRow: View, Equatable {
    let box: RowBox
    nonisolated static func == (a: TunedRow, b: TunedRow) -> Bool { a.box === b.box }
    var body: some View {
        let d = box.row
        HStack {
            Text(d.hash).frame(width: 64, alignment: .leading)
            Text(d.who).frame(width: 48, alignment: .leading)
            Text(d.msg).frame(maxWidth: .infinity, alignment: .leading)
            Text(d.state).foregroundStyle(tunedColor(d.state)).frame(width: 48, alignment: .leading)
        }.font(.system(size: 13, design: .monospaced)).lineLimit(1)
    }
}

private struct TunedLogRow: View, Equatable {
    let l: LogLine
    nonisolated static func == (a: TunedLogRow, b: TunedLogRow) -> Bool { a.l.k == b.l.k }
    var body: some View {
        HStack {
            Text(l.t); Text(l.lv.uppercased()).foregroundStyle(tunedColor(l.lv)); Text(l.m)
        }.font(.system(size: 12, design: .monospaced)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TunedChart: View {
    let m: TunedModel
    var body: some View {
        Chart(m.chart) { p in
            LineMark(x: .value("t", p.x), y: .value("cpu", p.v)).lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
    }
}

private struct TunedSessions: View {
    @Bindable var m: TunedModel
    var body: some View {
        ScrollViewReader { proxy in
            List(selection: $m.selection) {
                ForEach(0..<SCN.rows, id: \.self) { i in TunedRow(box: m.rows[i]).equatable() }
            }
            .onChange(of: m.selection) { _, s in if let s { proxy.scrollTo(s) } }
        }
    }
}

private struct TunedLog: View {
    let m: TunedModel
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(m.lines) { l in TunedLogRow(l: l).equatable() }
            }
        }
        .defaultScrollAnchor(.bottom)
    }
}

private struct TunedPanel<C: View>: View {
    let title: String; @ViewBuilder let content: C
    var body: some View {
        GroupBox { content.frame(maxWidth: .infinity, maxHeight: .infinity) } label: { Text(title).font(.system(size: 13, weight: .semibold)) }
    }
}

struct TunedRoot: View {
    let m: TunedModel
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                TunedPanel(title: "sessions") { TunedSessions(m: m) }
                TunedPanel(title: "log") { TunedLog(m: m) }
            }.frame(height: 420)
            TunedPanel(title: "cpu") { TunedChart(m: m) }.frame(height: 300)
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 窓が見えていないあいだはループを止める
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { n in
            if let w = n.object as? NSWindow { m.visible = w.occlusionState.contains(.visible) }
        }
        // （@State はこの環境の Command Line Tools ではマクロが無くて使えないので、モデルに持つ）
        .task(id: m.visible) {
            guard m.visible else { m.pause(); return }
            while !Task.isCancelled {
                m.step(CACurrentMediaTime() * 1000)
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }
}
