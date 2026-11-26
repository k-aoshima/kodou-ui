# KodouUI（Swift）

Kodou-ui の部品を、macOS の SwiftUI と AppKit で使う版です。見本帳の 36 部品がそろっています。macOS 14 以上で動きます。

部品ごとの型・SwiftUI と AppKit のどちらで作ったか・決まりの要点・自分のプロジェクトへの入れ方は、スキルの `skills/kodou-ui-build/references/swift.md` にあります。スキルだけを入れた環境でも使えるよう、`tools/build-assets.py` がこのフォルダの中身を `skills/kodou-ui-build/assets/swift/KodouUI/` に写します。

## 入っているもの

| ファイル | 中身 |
|---|---|
| `Tokens.swift`、`IconData.swift` | 色・間隔・動きの長さと、ドット絵のアイコンのマス目。`tools/build-assets.py` が見本帳から書き出す。手で直さない |
| `Dynamic.swift`、`Fonts.swift`、`Shared.swift`、`Text.swift` | 外観で替わる色、書体、部品が共有する小さな道具（窓が見えているか、フォーカスの枠、文字の組み置き） |
| `Ticker.swift`、`RingBuffer.swift` | タイマーは 1 本の `KodouTicker`（窓が隠れたら止まる）と、上限つきのリングバッファ |
| `Rows.swift`、`Log.swift`、`Table.swift`、`Tree.swift` | NSTableView・NSOutlineView を包んだ、件数の多い部品（リスト、ログ、表、ツリー） |
| `Select.swift` | セレクト・コンボボックス（候補は NSTableView）・メニュー |
| `Button.swift`、`Check.swift`、`Input.swift`、`Entry.swift` | ボタン、チェック・ラジオ・スイッチ、テキスト入力、スライダー・数値・テキストエリア・タグ入力 |
| `Nav.swift`、`Tooltip.swift`、`Dialog.swift`、`Toast.swift` | タブ・パンくず・ページ送り、ツールチップ、確認、トースト |
| `Status.swift`、`Bars.swift`、`Lines.swift`、`LineChart.swift` | 通知の帯・バッジ・進捗・スピナー・メーター・空の状態、棒グラフ・ヒストグラム・スパークライン、折れ線、点の多いグラフ |
| `Bits.swift`、`Box.swift`、`StatusLine.swift`、`Icon.swift` | キーと値・キーの表示・区切り線、枠、ステータスライン、アイコン |

色は SwiftUI では `KD.fg`、AppKit では `KodouColor.fg` のように書きます。どちらも外観が変わると自動で替わります。

## 作り方

Xcode は要りません。Command Line Tools の `swiftc` で静的ライブラリにします。

```sh
swift/build.sh        # → swift/build/libKodouUI.a と KodouUI.swiftmodule
```

使う側は `-I swift/build -L swift/build -lKodouUI` を付けてビルドし、`import KodouUI` します。例は `bench/swift/build.sh` にあります。

`Package.swift` もありますが、Command Line Tools だけの環境では SwiftPM がマニフェストのリンクで失敗することがあります（`Undefined symbols ... PackageDescription.Package.__allocating_init`）。そのため `build.sh` を正にしています。Xcode が入っていれば `swift build` でも作れるはずですが、まだ確かめていません。

部品を並べて確かめる窓は `swift/gallery.sh` で作って開きます（`--shot <フォルダ>` を付けると、4 つの頁を明・暗の両方で、入力の誤り・コンボボックスの候補・並べ替え・トーストの状態と一緒に PNG に書き出して終わります）。

## 一覧に NSTableView を選んだ理由

SwiftUI の `LazyVStack` で作った版と同じ場面で比べると、NSTableView の方がメモリは 34 MB 対 81 MB、流している間の CPU は 7.3% 対 30.0% でした。数字と測り方は `bench/swift/README.md` にあります。

## トークンを変えるとき

見本帳の `:root`（アイコンは見本帳のアイコンの節）を直してから `python3 tools/build-assets.py` を回します。`--check` は Web の書き出しと一緒に、`Tokens.swift`・`IconData.swift` と、スキルの `assets/swift/KodouUI/` への写しのずれも見ます。部品の `.swift` を直したときも、同じコマンドで写し直します。
