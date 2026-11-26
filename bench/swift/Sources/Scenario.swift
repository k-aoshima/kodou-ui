// Web のベンチ（bench/src/scenario.js）と同じ中身。数と速さを変えるときは両方を直す
import Foundation

enum SCN {
    static let rows = 10000, rowEveryMs = 200.0, logEveryMs = 20.0, logCap = 2000, points = 20000, pointEveryMs = 100.0
}
let VERBS = ["直す", "足す", "消す", "揃える", "分ける", "速くする", "見直す", "軽くする"]
let OBJ = ["入力欄", "ステータスライン", "ログ", "表の並べ替え", "トークン", "ツリー", "ダイアログ", "グラフの目盛り", "リスト", "タグ入力"]
let WHO = ["aki", "mika", "ren", "bot"]
let STATES = ["idle", "run", "wait", "done"]

func h32(_ i: Int) -> UInt32 {
    var x = UInt32(truncatingIfNeeded: UInt64(i + 1) &* 2654435761)
    x ^= x >> 15; x = x &* 2246822519; x ^= x >> 13; return x
}
struct SessionRow: Identifiable, Equatable { let id: Int; let hash: String; let who: String; let msg: String; var state: String }
func row(_ i: Int) -> SessionRow {
    let h = h32(i), hex = String(h, radix: 16), padded = String(repeating: "0", count: max(0, 8 - hex.count)) + hex
    return SessionRow(id: i, hash: String(padded.prefix(7)), who: WHO[Int(h % 4)], msg: "\(OBJ[Int((h >> 3) % 10)])を\(VERBS[Int((h >> 7) % 8)])", state: STATES[Int(h % 4)])
}
func nextState(_ s: String) -> String { STATES[(STATES.firstIndex(of: s)! + 1) % 4] }

struct LogLine: Identifiable { let k: Int; let lv: String; let t: String; let m: String; var id: Int { k } }
let SRC: [(String, String)] = [("info", "GET /api/session 200 12ms"), ("info", "GET /api/usage 200 8ms"), ("warn", "slow query: SELECT * FROM events 412ms"),
                               ("info", "POST /api/run 202 4ms"), ("error", "job 7f3a: exit 1  TypeError: cannot read \"chips\" of undefined"), ("info", "GET /health 200 1ms")]
func logLine(_ k: Int) -> LogLine {
    let (lv, m) = SRC[k % SRC.count]
    return LogLine(k: k, lv: lv, t: String(format: "00:%02d:%02d", (k / 50) % 60, k % 50), m: m)
}
/// 決まった順の乱数（どの版も同じ値になる）
final class Rng { var seed: Double; init(_ s: Double = 7) { seed = s }; func next() -> Double { seed = (seed * 16807).truncatingRemainder(dividingBy: 2147483647); return seed / 2147483647 } }
func makeSeries(_ n: Int, _ r: Rng) -> [Float] {
    var d = [Float](repeating: 0, count: n); var v = 30.0
    for i in 0..<n { v += (r.next() - 0.5) * 6 + (40 - v) * 0.01; if r.next() < 0.0015 { v += 40 }; v = max(1, min(99, v)); d[i] = Float(v) }
    return d
}
func nextPoint(_ prev: Float, _ r: Rng) -> Float {
    var v = Double(prev) + (r.next() - 0.5) * 6 + (40 - Double(prev)) * 0.01; if r.next() < 0.0015 { v += 40 }; return Float(max(1, min(99, v)))
}
