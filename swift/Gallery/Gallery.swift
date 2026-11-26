// KodouUI の部品を並べて見る窓。swift/gallery.sh で作って開く。
// --shot <フォルダ> を付けると、頁ごと・明暗ごとに PNG を書き出し、いくつかの状態（入力の誤り、候補を開く、並べ替え）も作って終わる
import AppKit
import SwiftUI
import KodouUI

// MARK: データ

@MainActor
final class Files: KodouTableSource {
    struct F { let name: String; let size: Int; let days: Int }
    var all: [F] = (0..<1000).map { i in F(name: "src/part-\(String(format: "%04d", (i * 7919) % 1000)).swift", size: (i * 2654435761) % 90000 + 120, days: (i * 31) % 400) }
    var order: [Int] = Array(0..<1000)
    var rowCount: Int { order.count }
    func cell(_ row: Int, _ column: String) -> KodouCell {
        let f = all[order[row]]
        switch column {
        case "name": return .init(f.name)
        case "size": return .init(f.size.formatted())
        default: return .init(f.days == 0 ? "今日" : "\(f.days)日前", f.days > 300 ? KodouColor.faint : nil)
        }
    }
    func sort(by column: String, ascending: Bool) {
        order.sort { a, b in
            let x = all[a], y = all[b]
            switch column {
            case "name": return ascending ? x.name < y.name : x.name > y.name
            case "size": return ascending ? x.size < y.size : x.size > y.size
            default: return ascending ? x.days < y.days : x.days > y.days
            }
        }
    }
}

@MainActor
final class Commits: KodouRowsSource {
    let msgs = ["ステータスラインに押したキーを出す", "ログの追いかけを止められるようにする", "表の並べ替えを速くする", "入力欄の誤りを離れてから出す", "ツリーの罫線を揃える", "トークンを書き出す"]
    var rowCount: Int { 10000 }
    func cells(_ i: Int) -> [KodouCell] {
        let h = String(format: "%07x", (i &* 2654435761) & 0xFFFFFFF)
        return [.init(h, KodouColor.yellow), .init(["aki", "mika", "ren"][i % 3], KodouColor.cyan), .init(msgs[i % msgs.count]), .init("\(i % 59 + 1)分前", KodouColor.faint)]
    }
}

struct Line { let t: String; let lv: String; let m: String }

final class GalleryState: ObservableObject {
    @Published var page = 0
    @Published var branch = ""
    @Published var status = "部品の見本"
    @Published var a = true
    @Published var b = false
    @Published var c = false
    @Published var fmt = true
    @Published var ai = false
    @Published var merge = "squash"
    @Published var sel = 0
    @Published var tab = 0
    @Published var pg = 3
    @Published var par = 4
    @Published var mem = 5
    @Published var msg = "ステータスラインに押したキーを出す\n\nモードの横に、いま押したキーを流して見せる。\n入力欄の中では出さず、モードを INSERT にする。"
    @Published var tags = ["ui", "tui"]
    @Published var alerts = [true, true, true, true]
}

// MARK: 頁

struct Gallery: View {
    @ObservedObject var s: GalleryState
    let toasts: KodouToasts
    let table: KodouTableController
    let tree: KodouTreeController
    let rows: KodouRowsController
    let log: KodouLog<Line>
    let series: KodouSeries
    static let pages = ["入力", "表示", "状態とグラフ", "重ね"]

    var body: some View {
        VStack(spacing: 0) {
            KodouTabs(Self.pages.map { KodouTabs.Tab($0) }, selection: $s.page)
            Group {
                switch s.page {
                case 0: inputs
                case 1: display
                case 2: status
                default: overlays
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(KD.bg)
        .overlay(alignment: .bottom) { KodouStatusLine(mode: "NORMAL", message: s.status, keys: [("?", "キー"), ("q", "閉じる")]) }
        .overlay { KodouToastHost(toasts, bottomInset: 26) }
    }

    // 入力
    var inputs: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 18) {
                KodouBox("ボタン") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            KodouButton("マージする", key: "⌘⏎", kind: .primary) {}
                            KodouButton("ブランチを切る") {}
                            KodouButton("閉じる", key: "Esc", kind: .ghost) {}
                            KodouButton("削除する", kind: .danger) {}
                            KodouButton("コピー", icon: "copy") {}
                        }
                        HStack(spacing: 4) {
                            Text("fix/log-follow を削除しました。").font(.kdRead(13.5))
                            Button("取り消し") { s.status = "取り消しました" }.buttonStyle(KodouButtonStyle(.link))
                        }
                        HStack(spacing: 10) {
                            KodouButton("小 sm", size: .sm) {}
                            KodouButton("中 md") {}
                            KodouButton("大 lg", size: .lg) {}
                            KodouButton("保存する") {}.disabled(true)
                        }
                    }
                }
                KodouBox("チェック・ラジオ・スイッチ") {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 0) {
                            Toggle("すべてのテスト", isOn: .constant(true)).toggleStyle(KodouCheckStyle(mixed: s.a != s.b))
                            Toggle("単体テスト", isOn: $s.a).toggleStyle(KodouCheckStyle()).padding(.leading, 28)
                            Toggle("結合テスト", isOn: $s.b).toggleStyle(KodouCheckStyle()).padding(.leading, 28)
                            Toggle("E2E（ブラウザが無いため使えません）", isOn: $s.c).toggleStyle(KodouCheckStyle()).padding(.leading, 28).disabled(true)
                        }
                        KodouRadioGroup("マージの方法", selection: $s.merge, options: [.init("squash", "squash", note: "1つにまとめる"), .init("merge", "merge", note: "コミットを残す"), .init("rebase", "rebase", note: "一直線に並べる")])
                            .frame(width: 280)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Toggle("保存したら整形する", isOn: $s.fmt).toggleStyle(KodouSwitchStyle(note: "prettier"))
                        Toggle("AI の変更を自動で適用する", isOn: $s.ai).toggleStyle(KodouSwitchStyle(note: "切なら毎回確認"))
                    }.frame(width: 440).padding(.top, 8)
                }
                KodouBox("セレクト・コンボボックス・メニュー") {
                    HStack(alignment: .top, spacing: 20) {
                        KodouSelect("比べるブランチ", options: ["main", "develop", "feat/key-cast", "fix/log-follow", "spike/agent-steer"], selection: $s.sel)
                        KodouSelect("無効", options: ["main"], selection: .constant(0)).disabled(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("操作").font(.kdRead(13, weight: .bold))
                            KodouMenu("操作", items: [
                                .init("開く", key: "o"), .init("名前を変える", key: "r"), .init("複製する", key: "d"),
                                .init("削除する", key: "x", danger: true, separatorBefore: true),
                            ])
                        }
                    }
                    KodouCombo("パッケージを追加", prefix: "npm i", placeholder: "名前で探す",
                               items: ["react", "react-dom", "react-window", "recharts", "zod", "vite", "vitest", "typescript", "eslint", "prettier", "esbuild", "puppeteer-core"],
                               help: "候補は使われた回数の順で、並びは変わりません") { s.status = "\($0) を足しました" }
                        .frame(width: 440).padding(.top, 12)
                }
            }.frame(width: 640)
            VStack(alignment: .leading, spacing: 18) {
                KodouBox("テキスト入力") {
                    KodouTextField("ブランチ名", text: $s.branch, prefix: "feat/", help: "英小文字・数字・ハイフン。40 字まで") { v in
                        if v.isEmpty { return .none }
                        if v == "agent-steer" { return .error("agent-steer はもうあります。別の名前にしてください", now: true) }
                        if v.range(of: "^[a-z0-9-]+$", options: .regularExpression) == nil { return .error("英小文字・数字・ハイフンだけにしてください（今は「\(v)」）") }
                        return .ok("feat/\(v) を作れます")
                    }
                }
                KodouBox("数値・スライダー") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 24) {
                            KodouStepper("並列数", value: $s.par, range: 1...8, help: "1〜8。↑↓ で 1 つ、⇧ で最大・最小") { v in v == 8 ? "8 が上限です（CPU のコア数）" : v == 1 ? "1 より少なくはできません" : "" }
                            KodouStepper("無効", value: .constant(2), range: 1...8).disabled(true)
                        }
                        KodouSlider("メモリの上限", index: $s.mem, steps: (1...16).map { "\($0)G" }, ticks: [0, 5, 10, 15]) { i in "上限 \(i + 1)G。読み込めるローカルモデルの目安は \(max(1, (i + 1) * 2 / 3))B まで" }
                    }
                }
                KodouBox("テキストエリア") {
                    KodouTextArea("コミットメッセージ", text: $s.msg, help: "1行目は件名で50字まで、2行目は空けます", firstLineLimit: 50) { i, l in
                        i == 0 ? l.count <= 50 : i == 1 ? l.isEmpty : true
                    }.frame(height: 150)
                }
                KodouBox("タグ入力") { KodouTagInput("ラベル", tags: $s.tags, max: 3) }
            }
        }
    }

    // 表示
    var display: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 18) {
                KodouBox("タブ・パンくず・ページ送り", padding: .init(top: 12, leading: 0, bottom: 12, trailing: 0)) {
                    VStack(alignment: .leading, spacing: 12) {
                        KodouTabs([.init("概要"), .init("変更", count: 12), .init("コミット", count: 3), .init("チェック", count: 1), .init("デプロイ", disabled: true)], selection: $s.tab)
                        Text("この PR は、入力の言い方をチップに置き換えて見せます。").font(.kdRead(14)).padding(.horizontal, 14)
                        KodouCrumbs(["~", "Project", "kodou-ui", "catalog", "index.html"]) { s.status = "\($0) 段目へ戻ります" }.padding(.horizontal, 14)
                        KodouPager(page: $s.pg, pages: 12, perPage: 20, total: 236).padding(.horizontal, 14)
                    }
                }
                KodouBox("長いリスト（1万行。j / k で動き、Space で複数選ぶ）", padding: .init(top: 12, leading: 0, bottom: 4, trailing: 0)) { KodouRows(rows).frame(height: 168) }
                KodouBox("表") { KodouTable(table).frame(height: 190) }
                KodouBox("ログ") { KodouRows(log.rows).frame(height: 120) }
            }.frame(width: 640)
            VStack(alignment: .leading, spacing: 18) {
                KodouBox("ツリー", padding: .init(top: 12, leading: 0, bottom: 4, trailing: 0)) { KodouTree(tree).frame(height: 216) }
                KodouBox("キーと値") {
                    KodouKeyValue([("node", "v20.12.2"), ("npm", "10.5.0"), ("リポジトリ", "github.com/example/kodou-ui"), ("ブランチ", "feat/key-cast"), ("ポート", "8080")])
                }
                KodouBox("キーの表示") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow { KodouKey("Esc"); Text("1つのキー（塗り）").font(.kdRead(13)).foregroundStyle(KD.dim) }
                        GridRow { KodouKey("⌘", "K", style: .chord); Text("同時に押す（枠）").font(.kdRead(13)).foregroundStyle(KD.dim) }
                        GridRow { KodouKey("g", "g", style: .sequence); Text("続けて押す（矢印でつなぐ）").font(.kdRead(13)).foregroundStyle(KD.dim) }
                    }
                }
                KodouBox("区切り線") {
                    VStack(spacing: 14) { KodouDivider(); KodouDivider(.dashed); KodouDivider(.double); KodouDivider(label: "今日") }
                }
                KodouBox("空の状態") {
                    KodouEmpty(icon: "box", title: "まだ開いている PR はありません", message: "feat/ で始まるブランチから作れます。") {
                        KodouButton("PR を作る", kind: .primary) {}
                        KodouButton("絞り込みを外す", kind: .ghost) {}
                    }
                }
            }
        }
    }

    // 状態とグラフ
    var status: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                KodouAlert(.info, "新しい版 1.5.0 があります。変更点を確かめてから更新できます。", onClose: {})
                KodouAlert(.warn, "未コミットの変更が3ファイルあります。このまま切り替えると、変更は持ち越されます。", onClose: {}) {
                    KodouButton("変更を見る", size: .sm) {}; KodouButton("退避して切り替える", size: .sm) {}
                }
                KodouAlert(.err, "ビルドに失敗しました。src/ui/Chip.tsx の12行目で、label に数値を渡しています。文字列に直すか、String(n) で包むと通ります。",
                           detailTitle: "エラーの詳細（TS2322）", detail: "src/ui/Chip.tsx:12:5 - error TS2322: Type 'number' is not assignable to type 'string'.", onClose: {}) {
                    KodouButton("場所を開く", size: .sm) {}; KodouButton("もう一度ビルドする", size: .sm) {}
                }
                KodouBox("バッジと状態") {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) { KodouBadge("✓ 通過", tone: .ok); KodouBadge("✗ 失敗", tone: .err); KodouBadge("◆ 待ち", tone: .warn); KodouBadge("v1.4.0") }
                            HStack(spacing: 8) { KodouBadge("merged", tone: .ok, solid: false); KodouBadge("conflict", tone: .err, solid: false); KodouBadge("draft", solid: false); KodouCount(12) }
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            KodouStatusDot("動いています", .running); KodouStatusDot("起動中", .starting); KodouStatusDot("止まっています", .stopped); KodouStatusDot("未設定", .unset)
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        KodouBootLine(.ok, "データベースにつながりました"); KodouBootLine(.warn, "空きメモリが 2.1G です（3G を下回りました）"); KodouBootLine(.err, "ポート 8080 は node が使っています")
                    }.padding(.top, 10)
                }
                KodouBox("進捗・スピナー") {
                    VStack(alignment: .leading, spacing: 10) {
                        KodouProgress("ビルド", done: 43, total: 50, meta: "43/50 ファイル 2.7秒 いま: src/ui/part-44.tsx", steps: ["取得", "依存", "ビルド", "テスト", "配置"], current: 4)
                        KodouSpinner("依存を取得中", delay: 0) { _ in "40/112" }
                    }
                }
                KodouBox("折れ線（p95 の応答時間 ms）") {
                    KodouLines("p95 の応答時間", labels: ["月", "火", "水", "木", "金", "土", "日"],
                               series: [.init("api", values: [120, 135, 128, 190, 172, 110, 98]), .init("web", values: [80, 92, 85, 101, 140, 76, 70], color: KD.magenta, dashed: true, diamond: true)],
                               range: 0...220, threshold: (160, "目標 160")).frame(height: 150)
                }
            }.frame(width: 640)
            VStack(alignment: .leading, spacing: 14) {
                KodouBox("メーター") {
                    VStack(alignment: .leading, spacing: 6) {
                        KodouMeter("Mem", value: 13.6, max: 16, text: "13.6/16G")
                        KodouMeter("Disk", value: 412, max: 512, text: "412/512G")
                        KodouMeter("CPU", value: 38, max: 100, text: "38%")
                    }
                }
                KodouBox("棒グラフ（1日のビルド時間・分）") {
                    KodouBarChart("1日のビルド時間", bars: [.init("月", 41), .init("火", 57), .init("水", 35), .init("木", 71), .init("金", 64), .init("土", 11), .init("日", 0)], max: 80, step: 20, limit: 60, unit: "分")
                }
                KodouBox("ヒストグラム（テスト1件あたりの時間）") {
                    KodouHistogram("テスト1件あたりの時間", bins: [.init("<10ms", 48), .init("10-25", 112), .init("25-50", 86), .init("50-100", 37), .init("100-250", 14, hot: true), .init("250-500", 5, hot: true), .init(">500", 2, hot: true)],
                                   scaleMax: 120, ticks: [0, 30, 60, 90, 120], legend: "▲ 100ms 以上（遅い）", width: 28)
                }
                KodouBox("スパークライン（直近24時間）") {
                    VStack(spacing: 2) {
                        KodouSparkline("CPU", values: [3, 4, 6, 9, 12, 16, 22, 30, 41, 52, 61, 55, 44, 35, 28, 20, 14, 10, 8, 6, 5, 4, 12, 12], now: "12%", max: "61")
                        KodouSparkline("メモリ", values: [2, 3, 5, 6, 8, 9, 10, 11, 11, 12, 12, 12, 13, 13, 13, 13, 13, 13.2, 13.4, 13.5, 13.6, 13.6, 13.6, 13.6], now: "13.6G", max: "13.6")
                        KodouSparkline("エラー", values: [0, 1, 0, 0, 2, 0, 1, 0, 5, 9, 3, 1, 0, 0, 1, 0, 0, 2, 0, 0, 0, 1, 0, 0], now: "0件", max: "9")
                    }
                }
                KodouBox("点の多いグラフ（2万点）") { KodouLineChart(series, label: "CPU 使用率").frame(height: 90) }
            }
        }
    }

    // 重ね
    var overlays: some View {
        VStack(alignment: .leading, spacing: 18) {
            KodouBox("ツールチップ（見本のため出したままにしている）") {
                HStack(spacing: 72) {
                    KodouButton("コピー", icon: "copy") {}.kodouTooltip("クリップボードにコピー", key: "⌘C")
                    KodouButton("通知 3件", icon: "bell") {}.kodouTooltip("未読の通知を開く", key: "n")
                    KodouButton("設定", icon: "gear") {}.kodouTooltip("設定を開く", key: "⌘,")
                    Text("幅が足りないときだけ →").font(.kdMono(12)).foregroundStyle(KD.dim)
                    Button {} label: { KodouIcon("trash").foregroundStyle(KD.red).frame(width: 24, height: 24) }
                        .buttonStyle(KodouButtonStyle(.danger)).accessibilityLabel("ゴミ箱").kodouTooltip("ゴミ箱に入れる", key: "x")
                }.padding(.top, 28).environment(\.kodouShowTooltips, true)
            }
            KodouBox("ダイアログ") {
                KodouConfirm(title: "ブランチを削除しますか", message: "spike/agent-steer を削除します。リモートにまだ送っていないコミットが2件あり、削除すると戻せません。", confirm: "削除する", onConfirm: {}, onCancel: {})
                    .padding(.bottom, 8)
            }
            HStack(spacing: 12) {
                KodouButton("トーストを出す") { toasts.show("ログを 2,000 行消しました", undo: { s.status = "取り消しました" }) }
            }
        }
    }
}

// MARK: 起動

@main
enum GalleryMain {
    @MainActor static var keep: [AnyObject] = []

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        MainActor.assumeIsolated { setup() }
        app.run()
    }

    @MainActor static func setup() {
        let s = GalleryState(), toasts = KodouToasts(), files = Files(), commits = Commits(), ticker = KodouTicker()
        let table = KodouTableController(columns: [.init("name", "名前"), .init("size", "バイト", ch: 9, numeric: true), .init("days", "更新", ch: 8)], label: "ファイル")
        table.source = files
        let rows = KodouRowsController(columns: [.init(.ch(8)), .init(.ch(5)), .init(.fill), .init(.ch(6))], label: "コミット")
        rows.source = commits
        rows.allowsPicking = true
        let tree = KodouTreeController(roots: [
            KodouTreeNode("app", children: [
                KodouTreeNode("Sources", children: [KodouTreeNode("Rows.swift", mark: "M"), KodouTreeNode("Tree.swift", mark: "A"), KodouTreeNode("Log.swift")]),
                KodouTreeNode("Resources", children: [KodouTreeNode("Info.plist")]),
                KodouTreeNode("build.sh", mark: "M"),
            ]),
            KodouTreeNode("README.md"),
        ], label: "ファイルの木")
        tree.expandAll()
        let log = KodouLog<Line>(capacity: 2000, columns: [.init(.ch(9)), .init(.ch(5)), .init(.fill)], ticker: ticker) { l in
            [.init(l.t, KodouColor.faint), .init(l.lv, l.lv == "ERROR" ? KodouColor.red : l.lv == "WARN" ? KodouColor.yellow : KodouColor.cyan, bold: l.lv == "ERROR"), .init(l.m)]
        }
        let src = [("INFO", "GET /api/session 200 12ms"), ("INFO", "GET /api/usage 200 8ms"), ("WARN", "slow query: SELECT * FROM events 412ms"), ("ERROR", "job 7f3a: exit 1  TypeError")]
        for k in 0..<40 { let (lv, m) = src[k % 4]; log.append(Line(t: String(format: "00:06:%02d", k), lv: lv, m: m)) }
        var seed: UInt64 = 7, v: Float = 30
        let series = KodouSeries((0..<20000).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let r = Float(seed >> 40) / Float(1 << 24)
            v += (r - 0.5) * 6 + (40 - v) * 0.01; if r > 0.9985 { v += 40 }; v = min(99, max(1, v)); return v
        })
        let w = NSWindow(contentRect: NSRect(x: 200, y: 60, width: 1300, height: 940), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        w.title = "KodouUI の部品"
        w.contentView = NSHostingView(rootView: Gallery(s: s, toasts: toasts, table: table, tree: tree, rows: rows, log: log, series: series))
        w.makeKeyAndOrderFront(nil)
        keep = [s, toasts, files, commits, ticker, table, rows, tree, log, series, w]
        if let i = CommandLine.arguments.firstIndex(of: "--shot"), i + 1 < CommandLine.arguments.count {
            w.level = .floating   // ほかの窓の下に隠れると、隠れたら止まる部品が止まるため
            w.orderFrontRegardless()
            Shooter(w: w, s: s, dir: CommandLine.arguments[i + 1], table: table, toasts: toasts).run()
        } else {
            NSApp.activate()
        }
    }
}

// MARK: --shot

@MainActor
final class Shooter {
    let w: NSWindow, s: GalleryState, dir: String, table: KodouTableController, toasts: KodouToasts
    var steps: [(Double, () -> Void)] = []
    init(w: NSWindow, s: GalleryState, dir: String, table: KodouTableController, toasts: KodouToasts) { self.w = w; self.s = s; self.dir = dir; self.table = table; self.toasts = toasts }

    func png(_ name: String) {
        guard let v = w.contentView, let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
        v.cacheDisplay(in: v.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
    func key(_ chars: String, code: UInt16, shift: Bool = false) {
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let e = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: shift ? .shift : [], timestamp: 0, windowNumber: w.windowNumber, context: nil,
                                        characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code) { w.sendEvent(e) }
        }
    }
    func type(_ text: String) { (w.firstResponder as? NSTextView)?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0)) }
    func field(_ n: Int) -> NSTextField? { w.contentView?.descendants(NSTextField.self).filter { $0.isEditable }.dropFirst(n).first }
    func at(_ t: Double, _ f: @escaping () -> Void) { steps.append((t, f)) }

    func run() {
        var t = 1.0
        for theme in ["light", "dark"] {
            at(t) { [self] in w.appearance = NSAppearance(named: theme == "light" ? .aqua : .darkAqua) }; t += 0.3
            for p in 0..<Gallery.pages.count {
                at(t) { [self] in s.page = p }; t += 0.8
                at(t) { [self] in png("\(p + 1)-\(theme)") }; t += 0.2
            }
        }
        // 状態（明るい外観）
        at(t) { [self] in w.appearance = NSAppearance(named: .aqua); s.page = 0 }; t += 0.8
        at(t) { [self] in if let f = field(1) { w.makeFirstResponder(f); type("Bad Name") } }; t += 0.6   // 1 は数値の欄の前にあるブランチ名
        at(t) { [self] in png("s1-typing") ; w.makeFirstResponder(nil) }; t += 0.6
        at(t) { [self] in png("s2-left") }; t += 0.2
        at(t) { [self] in if let f = field(0) { w.makeFirstResponder(f); type("re") } }; t += 0.8          // コンボ
        at(t) { [self] in png("s3-combo") ; w.makeFirstResponder(nil) }; t += 0.5
        at(t) { [self] in s.page = 1 }; t += 0.6
        at(t) { [self] in table.table.sortDescriptors = [NSSortDescriptor(key: "size", ascending: false)]; table.select(0) }; t += 0.6
        at(t) { [self] in png("s4-sorted") }; t += 0.2
        at(t) { [self] in s.page = 3; toasts.show("ログを 2,000 行消しました", undo: {}) }; t += 0.8
        at(t) { [self] in png("s5-toast") }; t += 0.4
        at(t) { NSApp.terminate(nil) }
        for (d, f) in steps { DispatchQueue.main.asyncAfter(deadline: .now() + d) { MainActor.assumeIsolated { f() } } }
    }
}

extension NSView {
    func descendants<T: NSView>(_ t: T.Type) -> [T] {
        subviews.flatMap { v -> [T] in ((v as? T).map { [$0] } ?? []) + v.descendants(t) }
    }
}
