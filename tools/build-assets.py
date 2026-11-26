#!/usr/bin/env python3
"""見本帳（catalog/index.html）から、スキルが使う部品の作りを切り出す。

見本帳を正本にし、エージェントが読める大きさのファイルに分けて
skills/kodou-ui-build/assets/ に書き出す。

  kodou.css            部品の CSS（tokens.css の後に読む）
  kodou.js             共通の関数（$・esc・frame・every・place・sl・⌥ のキーの札）
  icons.js             ドット絵のアイコン（PX 8×8、PX12 12×12）と px()
  components/<名前>.html  部品ごとの見本。HTML と、その部品の JS だけを持つ。開けばそのまま動く
  components/README.md 部品の一覧
  swift/Sources/KodouUI/Tokens.swift  Swift 版のトークン（:root の明・暗・高いコントラストから）
  swift/Sources/KodouUI/IconData.swift  Swift 版のアイコンのマス目（icons.js と同じ）
  swift/KodouUI/*.swift  swift/Sources/KodouUI の写し（スキルだけを入れた環境でも Swift の部品を使えるように）

  python3 tools/build-assets.py           # 書き出す
  python3 tools/build-assets.py --check   # 書き出した物が見本帳と合っているか（CI 用。合わなければ終了コード 1）

見本帳に新しい CSS や JS の節を足したら、下の対応表にも足す。足していない節があると止まる。
"""
import argparse, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(ROOT, 'catalog', 'index.html')
OUT = os.path.join(ROOT, 'skills', 'kodou-ui-build', 'assets')
SWIFT_TOKENS = os.path.join(ROOT, 'swift', 'Sources', 'KodouUI', 'Tokens.swift')
SWIFT_ICONS = os.path.join(ROOT, 'swift', 'Sources', 'KodouUI', 'IconData.swift')
SWIFT_SRC = os.path.join(ROOT, 'swift', 'Sources', 'KodouUI')

# ---- CSS の節: 見出しの書き出し → 扱い
CSS_RULES = [
    ('配置:', 'base'),            # :root（tokens.css にある）を除いた土台
    ('tmux の帯', 'keyframes'),   # @keyframes だけ
    ('目次と本体', 'skip'),
    ('部品。画面外の節は描かない', 'panel'),  # .comp の描かない設定を除く
    ('根拠', 'skip'),
]

# ---- JS の節: 見出しの書き出し → 書き出す先
JS_RULES = [
    ('描き直しは1フレームに1回', 'kodou'),
    ('タイマーは1本', 'kodou'),
    ('見えている分だけ描く（Kodou-ui の virt', 'virt'),
    ('LED の帯（Kodou-ui の ledBar', 'ledbar'),
    ('ドット絵のアイコン: 8×8', 'icons'),
    ('アイコン: 標準は 12×12', 'icons'),
    ('ステータスライン: キー、目次', 'skip'),   # 見本帳だけの目次と計測
    ('重ねるもの（popover）を基準', 'kodou'),
    ('⌥ を押している間だけ', 'kodou'),
    ('重ねるものは描かない節', 'skip'),
    ('ボタン: 処理中', ['button']),
    ('テキスト入力', ['input']),
    ('テキストエリア', ['textarea']),
    ('数値', ['number']),
    ('セレクト', ['select']),
    ('コンボボックス', ['combo']),
    ('チェック・ラジオ・スイッチ', ['check']),
    ('スライダー', ['slider']),
    ('溝:', ['slider']),
    ('タグ入力', ['tags']),
    ('リスト:', ['list']),
    ('長いリスト', ['vlist']),
    ('ツリー', ['tree']),
    ('キーと値', ['kv']),
    ('表:', ['table']),
    ('ログ:', ['log']),
    ('グラフの共通', ['chart', 'line', 'canvas', 'spark', 'hist']),
    ('棒グラフ', ['chart']),
    ('折れ線', ['line']),
    ('点の多いグラフ', ['canvas']),
    ('スパークライン', ['spark']),
    ('ヒストグラム', ['hist']),
    ('メーター', ['gauge']),
    ('進捗', ['progress']),
    ('スピナー', ['spinner']),
    ('1秒の決まり', ['spinner']),
    ('通知の帯', ['alert']),
    ('トースト', ['toast']),
    ('タブ', ['tabs']),
    ('パンくず', ['crumbs']),
    ('ページ送り', ['pager']),
    ('メニュー', ['menu']),
    ('ダイアログ', ['dialog']),
    ('ツールチップ', ['tooltip']),
    ('トークン', ['tokens']),
]
SKIP_SECTIONS = {'perf', 'refs'}   # 見本帳が自分を測る節と、文献の節
# 部品の節の中にあるが、ほかの部品も使う定義。kodou.js に移す
HOIST = ('const SP = ', 'const SPK = ', 'const spark = ')

KODOU_HEAD = """/* Kodou-ui の共通の関数。tools/build-assets.py が見本帳から書き出す（手で直さない）。
   読む順: tokens.css → kodou.css →（body の最後で）virt.js・ledbar.js・kodou.js・icons.js → 部品の JS
   - $ / $$ / esc / css: 要素を取る、HTML に入れる文字を逃がす、CSS 変数を読む
   - frame(key, fn): 描き直しを 1 フレームに 1 回へまとめる
   - every(el, ms, fn): タイマーは 1 本。頁が隠れている間と el（要素か要素の配列）が画面外の間は止まる。
     動かす部品が画面に1つもなければ、フレームも取らない
   - place(pop, anchor): 重ねるもの（popover）を基準の要素の下に置く
   - sl.msg(text): ステータスライン（#slMsg）に一言出す。無ければ何もしない
   - ⌥ を押している間、[data-key] を持つ要素の上にキーの札を出す
*/
"""

def blocks(text, start_pat):
    """`/* 見出し` で始まる行ごとに区切る。最初の見出しの前は ('', 前置き)。"""
    out, cur, head = [], [], ''
    for ln in text.split('\n'):
        if re.match(start_pat, ln):
            out.append((head, '\n'.join(cur))); cur = []; head = ln[3:]
        cur.append(ln)
    out.append((head, '\n'.join(cur)))
    return out

def rule_for(head, rules):
    for k, v in rules:
        if head.startswith(k):
            return v
    return None

# ---- Swift のトークン
def swift_tokens(style):
    """見本帳の :root（明・暗・高いコントラストの明と暗）から Tokens.swift を作る。"""
    pick = {
        'light': r'^:root \{\n(.*?)\n\}',
        'dark': r'^@media \(prefers-color-scheme: dark\) \{ :root:not\(\[data-theme="light"\]\) \{\n(.*?) \} \}',
        'hcLight': r'^@media \(prefers-contrast: more\) \{ :root \{[^\n]*\n(.*?) \} \}',
        'hcDark': r'^@media \(prefers-contrast: more\) and \(prefers-color-scheme: dark\) \{ :root:not\(\[data-theme="light"\]\) \{\n(.*?) \} \}',
    }
    sets = {}
    for k, pat in pick.items():
        m = re.search(pat, style, re.S | re.M)
        if not m:
            raise SystemExit(f'Swift のトークン: 見本帳の :root（{k}）が見つかりません')
        body = re.sub(r'/\*.*?\*/', '', m.group(1), flags=re.S)
        sets[k] = dict(re.findall(r'--([\w-]+):\s*([^;]+?)\s*(?:;|$)', body, re.M))
    def rgba(v, env):
        v = v.strip()
        m = re.fullmatch(r'var\(--([\w-]+)\)', v)
        if m:
            return rgba(env[m.group(1)], env)
        m = re.fullmatch(r'#([0-9A-Fa-f]{6})', v)
        if m:
            return (int(m.group(1), 16), 1.0)
        m = re.fullmatch(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)', v)
        if m:
            r, g, b, a = m.groups()
            return ((int(r) << 16) | (int(g) << 8) | int(b), float(a))
        return None
    camel = lambda n: re.sub(r'-(\w)', lambda m: m.group(1).upper(), n)
    lit = lambda c: f'.init(0x{c[0]:06X})' if c[1] == 1.0 else f'.init(0x{c[0]:06X}, {c[1]:g})'
    light, dark = sets['light'], {**sets['light'], **sets['dark']}
    hcl, hcd = {**light, **sets['hcLight']}, {**dark, **sets['hcDark']}
    colors, spaces, motions = [], [], []
    for name, v in light.items():
        c = rgba(v, light)
        if c:
            d = rgba(dark[name], dark)
            args = [lit(c), lit(d)]
            if name in sets['hcLight']:
                args.append('hcLight: ' + lit(rgba(hcl[name], hcl)))
            if name in sets['hcDark']:
                args.append('hcDark: ' + lit(rgba(hcd[name], hcd)))
            colors.append((camel(name), ', '.join(args)))
        elif re.fullmatch(r's\d', name):
            spaces.append((name, v.replace('px', '')))
        elif name.startswith('t-'):
            motions.append((camel(name[2:]), int(v.replace('ms', '')) / 1000))
    out = ['// Kodou-ui のトークン。tools/build-assets.py が catalog/index.html の :root から書き出す（手で直さない）',
           '// 明・暗・高いコントラスト（明と暗）の値を持つ動的な色で、外観が変わると自動で替わる',
           'import AppKit', 'import SwiftUI', '',
           '/// AppKit で使う色（NSColor）', 'public enum KodouColor {']
    out += [f'    public static let {n} = KodouDynamic.color({a})' for n, a in colors]
    out += ['}', '', '/// SwiftUI で使う色（KD.fg のように書く）', 'public enum KD {']
    out += [f'    public static let {n} = Color(nsColor: KodouColor.{n})' for n, _ in colors]
    out += ['}', '', '/// 間隔（pt）。Web の px と同じ数', 'public enum KodouSpace {']
    out += [f'    public static let {n}: CGFloat = {v}' for n, v in spaces]
    out += ['}', '', '/// 動きの長さ（秒）', 'public enum KodouMotion {']
    out += [f'    public static let {n}: Double = {v:g}' for n, v in motions]
    out += ['}', '']
    return '\n'.join(out)

def swift_icons(js):
    """icons.js の PX（8×8）と PX12（12×12）のマス目を Swift の辞書にする。"""
    out = ['// Kodou-ui のドット絵のアイコンのマス目。tools/build-assets.py が icons.js から書き出す（手で直さない）',
           '// 描き方は Icon.swift。決まりは skills/kodou-ui-build/references/icons.md', '']
    for var, sw in (('PX', 'px8'), ('PX12', 'px12')):
        body = re.search(r'const ' + var + r' = \{\n(.*?)\n\};', js, re.S).group(1)
        out.append(f'let kodouIcon{sw.upper()[2:]}: [String: [String]] = [')
        for name, rows in re.findall(r'^\s*(\w+):\s*\[([^\]]*)\]', body, re.M):
            cells = re.findall(r'[\'"]([#.]+)[\'"]', rows)
            out.append(f'    "{name}": [' + ', '.join(f'"{c}"' for c in cells) + '],')
        out.append(']')
        out.append('')
    return '\n'.join(out)

def build():
    src = open(CAT, encoding='utf-8').read()
    style = re.search(r'<style>\n(.*?)\n</style>', src, re.S).group(1)
    script = re.search(r'<script>\n(.*?)\n</script>', src, re.S).group(1)
    files = {SWIFT_TOKENS: swift_tokens(style)}

    # ---- CSS
    css_out = ['/* Kodou-ui の部品の CSS。tools/build-assets.py が見本帳から書き出す（手で直さない）。tokens.css の後に読む */']
    for head, body in blocks(style, r'^/\* '):
        if not head:
            continue
        r = rule_for(head, CSS_RULES) or 'keep'
        if r == 'skip':
            continue
        if r == 'base':
            body = body[body.index('* { box-sizing'):]
        elif r == 'keyframes':
            body = '\n'.join(l for l in body.split('\n') if l.startswith('@keyframes'))
        elif r == 'panel':
            body = '\n'.join(l for l in body.split('\n') if not l.startswith(('.comp {', '.comp:last-child')))
        css_out.append(body.rstrip())
    files['kodou.css'] = '\n'.join(css_out).rstrip() + '\n'

    # ---- JS
    kodou, icons, comp_js, unknown = [], [], {}, []
    jb = blocks(script, r'^/\* ')
    pre = jb[0][1].replace("'use strict';\n", '')
    kodou.append(pre.strip())
    hoisted = []
    for head, body in jb[1:]:
        keep = []
        for l in body.split('\n'):
            (hoisted if l.startswith(HOIST) else keep).append(l)
        body = '\n'.join(keep)
        r = rule_for(head, JS_RULES)
        if r is None:
            unknown.append(head[:40]); continue
        if r in ('skip',):
            continue
        if r in ('virt', 'ledbar'):
            have = open(os.path.join(OUT, r + '.js'), encoding='utf-8').read()
            code = lambda x: '\n'.join(l for l in x.split('\n') if l.strip() and not l.lstrip().startswith(('/*', '*', '//')))
            if code(body).strip() != code(have).strip():
                sys.exit(f'見本帳の {r} と assets/{r}.js の中身が違います。どちらかに揃えてください')
            continue
        if r == 'kodou':
            kodou.append(body.rstrip())
        elif r == 'icons':
            icons.append(body.rstrip())
        else:
            for c in r:
                comp_js.setdefault(c, []).append(body.rstrip())
    if unknown:
        sys.exit('対応表に無い JS の節があります: ' + ' / '.join(unknown))
    kodou.append('/* スピナーの文字と、数の並びを ▁▂▃ の 1 行にする spark（いくつかの部品で使う） */\n' + '\n'.join(hoisted))
    kodou.append("/* ステータスライン: #slMsg があれば一言出す */\nconst sl = { msg(t) { const el = document.getElementById('slMsg'); if (el) frame('slmsg', () => { el.textContent = t }) } };")
    kodou.append('startLoop();')
    files['kodou.js'] = KODOU_HEAD + "'use strict';\n" + '\n\n'.join(kodou) + '\n'
    files['icons.js'] = ('/* Kodou-ui のドット絵のアイコン。tools/build-assets.py が見本帳から書き出す（手で直さない）。\n'
                         '   px(名前, 1マスの px, 内側を塗るか, 8×8 を使うか) が SVG の文字列を返す。[data-px="名前"] の要素には読み込んだ時に入る。\n'
                         '   描き方の決まりと足し方は references/icons.md */\n' + '\n\n'.join(icons) + '\n')

    # ---- 部品ごとの見本
    secs = re.findall(r'(<section class="comp" id="c-([\w-]+)" data-grp="([^"]+)">.*?</section>)', src, re.S)
    rows = []
    for html, cid, grp in secs:
        if cid in SKIP_SECTIONS:
            continue
        name = re.search(r'<h2>(.*?)<span class="en">(.*?)</span></h2>', html)
        ja, en = name.group(1), name.group(2)
        lead = re.search(r'<p class="lead">(.*?)</p>', html, re.S)
        js = '\n\n'.join(comp_js.get(cid, []))
        extra = '<div class="toasts" id="toasts" aria-live="polite"></div>\n' if cid == 'toast' else ''
        page = f'''<!doctype html>
<html lang="ja">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kodou-ui {ja}</title>
<!-- Kodou-ui の部品の見本: {ja}（{en}）。tools/build-assets.py が見本帳から書き出す（手で直さない）。
     決まりは references/components.md の「{ja}」。作るときは、下の HTML と、最後の <script> の中の JS をそのまま写して使う。
     共通の CSS と関数は ../tokens.css ・ ../kodou.css ・ ../virt.js ・ ../ledbar.js ・ ../kodou.js ・ ../icons.js にある（この順に読む）。 -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=BIZ+UDGothic:wght@400;700&family=JetBrains+Mono:wght@400;500;700&display=swap">
<link rel="stylesheet" href="../tokens.css">
<link rel="stylesheet" href="../kodou.css">
<style>.kd-page {{ max-width: 960px; margin: 0 auto; padding: 24px max(16px, env(safe-area-inset-left, 0px)) 80px }}</style>
<body>
<main class="kd-page">
{html}
</main>
{extra}<div class="statusline" role="status" aria-live="off"><span class="sl-mode pl">NORMAL</span><span class="sl-msg" id="slMsg">{ja}</span></div>
<script src="../virt.js"></script>
<script src="../ledbar.js"></script>
<script src="../kodou.js"></script>
<script src="../icons.js"></script>
<script>
{js}
</script>
</body>
</html>
'''
        files[f'components/{cid}.html'] = page
        summary = re.sub(r'<[^>]+>', '', lead.group(1)).strip().split('。')[0] + '。' if lead else ''
        rows.append(f'| {grp} | [{ja}]({cid}.html) | `{cid}.html` | {summary} |')
    files[SWIFT_ICONS] = swift_icons(files['icons.js'])
    # Swift の部品はスキルの assets/swift/KodouUI/ に写す。書き出した Tokens.swift と IconData.swift は、今作った中身を写す
    for f in sorted(os.listdir(SWIFT_SRC)):
        if f.endswith('.swift'):
            src_path = os.path.join(SWIFT_SRC, f)
            files[f'swift/KodouUI/{f}'] = files.get(src_path) or open(src_path, encoding='utf-8').read()
    files['components/README.md'] = ('# 部品の見本\n\n'
        '見本帳（catalog/index.html）から、部品ごとに切り出した見本です。`tools/build-assets.py` が書き出すので、手で直さないでください。\n\n'
        '作るときは、使う部品のファイルだけを読み、HTML と最後の `<script>` の JS を写します。'
        '共通の CSS と関数は `../tokens.css`・`../kodou.css`・`../virt.js`・`../ledbar.js`・`../kodou.js`・`../icons.js` で、この順に読みます。'
        '使いどころと決まりは `../../references/components.md` にあります。\n\n'
        '| 種類 | 部品 | ファイル | 決まりの要点 |\n|---|---|---|---|\n' + '\n'.join(rows) + '\n')
    return files

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--check', action='store_true', help='書き出さずに、今のファイルが見本帳と合っているかだけ見る')
    a = ap.parse_args()
    files = build()
    stale = []
    for rel, text in files.items():
        p = os.path.join(OUT, rel)
        old = open(p, encoding='utf-8').read() if os.path.exists(p) else None
        if old == text:
            continue
        if a.check:
            stale.append(rel)
        else:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            open(p, 'w', encoding='utf-8').write(text)
    have = set()
    for sub in ('components', os.path.join('swift', 'KodouUI')):
        d = os.path.join(OUT, sub)
        if os.path.isdir(d):
            have |= {f'{sub}/{f}' for f in os.listdir(d)}
    extra = sorted(have - set(files))
    if a.check:
        if stale or extra:
            print('見本帳と合っていません。python3 tools/build-assets.py を回してください:\n  ' + '\n  '.join(stale + [e + '（見本帳に無い）' for e in extra]))
            return 1
        print(f'{len(files)} 個のファイルが見本帳と合っています。')
        return 0
    for e in extra:
        os.remove(os.path.join(OUT, e))
    print(f'{len(files)} 個のファイルを書き出しました（部品 {sum(1 for f in files if f.endswith(".html"))} 個、Swift {sum(1 for f in files if f.startswith("swift/"))} 個）。')
    return 0

if __name__ == '__main__':
    sys.exit(main())
