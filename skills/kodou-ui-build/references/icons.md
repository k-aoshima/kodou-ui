# アイコン

Kodou-ui のアイコンは、`#`（塗る）と `.`（空ける）を並べたマス目のデータで描く。ブラウザはこのデータから、マスを行ごとにまとめた1本の SVG の path を作る。見本は `catalog/icons.html` と、見本帳 `catalog/index.html` の `PX`・`PX12`。

## 画像生成を使わない理由

画像生成の AI で描いたドット絵は、マスの大きさと位置がアイコンごとにずれ、線の太さもそろわない。デザインシステムのアイコンは、並べたときに同じ格子に乗っていることが大事なので、マス目のデータを直接書く。データなら1個あたり数十バイトで、差分も読める。

## 決まり

- **大きさ**: 標準は 12×12。行の中に文字と並べる小さい所だけ 8×8 を使う。
- **表示の大きさ**: 1マスを整数か 0.5 刻みの px で描く。標準は 12×12 を 1マス 1.5px（18px）、8×8 は 1マス 2px（16px）。Retina でない画面では 1.5px がわずかににじむので、くっきりさせたい所は 1マス 2px（12×12 で 24px）にする。
- **にじませない**: SVG に `shape-rendering: crispEdges` を付け、viewBox はマス数そのもの（`0 0 12 12`）にする。
- **線**: 線は1マスの太さで描く。面で見せたい所（歯車の歯、雷）だけ2マス以上にしてよい。
- **余白と中心**: 余白はアイコンの中に持たず、置く側の gap で取る。描く範囲は 12×12 いっぱいまで使ってよいが、左右と上下の空きの差は1マスまでにして中心をそろえる。
- **塗り（tone）**: 目立たせたい状態の表示では、線の内側を自動で塗る。外周から届かない空きマスを内側とみなし、`fill: var(--accent)` を薄く（opacity 0.3）塗る。赤い状態なら `--red` で塗る。描く手間は線だけの版と同じ。
- **文字ラベル**: アイコンには文字を添える。アイコンだけのボタンは幅がどうしても足りない所だけにし、名前をツールチップと `aria-label` で出す。
- **色**: 線は `currentColor`。アイコン自体に色を決め打ちしない。

## 使い分け

| 版 | 大きさ | 使う所 |
|---|---|---|
| 標準 | 12×12、18px | ボタン、リスト、ツリー、見出し、タブ |
| 小 | 8×8、16px | 文の行の中、キーと値のコピー、候補の一覧の頭 |
| 塗り | 12×12＋tone | ダイアログの注意、空の状態の絵、目立たせる状態 |

## 今あるアイコン

12×12（`PX12`、107個）: file（ファイル）、folder（フォルダ）、open（開いたフォルダ）、branch（ブランチ）、pr（プルリクエスト）、term（端末）、copy（コピー）、bell（通知）、gear（設定）、trash（削除）、alert（注意）、box（空の箱）、pkg（パッケージ）、search（検索）、check（完了）、error（エラー）、play（実行）、clock（時間）、bolt（速さ）

Mac アプリの SF Symbols を置き換えるために足した 91 個: ring、dot、checkc、info、excl、stopc、pausec、ellc、dashed、half、filterc、x、chevR、chevL、chevD、chevU、stop、pause、plus、minus、power、chip、bubble、bubblel、bubblex、bubbleq、dashring、moon、zoomin、zoomout、refresh、ccw、undo、viewfinder、sidebar、sidebarR、photo、gauge、ellipsis、eject、collapse、expand、tray、trayfull、pulse、align、layers、sparkle、shield、shieldx、scale、globe、target、location、person、pencil、palette、pad、window、split、stack、grid、list、link、phone、hourglass、code、chart、trend、cal、bellbadge、external、arrowR、arrowU、arrowL、updown、return、swap、square、building、book、cursor、keyboard、hand、hare、tortoise、lock、wave、eraser、text、send。SF Symbols を置き換えるときは、記号の名前からこの一覧の名前への対応表を持ち、".fill" の付く記号は同じ形で内側を塗る（tone）。

8×8（`PX`）: file、folder、open、branch、pr、term、copy、bell、gear、trash、alert、box、pkg、heart（ロゴと動いている印）、knob（スライダーのつまみ、6×12）

## 新しいアイコンの足し方

1. 12×12 のマス目を書く。既存のアイコンと並べたときの線の太さと密度をそろえる。
   ```js
   gear: ['.....##.....', '..##.##.##..', '..########..', /* …12行 */ ],
   ```
2. 8×8 の版が要るなら同じ名前で `PX` にも書く。8×8 では細部を省き、形の特徴だけを残す。
3. 点検する。
   ```sh
   # icon.py は kodou-ui-review スキルの scripts/ にある
   python3 <kodou-ui-review>/scripts/icon.py page.html                 # PX12 をすべて
   python3 <kodou-ui-review>/scripts/icon.py page.html --name gear --show   # 1個をマス目で表示
   python3 <kodou-ui-review>/scripts/icon.py my-icons.txt --out build/icons --tone   # SVG を書き出す
   ```
   大きさが合わないものは問題として、中心のずれと孤立したマス（斜めも含めて周りに `#` が無いマス）は注意として出る。
4. ほかのアイコンと並べて、18px と 24px で見る。`catalog/icons.html` の「部品の中に置く」で、ボタン・一覧・状態の表示に置いた見え方も確かめる。

2026-11-23 時点の点検では、copy・play・bolt の3個が左右の中心のずれ（空きの差が2マス）として注意に出る。
