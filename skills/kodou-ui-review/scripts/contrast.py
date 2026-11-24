#!/usr/bin/env python3
"""CSS のトークンを読んで、文字と地のコントラスト比を表で出す。

使い方:
  python3 scripts/contrast.py catalog/index.html
  python3 scripts/contrast.py tokens.css --text fg,dim,red --ground bg,panel

読むのは、素の `:root { ... }`（ライト）と `:root[data-theme="dark"] { ... }`（ダーク）の2つ。
値が `#rgb` / `#rrggbb` / `var(--x)` のトークンだけを扱い、rgba など透明を含む値は飛ばす。
基準: 文字は 4.5:1、部品の境界（--ui）とフォーカスは 3:1（WCAG 1.4.3 / 1.4.11）。
基準を割るものがあれば終了コード 1 を返す。
"""
import argparse, re, sys

TEXT = ['fg', 'dim', 'faint', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan']
GROUND = ['bg', 'panel']
UI = ['ui', 'accent']          # 3:1 で見る
DECO = ['deco']                # 飾り。基準なしで値だけ出す
FILLS = [('on', 'blue'), ('on', 'red'), ('on', 'blue-hover'), ('sel-fg', 'sel-bg')]  # 塗った面の上の文字


def block(css, selector_re):
    m = re.search(selector_re + r'\s*\{', css)
    if not m:
        return None
    i, depth = m.end(), 1
    j = i
    while j < len(css) and depth:
        depth += {'{': 1, '}': -1}.get(css[j], 0)
        j += 1
    return css[i:j - 1]


def tokens(body):
    out = {}
    for name, val in re.findall(r'--([\w-]+)\s*:\s*([^;]+);?', body or ''):
        out[name] = val.strip()
    return out


def resolve(toks, name, seen=()):
    v = toks.get(name)
    if v is None or name in seen:
        return None
    m = re.fullmatch(r'var\(--([\w-]+)\)', v)
    if m:
        return resolve(toks, m.group(1), seen + (name,))
    m = re.fullmatch(r'#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})', v)
    if not m:
        return None
    h = m.group(1)
    if len(h) == 3:
        h = ''.join(c * 2 for c in h)
    return tuple(int(h[k:k + 2], 16) / 255 for k in (0, 2, 4))


def lum(rgb):
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = map(f, rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('file')
    ap.add_argument('--text', help='文字のトークン（カンマ区切り）')
    ap.add_argument('--ground', help='地のトークン（カンマ区切り）')
    a = ap.parse_args()
    css = open(a.file, encoding='utf-8').read()
    css = '\n'.join(re.findall(r'<style[^>]*>(.*?)</style>', css, re.S)) or css
    light = tokens(block(css, r'(?<![\w\]\)]):root(?![\[:\w])'))
    dark = dict(light)
    dark.update(tokens(block(css, r':root\[data-theme="dark"\]')))
    text = a.text.split(',') if a.text else TEXT
    ground = a.ground.split(',') if a.ground else GROUND
    bad = []

    def row(label, cells):
        print(f'| {label:<14} | ' + ' | '.join(f'{c:>14}' for c in cells) + ' |')

    print(f'# {a.file}\n')
    print('## 文字（4.5:1 以上）  値は ライト / ダーク、地ごと\n')
    row('トークン', [f'{g}' for g in ground])
    print('|' + '-' * 16 + '|' + '|'.join('-' * 16 for _ in ground) + '|')
    for t in text:
        cells = []
        for g in ground:
            pair = []
            for theme, toks in (('ライト', light), ('ダーク', dark)):
                fg, bg = resolve(toks, t), resolve(toks, g)
                if not fg or not bg:
                    pair.append('-')
                    continue
                r = ratio(fg, bg)
                pair.append(f'{r:.1f}' + ('!' if r < 4.5 else ''))
                if r < 4.5:
                    bad.append(f'{theme} --{t} / --{g} = {r:.2f}（4.5 未満）')
            cells.append(' / '.join(pair))
        row(t, cells)

    print('\n## 部品の境界とフォーカス（3:1 以上、bg に対して）\n')
    for t in UI + DECO:
        pair = []
        for theme, toks in (('ライト', light), ('ダーク', dark)):
            fg, bg = resolve(toks, t), resolve(toks, 'bg')
            if not fg or not bg:
                pair.append('-'); continue
            r = ratio(fg, bg)
            need = t in UI
            pair.append(f'{r:.1f}' + ('!' if need and r < 3 else ''))
            if need and r < 3:
                bad.append(f'{theme} --{t} / --bg = {r:.2f}（3 未満）')
        print(f'- {t:<8} {" / ".join(pair)}' + ('  （飾り専用。文字に使わない）' if t in DECO else ''))

    print('\n## 塗った面の上の文字（4.5:1 以上）\n')
    for fgn, bgn in FILLS:
        pair = []
        for theme, toks in (('ライト', light), ('ダーク', dark)):
            fg, bg = resolve(toks, fgn), resolve(toks, bgn)
            if not fg or not bg:
                pair.append('-'); continue
            r = ratio(fg, bg)
            pair.append(f'{r:.1f}' + ('!' if r < 4.5 else ''))
            if r < 4.5:
                bad.append(f'{theme} --{fgn} on --{bgn} = {r:.2f}（4.5 未満）')
        print(f'- --{fgn} on --{bgn}: {" / ".join(pair)}')

    print()
    if bad:
        print('基準を割っているもの:')
        for b in bad:
            print('  - ' + b)
        sys.exit(1)
    print('すべて基準を満たしています。')


if __name__ == '__main__':
    main()
