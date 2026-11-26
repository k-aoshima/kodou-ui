# 変更の記録

版の番号は [Semantic Versioning](https://semver.org/lang/ja/) に従います。

## 0.4.0（2026-11-26）

macOS のネイティブアプリ（SwiftUI・AppKit）でも Kodou-ui を使えるようにした。

- Swift の部品 `KodouUI`（`swift/`）: 見本帳と同じ 36 の部品と、ドット絵のアイコン。一覧・ログ・表・ツリーと、セレクト・コンボボックスの候補は NSTableView・NSOutlineView で描き、ほかは SwiftUI で作る。タイマーは `KodouTicker` の 1 本にまとめ、窓が隠れている間は止まる。
- トークン（`Tokens.swift`）とアイコン（`IconData.swift`）は、`tools/build-assets.py` が見本帳から書き出す。部品のコードはスキルの `assets/swift/KodouUI/` にも写し、`--check` で見本帳とのずれを見張る。
- `kodou-ui-build` に `references/swift.md` を足した。SwiftUI と AppKit の分け方とその根拠、トークン、36 の部品の一覧、自分のプロジェクトへの入れ方を書いている。スキルの説明に SwiftUI・AppKit を足し、「SwiftUI で作って」でも読まれるようにした。
- `lint.py` に Swift の規則を 4 つ足した（`swift-hidden-timer`、`swift-bulk-rows`、`swift-tiny-text`、`swift-fixed-color`）。
- Swift のベンチ（`bench/swift/`）: 同じ画面を 5 通りで作って比べた。KodouUI はメモリ 34 MB・流している間の CPU 7.3% で、手当てをした SwiftUI は 112 MB・37.1%、同じ頁を WKWebView で出したものは 121 MB・19.7% だった。

## 0.3.0（2026-11-26）

部品見本を、読みやすさと WCAG の文献に照らして見直した。測り方と根拠は `docs/research/components-review.md` にある。

- 文の書体の既定を OS の和文ゴシック（ヒラギノ角ゴ、游ゴシック UI、メイリオ）にし、Noto Sans JP を読み込まないようにした。1 部品あたりの転送量は平均 653KB から 270KB になった。
- 文字の大きさを px から rem にし、12px 未満の文字をなくした。`lint.py` の `tiny-text` は 12px 未満で出る。
- `prefers-contrast: more` のとき、文字と罫線を濃くする（`tokens.css` にも入れた）。
- ツールチップは、マウスを載せても消えず、Esc で閉じられる。`aria-describedby` で元の部品とつないだ。
- トーストは、マウスやフォーカスが載っている間は消えるまでの時間を止める。
- 入力欄の誤りは、欄を離れてから出す。`aria-invalid` と `aria-describedby` を付けた。
- 長いリストの行を 24px にした。リストとツリーに `aria-setsize`・`aria-posinset`、表に `aria-rowcount`・`aria-rowindex` を付けた。
- canvas のグラフに、最小・最大・平均などの要約を `role="img"` の名前として付けた。
- `every()` は、画面外の部品のタイマーを止め、何も見えていないときは rAF を回さない。
- `bench/run.mjs` に、CPU を遅くする `--cpu` と長く流す `--soak` を足した。結果は `bench/README.md` にある。

## 0.2.0（2026-11-24）

- 部品の作りをスキルに入れた。見本帳から部品ごとに切り出した `assets/components/<名前>.html`（37 ファイル、開けばそのまま動く）と、共通の `kodou.css`・`kodou.js`、110 個のアイコンの `icons.js`。作るスキルは、部品を一から書かずにここから写す。
- `tools/build-assets.py`: 見本帳から上のファイルを書き出す。CI が `--check` で見本帳との食い違いを見張る。
- icons.md のアイコンの数を 110 個に直した。

## 0.1.0（2026-11-24）

最初の版です。

- スキル: 画面を作る `kodou-ui-build` と、点検する `kodou-ui-review`。
- 見本帳: 36 の基本部品、アイコン、部品を組んだ場面。
- トークン: 明るい地と暗い地（`assets/tokens.css`）と、同じ値を DESIGN.md の形で書いたもの（`assets/DESIGN.md`）。作るスキルは、プロジェクトの根の `DESIGN.md` を最初に読む。
- 点検のスクリプト:
  - `check.py`: コントラスト・アイコン・決まりの検出を 1 回で回し、終了コードで結果を返す。
  - `lint.py`: ファイルを読むだけで分かる決まりの違反を、10 の規則で探す。
  - `contrast.py`、`icon.py`、`measure.mjs`。
- 入れ方: Claude Code のプラグイン（`.claude-plugin/marketplace.json`）と、`npx skills add`。
- 紹介ページ（`site/`）と、React との省メモリの比較（`bench/`）。
- 見本帳の fonts・icons・scenes の頁の色を、今のトークンに揃えた。scenes の頁のタイマーは、頁が隠れている間は止まる。見本帳のグラフの棒には、フォーカスの枠を付けた。
- 場面の見本のコマンド入力から、特定のアプリ向けの絞り込みの文法（`#` の接頭辞とチップ）を外した。打つたびに絞り、開いたものを次から上に出す形にした。
- 文書・スキル・見本帳の「道具」を「ツール」に揃えた。
