// よくある書き方の SwiftUI。一覧は List(selection:)、ログは ScrollView＋LazyVStack＋scrollTo、
// グラフは Swift Charts の LineMark に全点。データは @Observable のモデルに配列で持ち、流れごとに Timer を 1 本ずつ
import AppKit
import SwiftUI
import Charts

struct Point: Identifiable { let x: Int; let v: Float; var id: Int { x } }

@MainActor @Observable
final class PlainModel {
    var rows = (0..<SCN.rows).map(row)
    var selection: Int? = 0
    var lines: [LogLine] = []
    var points: [Point]
    @ObservationIgnored private var timers: [Timer] = []
    @ObservationIgnored private let rr = Rng(11)
    @ObservationIgnored private let r2 = Rng(7)
    @ObservationIgnored private var k = 0
    @ObservationIgnored private var n = SCN.points

    init() {
        let s = makeSeries(SCN.points, r2)
        points = s.enumerated().map { Point(x: $0.offset, v: $0.element) }
        // 切り分け用: PLAIN_PAUSE_HIDDEN=1 で、窓が見えていないあいだ Timer を止める（ほかは同じ）
        if ProcessInfo.processInfo.environment["PLAIN_PAUSE_HIDDEN"] != nil {
            NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { [unowned self] n in
                MainActor.assumeIsolated { if let w = n.object as? NSWindow, !w.occlusionState.contains(.visible) { timers.forEach { $0.invalidate() } } }
            }
        }
        timers.append(.scheduledTimer(withTimeInterval: SCN.rowEveryMs / 1000, repeats: true) { [unowned self] _ in MainActor.assumeIsolated {
            let i = Int(rr.next() * 40); rows[i].state = nextState(rows[i].state)
        } })
        timers.append(.scheduledTimer(withTimeInterval: SCN.logEveryMs / 1000, repeats: true) { [unowned self] _ in MainActor.assumeIsolated {
            if lines.count >= SCN.logCap { lines.removeFirst() }
            lines.append(logLine(k)); k += 1
        } })
        timers.append(.scheduledTimer(withTimeInterval: SCN.pointEveryMs / 1000, repeats: true) { [unowned self] _ in MainActor.assumeIsolated {
            let v = nextPoint(points[points.count - 1].v, r2)
            points.removeFirst(); points.append(Point(x: n, v: v)); n += 1
        } })
    }
}

private func stateColor(_ s: String) -> Color { s == "run" ? Color(red: 0.12, green: 0.37, blue: 0.66) : s == "wait" ? Color(red: 0.76, green: 0.25, blue: 0.05) : .primary }
private func lvColor(_ s: String) -> Color { s == "error" ? Color(red: 0.76, green: 0.25, blue: 0.05) : s == "warn" ? Color(red: 0.54, green: 0.35, blue: 0) : .primary }

private struct Panel<C: View>: View {
    let title: String; @ViewBuilder let content: C
    var body: some View {
        GroupBox { content.frame(maxWidth: .infinity, maxHeight: .infinity) } label: { Text(title).font(.system(size: 13, weight: .semibold)) }
    }
}

struct PlainRoot: View {
    @Bindable var m: PlainModel
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                Panel(title: "sessions") {
                    ScrollViewReader { proxy in
                        List(m.rows, selection: $m.selection) { d in
                            HStack {
                                Text(d.hash).frame(width: 64, alignment: .leading)
                                Text(d.who).frame(width: 48, alignment: .leading)
                                Text(d.msg).frame(maxWidth: .infinity, alignment: .leading)
                                Text(d.state).foregroundStyle(stateColor(d.state)).frame(width: 48, alignment: .leading)
                            }.font(.system(size: 13, design: .monospaced)).lineLimit(1)
                        }
                        .onChange(of: m.selection) { _, s in if let s { proxy.scrollTo(s) } }
                    }
                }
                Panel(title: "log") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(m.lines) { l in
                                    HStack {
                                        Text(l.t); Text(l.lv.uppercased()).foregroundStyle(lvColor(l.lv)); Text(l.m)
                                    }.font(.system(size: 12, design: .monospaced)).lineLimit(1).id(l.k)
                                }
                            }
                        }
                        .onChange(of: m.lines.last?.k) { _, k in if let k { proxy.scrollTo(k, anchor: .bottom) } }
                    }
                }
            }.frame(height: 420)
            Panel(title: "cpu") {
                // 切り分け用: PLAIN_NO_CHART=1 で Swift Charts を外し、ほかは同じにする
                if ProcessInfo.processInfo.environment["PLAIN_NO_CHART"] == nil { Chart(m.points) { p in
                    LineMark(x: .value("t", p.x), y: .value("cpu", p.v)).lineStyle(StrokeStyle(lineWidth: 1))
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden) }
            }.frame(height: 300)
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
