# Swift（SwiftUI・AppKit）で作るとき

macOS のネイティブのツールを Kodou-ui で作るときの決まり。考え方・部品の振る舞い・文の書き方は Web と同じで、`components.md` と `patterns.md` に従う。ここには、Swift で何を使って作るかだけを書く。部品の作りは Kodou-ui のリポジトリの `swift/`（KodouUI、macOS 14 以上）にある。

## SwiftUI と AppKit の分け方

画面の組み立て・入力欄・ボタン・ダイアログ・トースト・グラフは SwiftUI で作る。次の 3 つだけは AppKit（NSTableView・NSOutlineView）を NSViewRepresentable で包んで使う。

- 件数の決まっていない一覧（セッション、コミット、ファイル、検索結果）
- 流れ続けるログ
- 表とツリー

根拠は同じ画面を作り方を変えて測った結果（`bench/swift/README.md`）。1 万行の一覧、50 行/秒のログ、2 万点のグラフを 60 秒流した。

| 作り方 | メモリ | 流している間の CPU | 50ms を超えたフレーム |
|---|---|---|---|
| KodouUI（一覧とログは NSTableView） | 34 MB | 7.3% | 0 |
| 一覧とログを SwiftUI の LazyVStack にしたもの | 81 MB | 30.0% | 0 |
| 手当てをした SwiftUI（List、間引いた Swift Charts） | 112 MB | 37.1% | 21 |
| よくある書き方の SwiftUI（List、全点の Swift Charts） | 206 MB | 100% | 429 |
| 同じ Kodou-ui の頁を WKWebView で出したもの | 121 MB | 19.7% | 0 |

- `LazyVStack` は、1 万行の中を選んで飛び回ったあとにメモリが 41 MB から 81 MB に増えた。
- よくある書き方の SwiftUI は、Swift Charts を外しても CPU が 1 コアを使い切ったままだった。窓が見えていないあいだ Timer を止めると 0% に下がったので、重さは Timer が配列を書き換えるたびの描き直しから来ている。
- Swift Charts に 2 万点を渡すと、ほかの手当てが入っていても CPU が 1 コアを使い切った。描く幅の 1 列に最小と最大の 2 点まで間引いてから渡す。
- 手当てをした SwiftUI でも、CPU は KodouUI の約 5 倍で、50ms を超えるフレームが残った。件数の多い一覧とログを SwiftUI だけで作らない理由はここにある。
- 中身が Web で既にあるときでも、WKWebView で出すと WebKit のプロセス（WebContent・GPU・Networking）の分だけ重い。ネイティブで作る意味はある。

## トークン

色・間隔・動きの長さは `swift/Sources/KodouUI/Tokens.swift` にある。見本帳の `:root` から `tools/build-assets.py` が書き出すので、手で直さない。

- SwiftUI では `KD.fg`、AppKit では `KodouColor.fg` と書く。どちらも明・暗・高いコントラスト（明と暗）で自動で替わる。`Color(red:green:blue:)` や `NSColor(srgbRed:...)` で色を直に書かない。
- 間隔は `KodouSpace.s1`〜`s6`（4〜32pt）、動きは `KodouMotion.fast`・`base`。
- 書体は `KodouFont.mono(13)`（桁をそろえる所。JetBrains Mono が無ければ SF Mono）と `KodouFont.read(14)`（文として読む所。システムの書体で、和文はヒラギノ角ゴ）。SwiftUI では `.font(.kdMono(13))`。データは 12pt 以上、文は 14pt 以上にする。

## 部品

見本帳の 36 部品と、それぞれの Swift の型。「作り」は、SwiftUI で作ったか、AppKit を包んだか。決まりは `components.md` と同じで、ここには要点だけを書く。

| 部品 | 型 | 作り | 決まりの要点 |
|---|---|---|---|
| ボタン | `KodouButton`、`KodouButtonStyle` | SwiftUI | 種類は通常・primary・danger・ghost・link、大きさは sm・md・lg。枠のあるボタンに角かっこを付けず、ホバーは自身の色を濃くする。押せる範囲は 24pt 以上 |
| テキスト入力 | `KodouTextField` | SwiftUI | 合っていることはすぐ、形の誤りは欄を離れてから出す（`.error(..., now: true)` はすぐ）。誤りは VoiceOver に読み上げる |
| テキストエリア | `KodouTextArea` | SwiftUI | 行番号を付け、行ごとの決まりを守れていない行は番号に ! を付けて色を変える。1 行目の字数を出す |
| 数値 | `KodouStepper` | SwiftUI | - ＋ のボタン、↑↓、⇧＋↑↓（最大・最小）、直接の入力。端で止まったら理由を出す |
| セレクト | `KodouSelect` | SwiftUI ＋ 候補は NSTableView | Space・↓ で開き、↑↓ で選び、⏎ で決め、Esc で閉じる。閉じたまま頭の文字で切り替わる。候補は見えている分だけ描く |
| コンボボックス | `KodouCombo` | SwiftUI ＋ 候補は NSTableView | 打った分だけ絞り、一致した文字を緑の太字の下線にする。何件中何件かを出し、候補の並びは変えない |
| チェック・ラジオ・スイッチ | `KodouCheckStyle`、`KodouRadioGroup`、`KodouSwitchStyle` | SwiftUI | 印は [x] [ ] [-]、(•) ( )、ON / OFF の文字。自動で何かをする設定は既定を切にし、横に何が起きるかを書く |
| スライダー | `KodouSlider` | SwiftUI（Canvas） | 溝は 8pt の四角を 4pt あけて並べ、つまみはドット絵。←→、PageUp/PageDown、Home/End。動かすと同時に値と何が変わるかを出す |
| タグ入力 | `KodouTagInput` | SwiftUI | ⏎ か「,」で確定し、空欄で ⌫ を押すと最後の 1 つを外す。重なりはその場で知らせる。× は 24pt |
| リスト | `KodouRows`（`allowsPicking = true`） | NSTableView | 選んだ行は反転。j / k で動き、Space で複数選ぶ（選んだ行は薄い青）。選んだ状態はデータの側に持つ |
| 長いリスト | `KodouRows` ＋ `KodouRowsController` | NSTableView | 何万行でも見えている行だけ描き、変わった行だけ `reload(rows:)`。行は部品を持たずに文字を直接描く |
| ツリー | `KodouTree` ＋ `KodouTreeController` | NSOutlineView | 罫線と ▸▾ でつながりを見せる。←→ で開閉、変更の印は文字（M・A・D）。VoiceOver に深さ・位置・開閉を伝える |
| キーと値 | `KodouKeyValue` | SwiftUI | 点線でつなぐ。値はぼかさず選べる。コピーのボタンは 24pt で、押したら VoiceOver に知らせる |
| 表 | `KodouTable` ＋ `KodouTableController` | NSTableView | 見出しは反転で、押すと並べ替える（▲▼ の文字でも出す）。数字の列は右寄せ。並べ替えは番号の並びを並べ直すだけ |
| ログの流れ | `KodouLog` | NSTableView | 上限つきのリングバッファ。描き直しは 50ms に 1 回にまとめ、上限で回ったら先頭を消して末尾に足す。上へ戻すと追いかけを止める |
| 棒グラフ | `KodouBarChart` | SwiftUI（Canvas） | ブロックを積んだ棒。上限を超えた分は斜線と「+n」。棒は Tab で移れ、触れるかフォーカスで値を出す |
| 折れ線 | `KodouLines` | Swift Charts | 点の少ない系列だけ。系列は色に加えて点の形と線の種類で分け、端に名前を書く。触れると縦の線と値 |
| 点の多いグラフ | `KodouLineChart` ＋ `KodouSeries` | SwiftUI（Canvas） | 描く幅の 1 列に 1 本。境目を超えた列は色を替える。VoiceOver には最小・最大・平均を読む |
| スパークライン | `KodouSparkline` | SwiftUI | ▁〜█ の文字。今の値と最大を必ず数字で添える |
| ヒストグラム | `KodouHistogram` | SwiftUI | 8 分の 1 の刻みで端数まで描き、件数を横に出す。遅い区間は色に加えて ▲ |
| メーター | `KodouMeter` | SwiftUI（Canvas） | LED の帯と実際の値。境目を超えたら色に加えて「注意」「危険」の文字 |
| 進捗バー | `KodouProgress` | SwiftUI（Canvas） | 割合に加えて件数・時間・今の対象。手順があれば今どこかを並べる |
| スピナー | `KodouSpinner` | SwiftUI | 1 秒未満は出さない（`delay`）。何をしているかと件数か経過時間を添える。窓が隠れたら止め、動きを減らす設定では回さない |
| バッジと状態 | `KodouBadge`、`KodouCount`、`KodouStatusDot`、`KodouBootLine` | SwiftUI | 塗りと枠。状態は色だけでなく記号（✓ ✗ ● ◐ ■ ○）や文字でも示す |
| 通知の帯 | `KodouAlert` | SwiftUI | [INFO] [ OK ] [WARN] [FAIL] の文字と色。何が起きたかとどう直すかを書き、生のログは折りたたんで残す |
| トースト | `KodouToasts` ＋ `KodouToastHost` | SwiftUI | ポインタやフォーカスが乗っている間は止め、両方離れたら残りから続ける。取り消しは u。読み逃すと困る知らせには使わない |
| 空の状態 | `KodouEmpty` | SwiftUI | なぜ空なのかと、最初の 1 件を作る方法を書く |
| タブ | `KodouTabs` | SwiftUI | 選んだタブは反転、件数を添える。←→ で移れ、使えないタブは取り消し線で飛ばす |
| パンくず | `KodouCrumbs` | SwiftUI | パスと同じ形。今の場所は太字で、ほかはリンク |
| ページ送り | `KodouPager` | SwiftUI | 今のページを反転し、全体の件数を出す。←→ で前後へ |
| メニュー | `KodouMenu` | SwiftUI | 項目の横にキーを書き、開いている間はそのキーでも選べる。壊す操作は区切って最後に置く |
| ツールチップ | `.kodouTooltip(_:key:)` | SwiftUI | ポインタが乗っている間とフォーカスがある間は消えず、ツールチップの上に乗っても消えない。Esc で閉じる |
| ダイアログ | `KodouConfirm`、`.kodouConfirm(...)` | SwiftUI のシート | 取り消せない操作だけ。二重罫線。既定はやめる側（⏎・Esc・n）、y で実行 |
| キーの表示 | `KodouKey` | SwiftUI | 1 つのキーは塗り、同時に押すキーは枠、続けて押すキーは → でつなぐ |
| 区切り線 | `KodouDivider` | SwiftUI | 実線は区切り、点線は同じまとまりの中、二重線は大きな区切り。文字も載せられる |
| パネル | `KodouBox`、`KodouStatusLine` | SwiftUI | 罫線の枠に、線の上の題。画面の下にステータスライン |

土台として、ドット絵のアイコン `KodouIcon`（`IconData.swift` は icons.js から書き出す）、タイマー 1 本の `KodouTicker`（`every(ms)`・`frame(key, after:)`、窓が隠れたら止まる）、行を描く部品が共有する文字の組み置き `KodouLineCache` がある。

重ねるもの（セレクト・コンボボックス・メニューの候補、ツールチップ）は、SwiftUI の overlay で部品の上に重ねている。親が `clipped()` や `ScrollView` で切ると候補も切れるので、そういう所では親の外に置く。

部品を並べて確かめる窓は、リポジトリの `swift/gallery.sh` で開く。

## 自分のプロジェクトへの入れ方

部品の作りは、このスキルの `assets/swift/KodouUI/` に入っている（Kodou-ui のリポジトリの `swift/Sources/KodouUI/` の写しで、`tools/build-assets.py` が書き出す）。macOS 14 以上が必要。フォルダごと自分のプロジェクトに写して、ビルドの対象に加える。

1. 写す

   ```sh
   cp -R <このスキルのフォルダ>/assets/swift/KodouUI ./Sources/KodouUI
   ```

2. ビルドの対象に加える。使っている作り方に合わせて 1 つ選ぶ。

   - SwiftPM: `Package.swift` にターゲットを足し、アプリのターゲットの依存に加える。

     ```swift
     .target(name: "KodouUI", path: "Sources/KodouUI"),
     .executableTarget(name: "MyTool", dependencies: ["KodouUI"]),
     ```

   - Xcode: `KodouUI` のフォルダをプロジェクトにドラッグし、アプリのターゲットに加える。同じモジュールに入れるなら `import KodouUI` は要らない。

   - swiftc（Xcode なし。Command Line Tools だけ）: 静的ライブラリにしてからリンクする。

     ```sh
     swiftc -parse-as-library -O -target arm64-apple-macosx14.0 -wmo -module-name KodouUI \
       -emit-module -emit-module-path build/KodouUI.swiftmodule -emit-library -static -o build/libKodouUI.a Sources/KodouUI/*.swift
     swiftc -parse-as-library -O -target arm64-apple-macosx14.0 -I build -L build -lKodouUI Sources/MyTool/*.swift -o build/MyTool
     ```

     Command Line Tools に古い modulemap が残っていてビルドが止まるときは、リポジトリの `swift/clt-overlay.yaml` を `-vfsoverlay` と `-Xcc -ivfsoverlay` で渡す（`swift/build.sh` と同じ）。

3. 使う

   ```swift
   import KodouUI

   KodouBox("sessions") { KodouRows(controller) }
       .background(KD.bg)
   ```

swiftc の手順は Command Line Tools だけの環境で、写したフォルダからビルドできることを確かめた。SwiftPM と Xcode の手順は、まだ試していない。

写したファイルは手で直さない。トークンや部品を変えるときは Kodou-ui の側で直し、写し直す。

## 作るときの決まり

- 動き続ける画面のタイマーは `KodouTicker` にまとめ、`ticker.watch(window)` で窓が隠れたら止める。`Timer.publish` や `repeats: true` の Timer を部品ごとに持たない。
- 何千件にもなるデータを `ForEach`・`List`・`Chart` にそのまま渡さない。
- 状態は `@Observable` を行や部品ごとに分け、変わった所だけが描き直されるようにする。
- 行の高さは 24pt 以上にする（WCAG 2.5.8）。ベンチは Web のベンチに合わせて 22pt にしている。
- Command Line Tools だけの環境（Xcode なし）では、SwiftUI のマクロ（`@State`、`@Entry`、`#Preview`）の実装が無く、ビルドが止まる。部品の中の状態は `@StateObject` か `@Observable` のモデルで持つ。ビルドは `swiftc`（`swift/build.sh`）で行う。

## 点検

`kodou-ui-review` の `lint.py` は `.swift` も読む。見るのは次の 4 つ。

- `swift-hidden-timer`: 繰り返す Timer を、窓が隠れても止めていない
- `swift-bulk-rows`: 1,000 件以上の決まった数の行を `ForEach`・`List`・`Chart` にそのまま渡している
- `swift-tiny-text`: 文字の大きさが 12pt 未満
- `swift-fixed-color`: 色を数値で直に書いている
