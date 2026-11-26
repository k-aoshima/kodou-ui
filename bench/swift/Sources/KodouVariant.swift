// Kodou-ui の決まりで作った版。タイマー 1 本（KodouTicker）、一覧とログは NSTableView で見えている行だけ、
// 変わった行だけ描き直す、ログはリングバッファ、グラフは描く幅の 1 列に 1 本、窓が隠れたら止める
import AppKit
import SwiftUI
import KodouUI

@MainActor
final class KodouSessions: KodouRowsSource {
    var data = (0..<SCN.rows).map(row)
    let rows: KodouRowsController
    init() {
        rows = KodouRowsController(columns: [.init(.ch(8)), .init(.ch(6)), .init(.fill), .init(.ch(6))], rowHeight: 22, label: "sessions")
        rows.source = self
    }
    var rowCount: Int { data.count }
    func cells(_ i: Int) -> [KodouCell] {
        let d = data[i]
        let c: NSColor? = d.state == "run" ? KodouColor.blue : d.state == "wait" ? KodouColor.red : nil
        return [.init(d.hash), .init(d.who), .init(d.msg), .init(d.state, c)]
    }
}

@MainActor
final class KodouModel {
    let ticker = KodouTicker()
    let sessions = KodouSessions()
    let log: KodouLog<LogLine>
    let series: KodouSeries
    private let rr = Rng(11), r2 = Rng(7)
    private var k = 0

    init() {
        log = KodouLog(capacity: SCN.logCap, columns: [.init(.ch(9)), .init(.ch(6)), .init(.fill)], ticker: ticker) { l in
            let c: NSColor? = l.lv == "error" ? KodouColor.red : l.lv == "warn" ? KodouColor.yellow : nil
            return [.init(l.t), .init(l.lv.uppercased(), c), .init(l.m)]
        }
        if let b = ProcessInfo.processInfo.environment["KODOU_LOG_BATCH_MS"].flatMap(Double.init) { log.batchMs = b }  // 比べるため
        series = KodouSeries(makeSeries(SCN.points, r2))
        ticker.every(SCN.rowEveryMs) { [unowned self] in
            let i = Int(rr.next() * 40)
            sessions.data[i].state = nextState(sessions.data[i].state)
            sessions.rows.reload(rows: [i])
        }
        ticker.every(SCN.logEveryMs) { [unowned self] in log.append(logLine(k)); k += 1 }
        ticker.every(SCN.pointEveryMs) { [unowned self] in
            series.push(nextPoint(series.last, r2))
            ticker.frame("cv") { [unowned self] in series.commit() }
        }
    }
}

struct KodouRoot: View {
    let m: KodouModel
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                KodouBox("sessions") { KodouRows(m.sessions.rows) }
                KodouBox("log") { KodouRows(m.log.rows) }
            }.frame(height: 420)
            KodouBox("cpu") { KodouLineChart(m.series, label: "cpu") }.frame(height: 300)
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KD.bg)
    }
}
