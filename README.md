# Kodou-ui

エンジニアが毎日使う道具のための、UI と UX のデザインシステム。CLI の手触りを残したまま、見た目と分かりやすさを今のものにする。

> 状態: 作成中。部品は見本帳（`catalog/index.html`）にあり、スキルは最初の版があります。部品をパッケージとして切り出す作業はまだです。

## 考え方

旧車の車体と手触りを残し、中身を今の技術に載せ替える「レストモッド」という改造があります。Kodou-ui は同じことを道具の UI でします。

今のエンジニアの道具は2つに分かれています。CLI（git、grep、fzf、Vim）は打てば必ず応え、使うほどうまくなりますが、何ができるのか分かりにくく、状態も見えにくい道具です。GUI（IDE、Web のダッシュボード、AI のエージェント画面）は分かりやすい一方で、待たされ、中を隠し、AI が勝手に進めます。Kodou-ui は、CLI の手触りを持った今の道具を作るための部品と判断の基準をそろえます。

大事にするのは**操作するよろこび**と**機械との対話**です。詳しくは [docs/principles.md](docs/principles.md) にあります。

## 構成

| 層 | 中身 | 置き場所 |
|---|---|---|
| 原則 | 判断の基準になる4つの原則、昔のままにするものと今に替えるもの、文面の読みやすさ、速さと軽さ | `docs/principles.md` |
| 根拠 | 昔の見せ方と今の見せ方を比べた文献調査 | `docs/research/retro-vs-modern.md` |
| 見本帳 | 37 の基本部品を触って試せる頁と、トークン | `catalog/index.html` |
| アイコン見本 | マス目で描いたアイコンの3案の比較 | `catalog/icons.html` |
| 場面の見本 | fzf・htop・AI の作業など、部品を組んだ場面 | `catalog/scenes.html` |
| スキル（作る） | エージェントが画面を作るときの手順、部品・アイコン・パターンの決まり | `skills/kodou-ui-build/` |
| スキル（点検） | できた画面の点検手順とチェックリスト | `skills/kodou-ui-review/` |
| 道具 | コントラスト比の計算、アイコンの点検と SVG の書き出し | `scripts/contrast.py`、`scripts/icon.py` |
| UI の部品 | 見本帳から切り出す CSS と JS | `packages/`（未作成） |

部品だけでは、手応えも透明さもない画面を組めてしまいます。そのため Kodou-ui は、判断の部分をスキルとしてエージェントに渡し、UX まで一緒に届けます。

## スキルの入れ方（Claude Code）

Claude Code は、`SKILL.md` を含むフォルダを skills のフォルダに置くと、そのスキルを読み込みます。

- すべてのプロジェクトで使う: `~/.claude/skills/` に置きます
  ```sh
  cp -R skills/kodou-ui-build skills/kodou-ui-review ~/.claude/skills/
  ```
- 1つのプロジェクトだけで使う: そのプロジェクトの `.claude/skills/` に置きます

スキルの中の `catalog/`・`docs/`・`scripts/` の参照は、このリポジトリの根からの相対で書いています。点検のスクリプトを使うときは、このリポジトリを手元に置いてください。

## 道具

```sh
python3 scripts/contrast.py catalog/index.html     # 文字と地のコントラスト比（基準を割ると終了コード 1）
python3 scripts/icon.py catalog/index.html         # 12×12 のアイコンを点検
python3 scripts/icon.py catalog/index.html --out build/icons --tone   # SVG を書き出す
```

## 方針

- 文書とスキルは日本語を主にします。
- 部品は Web から作り、ライブラリに依存しません（CSS の変数と、素の JS）。

## ライセンス

MIT License です。[LICENSE](LICENSE) を見てください。
