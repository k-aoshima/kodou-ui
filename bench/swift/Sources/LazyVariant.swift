// 一覧とログを NSTableView でなく SwiftUI の LazyVStack で作った版（どちらを KodouUI に採るか決めるための比較）。
// タイマー 1 本・行ごとの観測・リングバッファ・Canvas のグラフは Kodou 版と同じ
import AppKit
import SwiftUI
import KodouUI

@MainActor @Observable
final class RowBox { var row: SessionRow; init(_ r: SessionRow) { row = r } }

@MainActor @Observable
final class LazyModel {
    @ObservationIgnored let ticker = KodouTicker()
    @ObservationIgnored let rows = (0..<SCN.rows).map { RowBox(row($0)) }
    var act = 0
    @ObservationIgnored var ring = KodouRing<LogLine>(capacity: SCN.logCap)
    var logVersion = 0
    @ObservationIgnored let series: KodouSeries
    @ObservationIgnored private let rr = Rng(11)
    @ObservationIgnored private let r2 = Rng(7)
    @ObservationIgnored private var k = 0

    init() {
        series = KodouSeries(makeSeries(SCN.points, r2))
        ticker.every(SCN.rowEveryMs) { [unowned self] in let i = Int(rr.next() * 40); rows[i].row.state = nextState(rows[i].row.state) }
        ticker.every(SCN.logEveryMs) { [unowned self] in
            ring.append(logLine(k)); k += 1
            ticker.frame("log") { [unowned self] in logVersion &+= 1 }
        }
        ticker.every(SCN.pointEveryMs) { [unowned self] in
            series.push(nextPoint(series.last, r2))
            ticker.frame("cv") { [unowned self] in series.commit() }
        }
    }
}

private struct LazyRow: View {
    let box: RowBox; let on: Bool
    var body: some View {
        let d = box.row
        HStack(spacing: 8) {
            Text(d.hash).frame(width: 64, alignment: .leading)
            Text(d.who).frame(width: 48, alignment: .leading)
            Text(d.msg).frame(maxWidth: .infinity, alignment: .leading)
            Text(d.state).frame(width: 48, alignment: .leading)
                .foregroundStyle(on ? KD.selFg : d.state == "run" ? KD.blue : d.state == "wait" ? KD.red : KD.fg)
        }
        .lineLimit(1).font(.kdMono(13)).padding(.horizontal, 6).frame(height: 22)
        .foregroundStyle(on ? KD.selFg : KD.fg).background(on ? KD.selBg : .clear)
        .accessibilityElement(children: .combine)
    }
}

private struct LazySessions: View {
    let m: LazyModel
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<SCN.rows, id: \.self) { i in LazyRow(box: m.rows[i], on: m.act == i).id(i) }
                }
            }
            .onChange(of: m.act) { _, a in proxy.scrollTo(a) }
        }
    }
}

private struct LazyLog: View {
    let m: LazyModel
    var body: some View {
        let _ = m.logVersion
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<m.ring.count, id: \.self) { i in
                        let l = m.ring[i]
                        HStack(spacing: 7) {
                            Text(l.t).frame(width: 66, alignment: .leading)
                            Text(l.lv.uppercased()).frame(width: 44, alignment: .leading)
                                .foregroundStyle(l.lv == "error" ? KD.red : l.lv == "warn" ? KD.yellow : KD.fg)
                            Text(l.m).frame(maxWidth: .infinity, alignment: .leading)
                        }.lineLimit(1).font(.kdMono(12)).frame(height: 19).id(i)
                    }
                }
            }
            .onChange(of: m.logVersion) { _, _ in proxy.scrollTo(m.ring.count - 1, anchor: .bottom) }
        }
    }
}

struct LazyRoot: View {
    let m: LazyModel
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                KodouBox("sessions") { LazySessions(m: m) }
                KodouBox("log") { LazyLog(m: m) }
            }.frame(height: 420)
            KodouBox("cpu") { KodouLineChart(m.series, label: "cpu") }.frame(height: 300)
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KD.bg)
    }
}
