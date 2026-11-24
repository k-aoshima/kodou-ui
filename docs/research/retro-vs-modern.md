# CLI/TUI の見せ方: 昔のままにするもの、今に替えるもの

CLI/TUI の見せ方を人の認知と使いやすさの研究に照らして3つに分けた。昔のままでよいもの、今に替えるもの、形は昔のまま残して中身を替える折衷のものである。根拠には、論文、W3C の WCAG 2.2 の解説、Nielsen Norman Group（以下 NN/g）の調査記事、Apple の公式資料を使った。

確認の度合いは参考文献の各項目の末尾に書いた。「本文」は本文を読んだもの、「抄録」は要旨だけを読んだもの、「記事」は解説記事を読んだもの。原典を確かめられなかった主張（Doherty threshold の 400ms、Tufte のデータインク比、ClearType の効果など）は根拠に使っていない。

## 1. 結論の表

判定の意味は次のとおり。

- 昔のまま: CLI/TUI の見せ方を変えない。研究から見ても問題がないか、むしろ有利なもの。
- 今に替える: 研究から見て不利なので、今の見せ方にする。昔の雰囲気は別の所で残す。
- 折衷: 形や記号は昔のまま残し、使う場所や中身を今のものにする。

| 見せ方 | 判定 | 理由 | 根拠 |
|---|---|---|---|
| `[  OK  ]` `[FAILED]` のように文字で状態を書く | 昔のまま | 色に頼らず文字で伝えるので、色覚の違いがあっても読める。今の UI が色だけで済ませがちな点を、CLI は最初から満たしている | [7][9] |
| 反転表示の選択 | 昔のまま | 面全体の明暗が入れ替わるので、選択・フォーカスの見え方の基準（3:1、2px の枠相当の面積）を満たしやすい | [11][12] |
| 情報を詰めた一覧、固定した配置 | 昔のまま | 配置が変わらないと位置を覚えられ、慣れた人ほど速くなる。行が長いほど速く読めるという結果もある | [4][20] |
| キー操作中心の操作 | 昔のまま | 覚えた後は最も速い。ただし覚えるまでの支えを足す（下の「キーの学び方」） | [17][18] |
| 1キーごとに即座に描き変える | 昔のまま | 0.1 秒以内なら、結果を見せるだけで足り、直接操作している感覚が保たれる | [24][25] |
| 進捗をバーと数（`[####----] 42%` `3/50`）で見せる | 昔のまま | 10 秒を超える処理には進捗率の表示が勧められている。実際の数を出すのは原則「中が見える」とも合う | [24][26][27] |
| ブロック文字の棒グラフ（共通の基線からの長さ） | 昔のまま | 共通の目盛りの上の位置・長さは、角度や面積より正確に読み取れる符号化である | [33] |
| 文の書体（等幅） | 今に替える | 普通の大きさでは、プロポーショナル体の方が最大読書速度がやや速い。和文では UD 書体が明朝・ゴシックより速く読めたという結果がある。等幅は桁をそろえる所に残す | [1][2] |
| 1行の長さ（端末の幅いっぱい） | 今に替える | WCAG は 1 行 80 字（CJK は 40 字）以内を求める。ただし速さだけなら長い行の方が速いという結果もあり、研究は分かれる。文は短く、表は幅いっぱいにする | [3][4] |
| 行間（端末の 1.0〜1.2 行） | 今に替える | WCAG は段落内の行間を 1.5 以上とする。文の行間は広げ、格子と表は詰めたままにする | [3] |
| ANSI の赤と緑で成否を分ける | 今に替える | 赤と緑の組み合わせは、赤緑の色覚の違い（中国系・日本人の男性で 4〜6.5%）があると見分けにくい。黒地の暗い赤は 1 型色覚では黒に近く見える | [7][8] |
| 色だけで状態を伝える | 今に替える | WCAG 1.4.1 の違反になる。記号か文字を必ず添える | [9] |
| 薄い灰色（dim）の補足文 | 今に替える | 読ませる文は 4.5:1 以上が必要。薄い色は飾りにだけ使う | [10] |
| 黒地を標準にする | 今に替える | 正常視力では、若い人にも高齢者にも明るい地に暗い字の方が成績がよい。暗い地は選べるようにする。白内障などでは暗い地の方が速い人もいる | [13][14][15] |
| コマンドを覚えて打つしかない入口 | 折衷 | 思い出す（recall）より見て選ぶ（recognition）方が易しい。打つ入口は残し、打てるものを一覧で見せる | [16][17] |
| 全部大文字 | 折衷 | ひと目で読む短い語なら大文字の方が速いという結果がある。文や長いラベルには使わない | [5][6] |
| クリックできる 1 文字のボタン（`[x]` など） | 折衷 | 見た目の `[x]` は残し、クリックできる範囲を 24×24 CSS px 以上にする | [21][22] |
| 画面の切り替え（瞬時に書き換え） | 折衷 | 位置や並びが変わる時に約 1 秒以内の短い動きを入れると変化を追いやすい。ただし効果が出ない場面も多く、動きを止める設定も要る | [29][30][31] |
| スピナー | 折衷 | 1 秒未満なら出さない。2〜10 秒は何をしているかの文と一緒に出す。10 秒を超えるなら進捗率に替える | [26] |
| アイコン（ドット絵） | 折衷 | 誰でも分かるアイコンは少ない。ドット絵は残し、文字ラベルを常に添える | [35] |
| エラーをエラーコードと英語の生ログで出す | 今に替える | 何が起きたか、どう直すかを人の言葉で書く。コードとログは補助として残す | [25][36] |
| `y/N` の確認 | 折衷 | 既定を安全側（N）にするのは今の指針とも合う。確認は慣れで読まれなくなるので、乱発せず、取り消せる操作は確認の代わりに取り消し（undo）にする | [25][37][38][39] |
| 懐かしい見た目そのもの | 折衷 | 見た目の好ましさは使いやすさの感じ方を上げるが、実際の使いやすさとは別物である。昔らしさは見た目で出し、読みやすさを下げない | [4][41][42] |

替える優先度が高いのは、文の書体、色だけで状態を伝えること、ANSI の赤と緑、薄い灰色の文、黒地の標準、行間と行の長さ、エラーの書き方、確認ダイアログの乱発の8つである。逆に、文字で書く状態表示、反転表示の選択、詰めた一覧と固定した配置、キー操作、即座の描き変え、数を出す進捗、ブロック文字の棒グラフは、昔のままで研究とも合う。

## 2. 観点ごとの整理

### 2.1 文字

#### 等幅とプロポーショナル

Mansfield ら（1996）は、Times（プロポーショナル）と Courier（等幅）で、正常視力 50 人とロービジョン 42 人の読みを測った[1]。正常視力の人の最大読書速度は Times の方が 5% 速く、ロービジョンの人は逆に Times の方が 10% 遅かった。文字が臨界文字サイズ（最大速度で読める最小の大きさ）より小さいと、Times の読書速度は Courier より最大 50% 遅くなった。結論は「普通の大きさの文では差は小さく、視力の限界に近い小ささでは書体の選び方で大きな差が出る」である。

和文では、中野ら（2010）が低視力シミュレータを使い、明朝、ゴシック、2種類の UD 書体の読書速度を比べた[2]。最大読書速度は一方の UD 書体が他の3書体より速く、ゴシックは明朝より速かった。ただし、同じ UD 書体でもメーカーによって結果が違った。BIZ UD を名指しで評価した査読論文は今回見つからなかった。

Kodou-ui では、原則のとおり文は UD のプロポーショナル体、コマンド・データ・表・格子は等幅にする。等幅を文に使わない理由は、速さの差よりも、文として読む所と桁をそろえる所の役割を分けることにある。文字を小さくする所（ステータスライン、表の補足）では、等幅の方が読みやすくなる可能性があるため、小さくする前に字の大きさ自体を見直す。

#### 行の長さと行間

WCAG 2.2 の 1.4.8（AAA）は、1行を 80 字（CJK は 40 字）以内、段落内の行間を 1.5 以上、段落の間を行間の 1.5 倍以上とする[3]。

一方で、Dyson（2004）の総説では、1行 25〜100 字を比べた実験で最も長い 100 字の行が最も短い行より速く読まれた[4]。ただし差の一部はスクロールの時間で説明でき、読み手が好むのは中くらいの長さだった。Dyson は、文字の組み方では主観の好みと実際の成績が一致しないことが多いとまとめている。

行の長さについて、研究は「速さなら長い行、好みと読み失いの少なさなら短い行」に分かれている。Kodou-ui では、説明・AI の発言・確認の問いのような文は 35〜40 字・行間 1.75〜1.85 にし、一覧・表・ログは端末らしく幅いっぱいに詰める。表は行を目で追う物ではなく、桁と列で拾う物だからである。

#### 全部大文字

Arditi と Cho（2007）は、小さい文字（視力の限界の 2 倍程度）では大文字だけの文の方が大文字小文字混じりより速く読め、文字を大きくすると差が消えたと報告した[5]。NN/g が紹介した Sawyer ら（2017）の実験では、ひと目で単語を判断する課題で、小文字は大文字より 26% 長くかかった[6]。ただし対象は単独の語で、NN/g は文や長い見出しには大文字を勧めていない。

`[  OK  ]` `ERROR` のような短い状態の語は大文字のままでよい。英語の説明文や長いボタン名は大文字にしない。

#### 描画

原則で、走査線・にじみ・ちらつきは使わず、描画はくっきりさせると決めている。ClearType などのサブピクセル描画の効果は、今回原典を確認できなかったため根拠に使っていない。Mansfield らの結果[1]が示すように、文字の見え方の差は小さい文字ほど効くため、CRT の劣化を再現するとちょうどその不利を自分で作ることになる。

### 2.2 色

#### ANSI の8色と色覚の違い

Birch（2012）の総説によると、先天の赤緑の色覚の違いは、欧州系の男性で約 8%、女性で約 0.4%、中国系と日本人の男性で 4〜6.5% である[8]。Okabe と Ito のカラーユニバーサルデザインは、赤と緑の組み合わせ、黒や暗い地の上の赤い文字（1 型色覚では暗い赤がほぼ黒に見える）、青と紫、緑と茶を避けるよう勧めている[7]。

ANSI の標準の配色では、成功を緑、失敗を赤で示し、地は黒であることが多い。これはちょうど避けるべき組み合わせである。Kodou-ui では、ANSI の8色という役割の枠（赤は失敗、黄は注意、緑は成功）は残し、色相は CUD の方へ寄せ（赤は朱色寄り、緑は青緑寄り）、成功と失敗の間に明度の差もつける。

#### 色だけで伝えない

WCAG 1.4.1（A）は、色を情報を伝える唯一の手段にしないことを求める[9]。CUD も色に形・線の種類・文字を組み合わせるよう勧めている[7]。

CLI の `[  OK  ]` `[FAILED]` `y/N` は、状態を文字で書いているので、色を外しても意味が残る。今の UI の「緑の丸だけ」「赤い枠だけ」より、CLI の書き方の方がこの点では優れている。Kodou-ui では、色を付ける物には必ず記号か文字を添えることを部品の決まりにする。

#### コントラスト

WCAG 1.4.3（AA）は、文字と地のコントラストを 4.5:1 以上（大きい文字は 3:1 以上）とする[10]。飾りだけの文字は対象外である。1.4.11（AA）は、部品とその状態（選択中、フォーカス中など）を見分けるための見た目に 3:1 以上を求める[11]。

端末の dim（薄い灰色）で補足を書く習慣は、読ませる文では 4.5:1 を割りやすい。原則のとおり、薄い色はかっこ・罫線のような飾りにだけ使う。

#### 反転表示

反転表示は選択した行の地と字の明暗を入れ替える。WCAG 2.4.13（AAA）は、フォーカスの表示を部品の外周 2px の枠と同じ面積以上で、表示の前後で 3:1 以上の差があるものとする[12]。行全体を反転すれば、面積もコントラストもこの基準を大きく上回る。反転表示は昔のままで今の基準を満たす数少ない見せ方である。

ただし、広い面を飽和した強い色（ANSI の純色の青や赤）で塗ると、上に載る文字のコントラストが足りなくなることがある。反転に使う色は地と字の組でも 4.5:1 を確かめる。

#### ライトとダーク

Piepenbrock ら（2013）は、18〜33 歳と 60〜85 歳の両方で、明るい地に暗い字（陽画）の方が視力検査と校正作業の成績がよいことを示した[13][14]。同じグループの別の研究では、陽画の有利さは文字が小さいほど大きく、参加者は読みやすさの違いを自覚していなかった[14]。Sethi と Ziat（2023）は、暗い地（陰画）では認知負荷が上がり、明るい部屋の高齢者と暗い部屋の若い人で探索時間が延びた一方、若い人は陰画を好んだと報告した[15]。

逆の結果もある。NN/g の整理では、白内障など目の濁りがある人は陰画の方が速く読めた（Legge ら 1985、7 人）[14]。ただしこの研究は CRT を使っており、陽画ではちらつきが強かった可能性がある。

研究は「正常視力では陽画が有利、目の濁りがある人には陰画が有利なことがある、好みは成績と一致しない」に分かれる。Kodou-ui はライトを標準にし、ダークは選べるようにする。端末の雰囲気は黒地でなく、格子・罫線・反転表示・等幅で出す。

### 2.3 操作

#### 思い出すことと見て選ぶこと

NN/g の Budiu（2024）は、記憶の手がかりが多い分、見て選ぶ（recognition）方が思い出す（recall）より易しいと説明し、`mv` の名前と引数の順を覚えなければならない UNIX のコマンドを recall の例に挙げている[16]。

Scarr ら（2011）は、マウスで見て選ぶ GUI は初心者に向くが「初心者のやり方」に人を閉じ込め、キー操作やコマンドラインは上限が高いが長い訓練が要ると整理した[17]。人が熟練者のやり方に移らない理由として、別のやり方があることを知らない、移る手間、今のやり方で足りてしまうこと（satisficing）、移った直後に一時的に遅くなること（performance dip）を挙げている。

Kodou-ui では、打つ入口（コマンドパレット）は残し、空のまま開いた時に打てるものを一覧で見せる。これは原則4にすでに書いてある。

#### キーの学び方

Grossman ら（2007）は、メニューからホットキーへの移行を速める方法を比べた[18]。メニューを選ぶたびにホットキーを音声で読み上げる方法と、メニューからの実行を止めてホットキーを使わせる方法は、ホットキーの使用を 100% 以上増やし、作業時間も縮めた。一方で、予備実験では、メニューのホットキー表示を目立たせる（光らせる）だけの方法は移行を助けなかった。

Malacria ら（2013）の ExposeHK は、修飾キーを押している間だけ各コマンドの上にショートカットを重ねて表示する方式である。後の IconHK の論文（2017）は、ExposeHK を「追加の操作なしにショートカットを見せられる」方式として評価している[19]。ExposeHK の原典は今回読めていないため、効果の数値は挙げない。

Scarr ら（2012）の CommandMaps は、多くのコマンドを階層にせず固定した配置で一度に見せる方式で、初心者ではメニューや Ribbon と差がなく、慣れた人では両方より有意に速かった[20]。

Kodou-ui では次のようにする。

- 配置と並びを固定する（原則4「同じ入力には同じ結果を同じ順で返す」と同じ）。
- 修飾キーや `?` を押している間だけ、使えるキーを画面の部品の上に重ねて見せる。
- マウスで実行した時に、同じ操作のキーをステータスラインに出す。目立たせるだけでは学習を助けないという結果[18]があるので、出すだけで済ませず、効果を見て直す。
- メニューからの実行を止める方法[18]は、原則3「ハンドルは人が握る」に反するので使わない。

#### クリックの的

Fitts の法則では、的までの時間は距離と的の幅で決まり、MacKenzie（1992）の式では MT = a + b log2(A/W + 1) である[22]。WCAG 2.5.8（AA）は、ポインタで押す的を 24×24 CSS px 以上（小さい的は周りに 24px の円が重ならない間隔があればよい）とし、2.5.5（AAA）は 44×44 CSS px とする[21]。Apple は 44pt × 44pt 以上を勧める[23]。

等幅の格子で `[x]` や `▸` を 1〜3 文字のボタンにすると、15px の文字では幅が 24px に届かないことがある。見た目の文字は格子のまま残し、`::before` や余白でクリックできる範囲を 24px 以上に広げる。行全体をクリックの的にできる一覧では、行の高さを 24px 以上にする。

### 2.4 反応と動き

#### 応答時間

NN/g の Nielsen は、0.1 秒以内なら瞬時に反応したと感じられて結果を見せるだけで足り、1 秒以内なら考えが途切れず、10 秒を超えると注意が他へ移るとまとめた[24]。CLI の指針（clig.dev）も、100ms 以内に何かを表示することを処理の速さそのものより重要だとしている[25]。

キーを押せば即座に描き変える CLI の振る舞いは、そのまま残す。原則1の 50ms（遅くても 100ms）はこの 0.1 秒より厳しい目標である。Doherty と Thadani の 400ms（Doherty threshold）はよく引かれるが、今回原典を確認できなかったため根拠にしない。

#### 進み具合の見せ方

NN/g の Sherwin（2014）は、1 秒を超える処理には進み具合を見せ、1 秒未満にスピナーを出すと気が散る、スピナーは 2〜10 秒ほどに使い何を読み込んでいるかの文を添える、10 秒を超えるなら進捗率と残り時間の目安を出す、と勧める[26]。件数で進む処理は「50 件中 3 件目」のように短くても進捗率を使ってよい。Myers（1985）の実験では、進捗表示がある方が有意に好まれ、86.1% が進捗表示を好んだ[27]。

Harrison ら（2007）は、終わりに向けて加速する進捗バーが同じ時間でも速く感じられ、終わり近くで止まるバーは遅く感じられることを示した[28]。ただし、実際の進み具合と違う動きを見せることになるので、原則2「中が見える」（数字はぼかさず実際の値を出す）とぶつかる。Kodou-ui では使わない。終わり近くで止まらないよう、最後の工程（書き込み、後片付け）も進捗に含めて数える。

CLI の `[####----] 42%` と `3/50` は、この研究とよく合う。そのまま残し、10 秒を超える処理には中断の手段（`Ctrl-C` の案内）を添える[24]。

#### 動き

Heer と Robertson（2007）は、統計グラフの切り替えに動きを入れると、要素の追跡と値の変化の読み取りの両方で静的な切り替えより有意に有利だったと報告した[29]。紹介されている先行研究では、回転より平行移動のような単純な動きで、約 1 秒の切り替えが最もよかった。

Tversky ら（2002）は、動きの方が優れて見える研究の多くは、静止画より多くの情報や操作を含んでいて公平な比較になっていないと指摘した[30]。動きは速すぎたり複雑すぎたりして正しく知覚されないことが多い一方で、向きを取り戻す（real time reorientation）ような場面では役に立ちうる、とまとめている。

WCAG 2.3.3（AAA）は、操作で始まる動きを止められるようにすることを求める[31]。前庭障害ではめまい・吐き気・頭痛が起きうるためである。2.2.2（A）は、自動で始まり 5 秒を超えて続く動き・点滅に、止める手段を求める[32]。点滅する文字カーソルが 2.2.2 の対象かは、解説にも書かれていない。

研究は「位置関係が変わる時は単純で短い動きが役に立つ、それ以外では効果がはっきりしない」に分かれる。Kodou-ui では、CLI らしい瞬時の書き換えを基本にし、並びが入れ替わる時、パネルが開閉する時のような位置関係が変わる時だけ、`transform` で 150〜300ms 程度の動きを入れる（この時間は Kodou-ui の目安で、研究の値ではない）。`prefers-reduced-motion` では動きを消す。カーソルの点滅は入力欄にフォーカスがある間だけにする。

### 2.5 情報の見せ方

#### 密度

Tufte のデータインク比（データを表さないインクを減らす）は、今回原典を読めていないため根拠にしない。逆の結果として、Bateman ら（2010）は、飾りを多く入れたグラフでも内容の読み取りの正確さは飾りのないグラフと変わらず、2〜3 週間後の記憶はよかったと報告した[34]。ただし著者自身、すべてのグラフをこの作りにするよう勧めてはいない。

道具の一覧では、記憶より、毎日同じ場所で速く拾えることが大事である。行が長い方が速く読めるという結果[4]と、慣れた人には固定した配置で一度に多く見せる方が速いという結果[20]は、詰めた一覧を残すことを支える。

#### ブロック文字のグラフ

Cleveland と McGill の実験を再現した Heer と Bostock（2010）では、精度の順位は元の研究と同じで、共通の目盛り上の位置が長さより有意に正確で、面積は角度より悪く、どちらも位置より大幅に悪かった[33]。同じ論文の別の実験では、グラフの高さが 40px だと誤差が有意に大きく、80px を超えて高くしても精度はほとんど上がらなかった。目盛り線の間隔は 8px 以上が勧められている。

`▁▂▃▄▅▆▇█` のブロック文字は 1 文字の高さを 8 段階に分けるだけなので、1 行のスパークラインは高さが 40px にも届かない。傾向（上がっているか、山がどこか）を見るには十分だが、値を比べる用途には向かない。Kodou-ui では次のようにする。

- 共通の基線から伸びる棒（横向きの `████▌` など）は、位置と長さの符号化なので残す。
- 1 行のスパークラインは傾向を見る物と割り切り、今の値・最大値を数字で横に出す。
- 円グラフや面積で量を見せる物は作らない。

#### アイコンと文字ラベル

NN/g の Harley（2014）は、誰でも分かるアイコンは家、印刷、検索（虫眼鏡）などわずかで、アイコンには常に見える文字ラベルを添えるべきだとしている[35]。ある調査では閲覧履歴を表す時計のアイコンは一度もクリックされなかった。

ドット絵のアイコンは、見た目の古さをそろえる役には立つが、意味を伝える役は文字ラベルが担う。原則（アイコンを添える、ドット絵で描く）は残し、アイコンだけのボタンは作らない。

### 2.6 エラーと確認

#### エラーメッセージ

NN/g の Neusesser と Sunwall（2023）は、エラーを目立たせる（色やアニメーションだけに頼らない）、原因の近くに出す、専門用語を避けて人の言葉で書く、何が問題でどう直すかを書く、入力を消さない、責める言い方をしない、エラーコードだけを出さない、を挙げる[36]。clig.dev も、想定できるエラーは捕まえて人向けに書き直し、直し方（例: 実行すべき `chmod`）を示し、大事な情報は出力の最後に置くよう勧める[25]。

CLI のエラーの欠点は、生のスタックトレースや `EACCES` だけを出すことにある。Kodou-ui のエラーは、1 行目に何が起きたかと直し方を UD 書体の文で書き、エラーコード・ログ・実行したコマンドは等幅で折りたたんで添える。コードとログを隠さないのは原則2のためである。

#### 確認ダイアログの慣れ

Anderson ら（2015）は fMRI で、警告を見た時の脳の視覚処理の反応が 2 回目にはもう大きく落ちることを示し、見た目が変わる警告の方が慣れに強かった[39]。Bravo-Lillo ら（2013）は、確認に必要な情報へ注意を向けさせ、危ない操作を一時的にできなくする工夫（attractor）で、情報を見て判断する人が対照群の 2〜3 倍になったと報告した[40]。Raskin（2007）は、人は何度も「OK」を押すうちに反射で押すようになるので、確認を出すくらいなら取り消し（undo）を用意せよと主張した[38]。

NN/g の Nielsen（2018）も、確認は取り返しのつかない重い操作だけにし、乱発すると無視されるようになる、Yes/No でなく「ファイルを削除」のように結果を書いたボタンにする、既定を Yes にしない、取り消せるなら取り消しを用意する、と勧める[37]。clig.dev は、重さで分けて、重い操作では消す物の名前を打たせ、スクリプト用に `--confirm=名前` を用意するよう勧める[25]。

`y/N` の既定を安全側にする書き方は、この指針と合うので残す。変えるのは使い方である。

- 取り消せる操作（一覧からの削除、設定の変更）は確認を出さず、実行して取り消しを数秒間出す。
- 確認を出す時は、`y/N` の前に対象と結果を具体的に書く（例: `3 件のブランチ feat/a, feat/b, fix/c を消す。取り消せない。 y/N`）。
- 取り返しのつかない重い操作だけ、名前を打たせる。
- 同じ確認を何度も出さない。慣れは 2 回目から始まる[39]。

### 2.7 懐かしさとレトロな見た目

Lasaleta ら（2014）の 6 つの実験では、懐かしい気持ちになった人はお金への欲求が下がり、商品により多く払おうとした[41]。ただしこの研究で懐かしさを起こしたのは過去の出来事を思い出させる課題で、レトロな見た目の画面ではない。道具の見た目にそのまま当てはめられるかは分からない。

Tractinsky ら（2000）は、ATM を模した画面で、見た目の美しさの感じ方と使いやすさの感じ方が使う前から強く相関し、使った後の評価にも見た目が影響した一方、実際の使いやすさは評価に影響しなかったと報告した[42]。Dyson（2004）も、文字の組み方の好みと実際の読みの成績は一致しないことが多いとしている[4]。

見た目の好ましさは使いやすさの「感じ方」を上げるが、実際の使いやすさを保証しない。レトロな見た目が好かれても、それで読みにくさや分かりにくさが帳消しになるわけではない。Kodou-ui は、昔らしさを格子・罫線・反転表示・CLI の言い回し・ドット絵で出し、文字の読みやすさ、色、的の大きさ、エラーの書き方は研究に合わせる。原則「形は古く、描画はくっきりさせる」はこの整理と合っている。

## 3. 参考文献

1. Mansfield, J. S., Legge, G. E., & Bane, M. C. (1996). Psychophysics of Reading XV: Font Effects in Normal and Low Vision. *Investigative Ophthalmology & Visual Science*, 37(8), 1492–1501. https://legge.dl8.umn.edu/sites/legge.psych.umn.edu/files/files/media/mansfield96_psychophysics_of_reading_xv-_font_effects_in_normal_and_low_vision.pdf （本文1頁目）
2. 中野泰志・山本亮・新井哲也 (2010). ユニバーサルデザインフォントの見やすさ（3）明朝体、ゴシック体、ユニバーサルデザイン書体のリーダビリティの比較. 発表資料. https://web.econ.keio.ac.jp/staff/nakanoy/research/largeprint/03_kaken/2012/fig/JPA2010.pdf （本文）
3. W3C (2023). Understanding Success Criterion 1.4.8: Visual Presentation. WCAG 2.2. https://www.w3.org/WAI/WCAG22/Understanding/visual-presentation.html （本文）
4. Dyson, M. C. (2004). How physical text layout affects reading from screen. *Behaviour & Information Technology*, 23(6), 377–393. https://centaur.reading.ac.uk/23344/ （本文）
5. Arditi, A., & Cho, J. (2007). Letter case and text legibility in normal and low vision. *Vision Research*, 47(19), 2499–2505. https://pmc.ncbi.nlm.nih.gov/articles/PMC2016788 （抄録）
6. Laubheimer, P. (2017). Glanceable Fonts. Nielsen Norman Group. https://www.nngroup.com/articles/glanceable-fonts/ （記事。Sawyer ら 2017 の紹介）
7. Okabe, M., & Ito, K. Color Universal Design (CUD): How to make figures and presentations that are friendly to Colorblind people. https://jfly.uni-koeln.de/color/ （本文）
8. Birch, J. (2012). Worldwide prevalence of red-green color deficiency. *Journal of the Optical Society of America A*, 29(3), 313–320. https://pubmed.ncbi.nlm.nih.gov/22472762/ （抄録）
9. W3C (2023). Understanding Success Criterion 1.4.1: Use of Color. https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html （本文）
10. W3C (2023). Understanding Success Criterion 1.4.3: Contrast (Minimum). https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html （本文）
11. W3C (2023). Understanding Success Criterion 1.4.11: Non-text Contrast. https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html （本文）
12. W3C (2023). Understanding Success Criterion 2.4.13: Focus Appearance. https://www.w3.org/WAI/WCAG22/Understanding/focus-appearance.html （本文）
13. Piepenbrock, C., Mayr, S., Mund, I., & Buchner, A. (2013). Positive display polarity is advantageous for both younger and older adults. *Ergonomics*, 56(7), 1116–1124. https://doi.org/10.1080/00140139.2013.790485 （抄録）
14. Budiu, R. (2020). Dark Mode vs. Light Mode: Which Is Better? Nielsen Norman Group. https://www.nngroup.com/articles/dark-mode/ （記事。Piepenbrock ら 2013・2014、Dobres ら 2017、Legge ら 1985 の紹介）
15. Sethi, T., & Ziat, M. (2023). Dark mode vogue: Do light-on-dark displays have measurable benefits to users? *Ergonomics*, 66(12), 1814–1828. https://pubmed.ncbi.nlm.nih.gov/36533999/ （抄録）
16. Budiu, R. (2024). Memory Recognition and Recall in User Interfaces. Nielsen Norman Group. https://www.nngroup.com/articles/recognition-and-recall/ （記事）
17. Scarr, J., Cockburn, A., Gutwin, C., & Quinn, P. (2011). Dips and Ceilings: Understanding and Supporting Transitions to Expertise in User Interfaces. *CHI 2011*. https://csse.canterbury.ac.nz/andrew.cockburn/papers/blur.pdf （本文）
18. Grossman, T., Dragicevic, P., & Balakrishnan, R. (2007). Strategies for Accelerating On-line Learning of Hotkeys. *CHI 2007*, 1591–1600. https://www.dgp.toronto.edu/~ravin/papers/chi2007_learninghotkeys.pdf （本文）
19. Giannisakis, E., Bailly, G., Malacria, S., & Chevalier, F. (2017). IconHK: Using Toolbar Button Icons to Communicate Keyboard Shortcuts. *CHI 2017*. https://hal.inria.fr/hal-01444365 （本文。ExposeHK（Malacria ら 2013）の記述はこの論文から）
20. Scarr, J., Cockburn, A., Gutwin, C., & Bunt, A. (2012). Improving Command Selection with CommandMaps. *CHI 2012*, 257–266. https://hci.cs.umanitoba.ca/publications/details/improving-command-selection-with-commandmaps （抄録）
21. W3C (2023). Understanding Success Criterion 2.5.8: Target Size (Minimum). https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html （本文）
22. MacKenzie, I. S. (1992). Fitts' law as a research and design tool in human-computer interaction. *Human-Computer Interaction*, 7, 91–139. https://www.yorku.ca/mack/hci1992.html （本文）
23. Apple. UI Design Dos and Don'ts. https://developer.apple.com/design/tips （本文）
24. Nielsen, J. (1993, 2014 更新). Response Times: The 3 Important Limits. Nielsen Norman Group. https://www.nngroup.com/articles/response-times-3-important-limits/ （記事）
25. Prasad, A., Firshman, B., Tashian, C., & Parish, E. Command Line Interface Guidelines. https://clig.dev/ （本文）
26. Sherwin, K. (2014). Progress Indicators Make a Slow System Less Insufferable. Nielsen Norman Group. https://www.nngroup.com/articles/progress-indicators/ （記事）
27. Myers, B. A. (1985). The Importance of Percent-Done Progress Indicators for Computer-Human Interfaces. *CHI '85*. https://www.cs.cmu.edu/~bam/papers/percentdoneCHI85.pdf （本文）
28. Harrison, C., Amento, B., Kuznetsov, S., & Bell, R. (2007). Rethinking the Progress Bar. *UIST 2007*, 115–118. https://chrisharrison.net/projects/progressbars/ProgBarHarrison.pdf （本文）
29. Heer, J., & Robertson, G. G. (2007). Animated Transitions in Statistical Data Graphics. *IEEE Transactions on Visualization and Computer Graphics (InfoVis 2007)*. https://idl.cs.washington.edu/files/2007-AnimatedTransitions-InfoVis.pdf （本文）
30. Tversky, B., Morrison, J. B., & Betrancourt, M. (2002). Animation: can it facilitate? *International Journal of Human-Computer Studies*, 57, 247–262. https://hci.stanford.edu/courses/cs448b/papers/Tversky_AnimationFacilitate_IJHCS02.pdf （抄録）
31. W3C (2023). Understanding Success Criterion 2.3.3: Animation from Interactions. https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html （本文）
32. W3C (2023). Understanding Success Criterion 2.2.2: Pause, Stop, Hide. https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html （本文）
33. Heer, J., & Bostock, M. (2010). Crowdsourcing Graphical Perception: Using Mechanical Turk to Assess Visualization Design. *CHI 2010*. https://idl.cs.washington.edu/files/2010-MTurk-CHI.pdf （本文。Cleveland & McGill 1984 の再現）
34. Bateman, S., Mandryk, R. L., Gutwin, C., Genest, A., McDine, D., & Brooks, C. (2010). Useful Junk? The Effects of Visual Embellishment on Comprehension and Memorability of Charts. *CHI 2010*, 2573–2582. https://vis.csail.mit.edu/classes/6.859/readings/pdfs/Bateman-UsefulJunk.pdf （抄録）
35. Harley, A. (2014). Icon Usability. Nielsen Norman Group. https://www.nngroup.com/articles/icon-usability/ （記事）
36. Neusesser, T., & Sunwall, E. (2023). Error-Message Guidelines. Nielsen Norman Group. https://www.nngroup.com/articles/error-message-guidelines/ （記事）
37. Nielsen, J. (2018). Confirmation Dialogs Can Prevent User Errors (If Not Overused). Nielsen Norman Group. https://www.nngroup.com/articles/confirmation-dialog/ （記事）
38. Raskin, A. (2007). Never Use a Warning When You Mean Undo. *A List Apart*. https://alistapart.com/article/neveruseawarning/ （本文）
39. Anderson, B. B., Kirwan, C. B., Jenkins, J. L., Eargle, D., Howard, S., & Vance, A. (2015). How Polymorphic Warnings Reduce Habituation in the Brain: Insights from an fMRI Study. *CHI 2015*, 2883–2892. https://scholarsarchive.byu.edu/facpub/9306 （抄録）
40. Bravo-Lillo, C., Cranor, L., Komanduri, S., Downs, J., Reeder, R., Schechter, S., & Sleeper, M. (2013). Your Attention Please: Designing security-decision UIs to make genuine risks harder to ignore. *SOUPS 2013*. https://www.microsoft.com/en-us/research/?p=164816 （抄録）
41. Lasaleta, J. D., Sedikides, C., & Vohs, K. D. (2014). Nostalgia Weakens the Desire for Money. *Journal of Consumer Research*, 41(3), 713–729. https://www.southampton.ac.uk/~crsi/Lasaleta,%20Sedikides,%20and%20Vohs%202014.pdf （抄録）
42. Tractinsky, N., Katz, A. S., & Ikar, D. (2000). What is beautiful is usable. *Interacting with Computers*, 13(2), 127–145. https://academic.oup.com/iwc/article-abstract/13/2/127/898608 （抄録）
