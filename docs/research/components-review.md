# 部品の見本は本当に見やすく軽いか

36 の部品の見本（`skills/kodou-ui-build/assets/components/`）を、実際にブラウザで開いて測り、文献と照らして見直した。見せ方の一般論は [retro-vs-modern.md](retro-vs-modern.md) で扱ったので、ここでは部品ごとの作りと、軽さ、目の疲れにくい配色を扱う。

結論は次の3つである。

- 見やすさの土台（文字で書く状態、反転の選択、4.5:1 以上の色、色に頼らない区別）は、測っても文献に照らしても成り立っている。崩れているのは、11〜11.5px の小さい文字、ツールチップとトーストの WCAG 上の扱い、高さ 22px の行、入力のチェックのタイミングの4点である。
- 「軽い」は、Kodou-ui 自身の CSS と JS については正しい。ただし初回の転送量の 8 割以上は日本語の Web フォントで、部品を1つ出すだけで 440〜830KB を読み込む。
- 目の疲れの主な原因は、まばたきの減少と、画面と周りの明るさの差で、配色では変えられない。今の配色に根拠と食い違う所はなく、「暗い地」「暖かい地」「青を避ける」で疲れにくくなるとも言えない。効く手当ては、利用者が明るさと文字の大きさを選べるようにすることである（4 章）。

確認の度合いは参考文献の各項目の末尾に書いた。「本文」は本文を読んだもの、「抄録」は要旨だけを読んだもの、「記事」は二次資料、「実測」は今回測ったもの。

## 1. 測り方

headless Chrome（Chrome for Testing 1255、puppeteer-core 25）で、部品の見本を1つずつキャッシュのない状態で開いた。窓は 1280×900、明るい地。1つの見本につき次を取った。

- 転送: リクエスト数、全体とフォントの転送量（圧縮後）
- 表示: 最初の描画（FCP）、レイアウトのずれ（CLS）
- 文字: 見本の中の文字の大きさごとの字数、行間
- 押す所: 24×24px に満たない、押せる要素
- 静かな時の負荷: 読み込み後 5 秒、何も触らずにいる間のレイアウト回数とタスク時間
- DOM: `main` の中の要素数

file:// で開き、フォントは Google Fonts から取った。回線の制限と CPU の減速はかけていないので、時間の数字は速い回線での値である。

## 2. 見やすさ

### 2.1 部品ごとの判定

| 部品                          | 判定   | 理由                                                                                                                                                        |
| --------------------------- | ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 状態の文字（`[FAIL]` など）、バッジ、通知の帯 | よい   | 色に頼らず文字で伝える。色は全部 4.9:1 以上                                                                                                                                 |
| リスト、表、ツリーの反転の選択             | よい   | 面全体の明暗が入れ替わり、選択の見え方の基準を満たしやすい                                                                                                                             |
| キーと値の点線                     | よい   | 点線は CSS の線で描いていて、スクリーンリーダーに「ドット」と読まれない[A7]                                                                                                                |
| 棒グラフ、ヒストグラム                 | よい   | 共通の基線からの長さで表す。ヒストグラムは 1 行 1 本の横棒なので、ブロック文字を縦に積んだ時の行間の隙間[A1]は起きない                                                                                          |
| スパークライン                     | よい   | 1 行の高さでは値の差を読み違えやすい[A2]。今の値と最大を数字で添える決まりがあり、これで補えている                                                                                                      |
| メーター                        | よい   | 円形ではなく直線の長さで表し[A3]、実際の値を数字で書く。区切った帯と連続した帯を比べた研究は見つからなかった                                                                                                  |
| 折れ線                         | 条件付き | 色に加えて線の種類と点の形、線の端の名前で分けるのは、色覚の違いに強い。ただし短い区間では破線の模様が見えないので、系列は少なく保つ[A5]                                                                                    |
| スライダー                       | 条件付き | 正確な値が要らない量に向く[A4]。正確さが要る値は数値の部品を使う、と決まりに書くとよい                                                                                                             |
| 表                           | 条件付き | 1 行おきの縞は成績を下げず、いくつかの問いで正確さを上げた[A6]。今の表には縞がない。行が多い表には薄い縞を選べるようにする                                                                                          |
| メニュー                        | 条件付き | 項目の横にキーを書くだけでは、キーはほとんど覚えられない[A11]。修飾キーを押している間だけ、画面上にキーを重ねて出す方法が効く                                                                                         |
| スピナー、進捗バー                   | よい   | 1 秒未満は出さず、10 秒を超えたら件数か割合を出す決まりが、NN/g の目安と同じ[A12]                                                                                                          |
| テキスト入力                      | 直す   | 打つたびに確かめている。Wroblewski（2009）では、欄を離れた後に確かめる方が、入力中に確かめるより 7〜10 秒速かった[A15]。形が決まっている欄は離れた後に、名前が空いているかのように打ちながら知りたいものだけ打つたびに確かめる                               |
| ツールチップ                      | 直す   | CSS の `:hover` だけで出していて、Esc で閉じられない。`pointer-events: none` なので、ツールチップの上にポインタを動かすと消える。WCAG 1.4.13 の「閉じられる」「ポインタを乗せても消えない」を満たさない[A9]。`aria-describedby` もない |
| トースト                        | 直す   | 5 秒で必ず消え、ポインタを乗せても、フォーカスがあっても止まらない。「元に戻す」が 5 秒で使えなくなるのは、WCAG 2.2.1 の制限時間に当たりうる[A8]。乗せている間とフォーカスの間は止め、取り消しをほかの場所（履歴など）からもできるようにする                          |
| 長いリスト                       | 直す   | 行の高さが 22px で、隣の行と接している。WCAG 2.5.8 は 24px に満たない押す所に間隔を求めるので、満たさない。24px にする。`aria-setsize` と `aria-posinset` もない[B4]                                        |
| 点の多いグラフ（canvas）             | 直す   | `<canvas>` に `aria-label` はあるが `role` がなく、支援技術から見えない[B6]。`role="img"` を付け、最小・最大・閾値を超えた回数を文で添える                                                            |

### 2.2 文字の大きさ

見本の中で一番多い大きさは 12〜13.5px で、11〜11.5px の文字が 21 の部品に出る。小さいのは、キーの表示（`Esc` `j/k`）、グラフの目盛りの数字、件数、状態の名前（「通常」「無効」）である。

窪田ほか（1999）では、液晶で好まれた文字の大きさは視角 32〜33 分だった[A13]。96dpi の画面を 50cm から見るとして換算すると約 18px になる（この換算は今回の推論）。画面で読める最小の文字は、印刷向けの JIS S 0032 で求めた大きさより有意に大きくする必要があった、という報告もある[A13]。11px の日本語は、この好まれる大きさを大きく下回る。

ただし、等幅の英数字を UI のラベルとして 11〜12px で使った時の研究は見つからなかった。キーの表示や目盛りは文として読むものではなく、ひと目で拾うものである。それでも 11px は下げすぎなので、次のようにする。

- 最小を 12px にする。11px と 11.5px は 12px に上げる
- 日本語の文字は 13px 以上にする
- 説明の文（`--font-read`）は 14〜15px を保つ

### 2.3 押す所の大きさ

24×24px に満たない押す所は、次のとおりだった。

- 長いリストの行（高さ 22px、隣と接する）: 2.5.8 を満たさない
- 小さいボタン `.btn.sm`（高さ 20px）: 通知の帯、ダイアログ、メーター、進捗バーで使う。上下に間隔があれば 2.5.8 の間隔の例外で通る。並べる時の間隔を決まりに書く
- パンくずの `~`（幅 12px）: 幅を 24px にする

チェックボックスとラジオの `input` は 1×1px だが、見えない本体で、押す所はラベル全体なので問題ない。

### 2.4 見た目の密度

Tuch ほか（2012）は、17ms しか見せなくても見た目の複雑さが印象を左右し、複雑さが低くよくある形に近いページが最も好まれたと報告した[A14]。Reinecke ほか（2013）では、色の多さより複雑さの方がずっと強く効いた[A14]。

詰めた TUI 風の画面は、初めて見る人には複雑に見えやすい。色の数を絞っても効果は小さく、効くのは要素の数と線の多さを減らすことである。見本の部品は、1つの見本の要素数が 11〜132 と小さい。見本帳（catalog/index.html）は全部の部品を1ページに並べるので 1,808 要素になり、Lighthouse の失敗の閾値（約 1,400）を超える[B4]。ただし見本帳は部品の節ごとに `content-visibility: auto` を付けていて、画面外の節は描かない。要素の数は多いが、描く量は画面に見えている節の分だけである。

## 3. 軽さ

### 3.1 部品ごとの数字

| 項目 | 値（36 部品の範囲） |
|---|---|
| リクエスト数 | 17〜44 件 |
| うちフォント | 9〜36 件 |
| 転送量 | 438〜827KB |
| うちフォント | 208〜595KB |
| Google Fonts の CSS | 149KB（展開後 581KB） |
| Kodou-ui の CSS と JS | 約 78KB（無圧縮）、br 圧縮で約 17KB |
| 最初の描画 | 316〜1,604ms |
| `main` の中の要素数 | 11〜132 |
| 静かな時のレイアウト | スピナー 50 回/5 秒、ログ 20 回/5 秒、ほかは 0 回 |
| 静かな時のタスク時間 | 8〜82ms/5 秒 |

### 3.2 重いもの: 日本語の Web フォント

転送量の 8 割以上はフォントである。Google Fonts は日本語のフォントを 1 ウェイトあたり 124 個に分けて配り、ページで使う文字を含むファイルだけを読み込む[B1]。それでも、BIZ UDGothic、Noto Sans JP、JetBrains Mono の 3 系統を読むので、部品を1つ出すだけで 9〜36 件、208〜595KB になる。見本帳では 105 件、約 1.5MB だった。

フォントの差し替えでレイアウトもずれる。色・文字の見本（tokens.html）は CLS 0.106 で、「良好」の 0.1 を超えた。

直し方は次の順に効く。

1. `--font-read` を `"Hiragino Sans", "Yu Gothic UI", system-ui, sans-serif, "Noto Sans JP"` の順にする。前のローカルのフォントで足りる環境では、Web フォントを読まない
2. BIZ UDGothic と Noto Sans JP の 2 系統を 1 系統にする
3. 説明の文のフォントは `font-display: optional` にする。100ms で間に合わなければ差し替えないので、ずれない[B1]

### 3.3 軽いもの

Kodou-ui 自身の CSS と JS は軽い。kodou.css は 37KB だが br 圧縮で 7.4KB で、Google Fonts の CSS（149KB）の 20 分の 1 である[B5]。ぼかしの付いた影、`filter`、`backdrop-filter` は使っていない[B7]。

動く部品も軽い。描画のループは 1 本にまとめてあり、ページが隠れると止まり、画面の外に出た部品は更新しない。`.box` の中は `contain: content` で、文字が変わってもレイアウトの計算が部品の中で済む[B2]。スピナーは 5 秒に 50 回レイアウトするが、タスク時間は 82ms（約 1.6%）だった。

点の多いグラフは、描く幅の 1 列に 1 点まで間引くので、点の数が画面の幅で頭打ちになる。1 万点を超える量に canvas を使うのは、一般的な勧めとも合う[B6]。

### 3.4 小さく直すもの

- 描画のループは、画面の中に動く部品が1つもなくても毎フレーム回り続ける（`kodou.js` の `loop()`）。静かな時のタスク時間は 5 秒で 8〜47ms と小さいが、何もしない rAF のループでも電力を使う[B3]。画面の中の部品が 0 になったら止め、IntersectionObserver で再開する
- ベンチの 57MB と 128MB は、file://、headless、20 秒のシナリオ1本での値である。メモリの値は Chrome の版や測り方で変わり、1 回の測定は当てにしにくい[B9]。bench/README.md に条件を書き添え、遅い回線と CPU の減速、長時間の放置のシナリオを足す

## 4. 目の疲れにくい色

配色で目の疲れが大きく変わるという証拠は弱い。疲れに効いているのは、まばたきの減少と、画面と周りの明るさの差である。今の配色には、根拠と食い違う所はなかった。

### 4.1 疲れの主な原因は色ではない

画面の作業では、まばたきが約 5 分の 1 に減る[C1]。Rosenfield（2011）は、画面を見る時のピント合わせと寄り目は紙とほぼ同じで、画面で多いのはドライアイだとまとめた[C1]。Benedetto ほか（2014）では、画面の輝度が 140 cd/m² の時は 20 cd/m² の時よりまばたきが減り、疲れが増えた[C2]。周りが明るいほど快適な画面の輝度は上がり、周りと画面の輝度の差が大きいほど疲れる、という結果もある[C2]。

まばたき、見る距離、画面の明るさは、配色では変えられない。配色にできるのは、読みやすさの下限を守ることと、まぶしい面を広げないことである。

### 4.2 今の配色の判定

| 見せ方        | 今の値                          | 判定     | 理由                                                                                                      |
| ---------- | ---------------------------- | ------ | ------------------------------------------------------------------------------------------------------- |
| 明るい地を標準にする | 地 #F4F4EF                    | よい     | 明るい地と暗い地で疲れに有意な差はなかった、という研究がある。暗い地で疲れが減ったのは明るい部屋だけ、という研究もあり、結果は割れている[C3]。暗い地を「目に優しい」とする根拠はない            |
| 純白を避けた地    | 相対輝度 0.90、文字との比 14.1:1       | 効果は小さい | 明るい部屋では、白より明るい灰色の地の方が快適だった[C4]。ただしその灰色（L\*≈75）は #F4F4EF よりずっと暗い。今の地は純白より約 1 割暗いだけで、疲れを減らす効果は小さいと見るべきである |
| 地の暖かい色味    | 黄みの灰色                        | 中立     | 色付きの透明板やレンズで読みが楽になるという主張は、系統的レビューで支持されなかった[C5]。暖かい色味は好みとしては残してよいが、疲れにくさの理由には使わない                        |
| 青を使うこと     | blue #0058A0 / #72B2FF       | 問題ない   | 画面の青い光が目を傷める根拠はなく、青い光を切る眼鏡も疲れを減らさない可能性が高い[C6]。夜の睡眠への配慮は OS の Night Shift などの役目で、UI の配色が受け持つことではない       |
| 暗い地の文字     | #D9DCE3、地との比 13.1:1          | よい     | 純白を避けているので、明るい文字のにじみ（ハレーション）を抑える。ただし疲れを直接比べた実験は見つからなかった                                                 |
| 暗い地の差し色    | 地との比 6.1〜10.3:1、明度を上げて淡くしている | よい     | 暗い面の上の鮮やかな色はちらついて見えやすいので、淡い色を使う、という指針[C7]に沿っている                                                         |
| 反転の選択      | 1 行だけ                        | よい     | 1 行の反転は問題ない。縞模様の不快感（pattern glare）は、同じ幅の明暗の帯が等間隔に並ぶと強くなる[C8]。表の縞は濃くせず、選択の反転を何行も続けて並べない                  |

### 4.3 気を付けること

- 暗い地で、red #FF9670 と blue #72B2FF の細い線や小さい文字を隣り合わせない。赤と青は前後に浮いて見えることがあり（色立体視）、見え方には個人差が大きい[C7]。並べる時は、間に文字色か dim を挟む
- 明るい地の red #BE3F0E は 4.9:1 で、基準の 4.5:1 に近い。これ以上薄くしない
- 表に縞を付ける時（2.1 の表）は、`--rule-soft` 程度の薄い差にとどめる[C8]
- 黒い文字と白い地は脈絡膜を薄くし、白い文字と黒い地は厚くした、という実験がある[C9]。著者は近視を抑えられるかもしれないと推測しているが、近視の進み方は測っていない。仮説の段階なので、配色を決める理由には使わない

### 4.4 疲れへの手当て

疲れへの手当ては、配色を1つに決めることより、利用者が明るさと文字の大きさを選べることにある。今の Kodou-ui の状態は次のとおり。

- `prefers-color-scheme` に従う: できている
- `prefers-contrast` に従う: 対応がない。`more` の時に dim と faint を文字色に近づけ、罫線を濃くする
- 文字の大きさ: すべて px で書いているので、ブラウザの拡大では大きくなるが、文字の大きさの設定には従わない。rem にすると両方に従う
- 暗い部屋向けの選択肢: 暗い地の画面全体の明るさは、今の値で十分低い。明るい地のまま地を少し暗くする「dim」の段を足すかは、使う場面を見て決める

## 5. 直す順

2026-11-26 に 1〜11 を直した。状態の欄に結果を書く。

| 順 | 直すこと | 種類 | 状態 |
|---|---|---|---|
| 1 | 説明の文のフォントをシステムのフォントから先に使い、Web フォントを 1 系統にまとめる | 軽さ | 済み。Noto Sans JP を読まなくなり、部品1つの転送量は平均 653KB → 270KB（範囲 192〜363KB）、フォントのリクエストは 3〜22 件になった。等幅のフォントの差し替えによる CLS（tokens.html で 0.12）は残る |
| 2 | ツールチップを Esc で閉じられ、上に乗せても消えないようにし、`aria-describedby` を付ける | 見やすさ | 済み |
| 3 | トーストを、乗せている間とフォーカスの間は止める | 見やすさ | 済み |
| 4 | 11〜11.5px の文字を 12px に上げる | 見やすさ | 済み。見本帳、紹介ページ、場面集、アイコンと書体の見本も上げ、`lint.py` の tiny-text を 12px 未満で引っかかるようにした |
| 5 | 長いリストの行を 24px にし、`aria-setsize` と `aria-posinset` を付ける | 見やすさ | 済み。リストとツリーにも位置と数を付け、表には `aria-rowcount` と `aria-rowindex` を付けた |
| 6 | 形が決まっている入力欄は、欄を離れた後に確かめる | 見やすさ | 済み。合っていることと直ったことは打つたびに出し、名前の重なりはすぐ出す |
| 7 | canvas に `role="img"` と文の要約を付ける | 見やすさ | 済み |
| 8 | 画面の中に動く部品がなければ描画のループを止める | 軽さ | 済み。画面外では rAF が 0 回/秒になった（前は 60 回/秒） |
| 9 | 見本帳に `content-visibility: auto` を付ける | 軽さ | 直す前から付いていた（2.4 を直した） |
| 10 | ベンチの条件を書き添え、シナリオを増やす | 軽さ | 済み。`run.mjs` に `--cpu` と `--soak` を足した |
| 11 | `prefers-contrast: more` に対応し、文字の大きさを rem にする | 目の疲れ | 済み。行の高さは px のままなので、文字の大きさの設定を 125% より大きくすると行が窮屈になる |

## 6. 参考文献

### 見やすさ

- [A1] ブロック文字と罫線の隙間: suckless st の開発記録（git.suckless.org/sites/commit/b64e3c5b…）、https://github.com/microsoft/terminal/issues/5897 、https://github.com/adobe-fonts/source-code-pro/issues/57 （記事）
- [A2] Heer, J., Kong, N., Agrawala, M. (2009). Sizing the Horizon. CHI 2009. https://hci.stanford.edu/courses/cs448b/w09/Heer-Horizon.pdf （本文）
- [A3] Few, S. Bullet Graph Design Specification. Perceptual Edge, 2013 改訂. https://www.telerik.com/docs/default-source/blogs-docs/bullet_graph_design_spec-pdf （記事）
- [A4] Harley, A. (2015). Slider Design. NN/g. https://www.nngroup.com/articles/gui-slider-controls/ ／ W3C ARIA APG Slider Pattern. https://www.w3.org/WAI/ARIA/apg/patterns/slider/ （本文）
- [A5] Huestegge, L., Philipp, A. M. (2011). Effects of spatial compatibility on integration processes in graph comprehension. Attention, Perception, & Psychophysics. doi:10.3758/s13414-011-0155-1 （抄録）
- [A6] Enders, J. (2008). Zebra Striping: Does it Really Help? ／ Zebra Striping: More Data for the Case. A List Apart. https://alistapart.com/article/zebrastripingdoesithelp/ 、https://alistapart.com/article/zebrastripingmoredataforthecase/ （本文）
- [A7] WebAIM のメーリングリストでのリーダー線の議論. https://webaim.org/discussion/mail_message?id=48115 （記事）
- [A8] W3C. WCAG 2.2, 2.2.1 Timing Adjustable ／ 4.1.3 Status Messages. https://www.w3.org/TR/WCAG22/ （本文）
- [A9] W3C. WCAG 2.2, 1.4.13 Content on Hover or Focus ／ Kendrick, A. (2019). Tooltip Guidelines. NN/g. https://www.nngroup.com/articles/tooltip-guidelines/ （本文）
- [A11] Grossman, T., Dragicevic, P., Balakrishnan, R. (2007). Strategies for Accelerating On-line Learning of Hotkeys. CHI 2007. https://www.dgp.toronto.edu/~ravin/papers/chi2007_learninghotkeys.pdf （本文）／ Malacria, S. et al. (2013). Promoting Hotkey Use through Rehearsal with ExposeHK. CHI 2013. https://hal.archives-ouvertes.fr/hal-01894253 （抄録）
- [A12] NN/g. Progress Indicators Make a Slow System Less Insufferable. https://www.nngroup.com/articles/progress-indicators/ （本文）
- [A13] 窪田悟ほか (1999). 映像情報メディア学会誌 53(10). doi:10.3169/itej.53.1335 （抄録）／ 科研費 15K00699 2017 年度実績報告. https://kaken.nii.ac.jp/en/report/KAKENHI-PROJECT-15K00699/15K006992017jisseki （抄録）
- [A14] Tuch, A. N. et al. (2012). The role of visual complexity and prototypicality regarding first impression of websites. https://research.google.com/pubs/archive/38315.pdf （抄録）／ Reinecke, K. et al. (2013). Predicting Users' First Impressions of Website Aesthetics. CHI 2013. https://kgajos.seas.harvard.edu/papers/reinecke13aesthetics.pdf （抄録）
- [A15] Wroblewski, L. (2009). Inline Validation in Web Forms. A List Apart. https://alistapart.com/article/inline-validation-in-web-forms/ （本文）

### 軽さ

- [B1] web.dev. Best practices for fonts. https://web.dev/articles/font-best-practices （本文）／ Google Developers Blog (2018). Google Fonts launches Japanese support. https://developers.googleblog.com/2018/09/google-fonts-launches-japanese-support.html （本文）／ Google Fonts の CSS の分割数と転送量（実測）
- [B2] web.dev. Avoid large, complex layouts and layout thrashing. https://web.dev/articles/avoid-large-complex-layouts-and-layout-thrashing ／ MDN. contain. https://developer.mozilla.org/en-US/docs/Web/CSS/contain （本文）
- [B3] Chrome for Developers. Heavy throttling of chained JS timers beginning in Chrome 88. https://developer.chrome.com/blog/timer-throttling-in-chrome-88 （本文）／ blink-dev の rAF の間引きの議論. https://groups.google.com/a/chromium.org/g/blink-dev/c/xodJxrzjv30 （本文）
- [B4] Chrome for Developers. Avoid an excessive DOM size. https://developer.chrome.com/docs/lighthouse/performance/dom-size ／ web.dev. Interaction to Next Paint. https://web.dev/articles/inp （本文）
- [B5] Chrome for Developers. Eliminate render-blocking resources. https://developer.chrome.com/docs/lighthouse/performance/render-blocking-resources （本文）／ kodou.css の圧縮後の大きさ（実測）
- [B6] MDN. `<canvas>`. https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/canvas （本文）／ Horak, T. et al. (2018). Comparing Rendering Performance of Common Web Technologies for Large Graphs. https://mt.inf.tu-dresden.de/cnt/uploads/Horak-2018-Graph-Performance-Poster.pdf （抄録）
- [B7] web.dev. Animations guide. https://web.dev/articles/animations-guide （本文）
- [B9] MDN. Performance.measureUserAgentSpecificMemory(). https://developer.mozilla.org/en-US/docs/Web/API/Performance/measureUserAgentSpecificMemory ／ web.dev. Monitor your web page's total memory usage. https://web.dev/articles/monitor-total-page-memory-usage （本文）

### 目の疲れ

- [C1] Patel, S. et al. (1991). Effect of visual display unit use on blink rate and tear stability. Optom Vis Sci 68:888. https://pubmed.ncbi.nlm.nih.gov/1766652/ （抄録）／ Rosenfield, M. (2011). Computer vision syndrome: a review of ocular causes and potential treatments. Ophthalmic Physiol Opt 31:502. https://pubmed.ncbi.nlm.nih.gov/21480937/ （抄録）／ AAO. Digital Devices and Your Eyes. https://aao.org/eye-health/tips-prevention/digital-devices-your-eyes （本文）
- [C2] Benedetto, S. et al. (2014). Effects of luminance and illuminance on visual fatigue and arousal during digital reading. https://lead.ube.fr/wp-content/uploads/2023/09/Benedetto_et_al._2014.pdf （抄録）／ Zhou, Y. et al. (2021). Applied Sciences. doi:10.3390/app11094108 （抄録）
- [C3] Sengsoon, P., Intaruk, R. (2025). IJERPH. doi:10.3390/ijerph22040609 （抄録）／ Xie, X. et al. (2021). IEEE Access. doi:10.1109/ACCESS.2021.3061770 （抄録）／ ACHI 2024. https://personales.upv.es/thinkmind/ACHI/ACHI_2024/achi_2024_3_150_20069.html （抄録）
- [C4] Huang, H. et al. (2021). Applied Sciences 11:8679. doi:10.3390/app11188679 （抄録）
- [C5] Griffiths, P. G. et al. (2016). The effect of coloured overlays and lenses on reading: a systematic review of the literature. Ophthalmic Physiol Opt 36:519. doi:10.1111/opo.12316 （抄録）
- [C6] Singh, S. et al. (2023). Blue-light filtering spectacles for computer vision syndrome. Cochrane Database Syst Rev. doi:10.1002/14651858.CD013244.pub2 （抄録）／ AAO. Should You Be Worried About Blue Light? https://aao.org/eye-health/tips-prevention/should-you-be-worried-about-blue-light （本文）／ Duraccio, K. M. et al. (2021). Sleep Health. doi:10.1016/j.sleh.2021.03.005 （抄録）
- [C7] Ozolinsh, M. et al. (2015). Frontiers in Psychology. doi:10.3389/fpsyg.2015.00337 （抄録）／ Material Design. Dark theme. https://m2.material.io/design/color/dark-theme （本文、実験の裏付けのない指針）
- [C8] Monger, L. J., Wilkins, A. J., Allen, P. M. (2015). Frontiers in Psychology. doi:10.3389/fpsyg.2015.01651 （抄録）
- [C9] Aleman, A. C., Wang, M., Schaeffel, F. (2018). Reading and Myopia: Contrast Polarity Matters. Scientific Reports. doi:10.1038/s41598-018-28904-x （抄録）
