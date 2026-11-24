# 変更の記録

版の番号は [Semantic Versioning](https://semver.org/lang/ja/) に従います。

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
