#!/usr/bin/env python3
"""マス目（# と .）で描いたアイコンを点検し、SVG に書き出す。

使い方:
  python3 scripts/icon.py catalog/index.html               # PX12 を点検
  python3 scripts/icon.py catalog/index.html --set PX      # 8×8 の PX を点検
  python3 scripts/icon.py my-icons.txt --out build/icons   # 点検して SVG を書き出す
  python3 scripts/icon.py catalog/index.html --name gear --show   # 1個をマス目で表示

入力:
  - .html / .js: `const PX12 = { name: ["....", ...], ... }` の形を読む（--set で名前を選ぶ）
  - .txt: 1行目に名前、続けてマス目の行、空行で区切る

点検すること:
  - 大きさ: すべての行が同じ幅で、幅と高さが --size（既定は PX12 なら 12、PX なら 8）と合う
  - 外周の余白と中心: 上下左右の空きマスを出す。左右か上下の空きの差が2マス以上なら注意（中心がずれている）
  - 孤立したマス: 斜めも含めて周りに # が1つも無い # は注意（ノイズのことが多い）
  - 空のアイコン
問題があれば終了コード 1 を返す（注意だけなら 0）。
"""
import argparse, os, re, sys


def load(path, setname):
    text = open(path, encoding='utf-8').read()
    icons = {}
    if path.endswith('.txt'):
        for chunk in re.split(r'\n\s*\n', text.strip()):
            lines = [l.strip() for l in chunk.splitlines() if l.strip()]
            if lines:
                icons[lines[0].rstrip(':')] = lines[1:]
        return icons
    m = re.search(r'const\s+' + re.escape(setname) + r'\s*=\s*\{(.*?)\n\};', text, re.S)
    if not m:
        sys.exit(f'{path} に const {setname} = {{ ... }}; が見つかりません')
    for name, body in re.findall(r'([\w-]+)\s*:\s*\[(.*?)\]', m.group(1), re.S):
        icons[name] = re.findall(r'["\']([#.]+)["\']', body)
    return icons


def runs(test, w, h):
    d = ''
    for y in range(h):
        x = 0
        while x < w:
            if not test(x, y):
                x += 1; continue
            e = x
            while e < w and test(e, y):
                e += 1
            d += f'M{x} {y}h{e - x}v1h-{e - x}z'
            x = e
    return d


def inside(rows):
    h, w = len(rows), len(rows[0])
    out = [[False] * w for _ in range(h)]
    st = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while st:
        x, y = st.pop()
        if not (0 <= x < w and 0 <= y < h) or out[y][x] or rows[y][x] == '#':
            continue
        out[y][x] = True
        st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return lambda x, y: rows[y][x] != '#' and not out[y][x]


def svg(rows, cell, tone):
    h, w = len(rows), len(rows[0])
    paths = ''
    if tone:
        d = runs(inside(rows), w, h)
        if d:
            paths += f'<path fill="currentColor" opacity=".3" d="{d}"/>'
    paths += f'<path fill="currentColor" d="{runs(lambda x, y: rows[y][x] == "#", w, h)}"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * cell:g}" height="{h * cell:g}" '
            f'viewBox="0 0 {w} {h}" shape-rendering="crispEdges">{paths}</svg>\n')


def check(name, rows, size):
    errs, warns = [], []
    if not rows:
        return [f'{name}: 行がありません'], []
    widths = {len(r) for r in rows}
    if len(widths) != 1:
        errs.append(f'{name}: 行の幅がそろっていません {sorted(widths)}')
        return errs, warns
    w, h = widths.pop(), len(rows)
    if size and (w, h) != (size, size):
        errs.append(f'{name}: 大きさが {w}×{h}（{size}×{size} のはず）')
    cells = [(x, y) for y in range(h) for x in range(w) if rows[y][x] == '#']
    if not cells:
        return errs + [f'{name}: # がありません'], warns
    xs, ys = [c[0] for c in cells], [c[1] for c in cells]
    margin = (min(ys), w - 1 - max(xs), h - 1 - max(ys), min(xs))  # 上 右 下 左
    if abs(margin[1] - margin[3]) >= 2:
        warns.append(f'{name}: 左右の中心がずれています（左{margin[3]} 右{margin[1]}）')
    if abs(margin[0] - margin[2]) >= 2:
        warns.append(f'{name}: 上下の中心がずれています（上{margin[0]} 下{margin[2]}）')
    s = set(cells)
    near = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx, dy) != (0, 0)]
    lone = [c for c in cells if not any((c[0] + dx, c[1] + dy) in s for dx, dy in near)]
    if lone:
        warns.append(f'{name}: 孤立したマス {len(lone)} 個 {lone[:4]}')
    return errs, warns, margin


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('file')
    ap.add_argument('--set', default='PX12', help='読む定数の名前（既定 PX12）')
    ap.add_argument('--size', type=int, help='期待する一辺のマス数（既定は PX12→12、PX→8、ほかは点検しない）')
    ap.add_argument('--skip', default='knob,heart', help='大きさの点検から外す名前（カンマ区切り）')
    ap.add_argument('--out', help='SVG を書き出すフォルダ')
    ap.add_argument('--cell', type=float, default=1.5, help='書き出す SVG の1マスの px（既定 1.5）')
    ap.add_argument('--tone', action='store_true', help='内側を塗った版も書き出す')
    ap.add_argument('--name', help='この名前だけを扱う')
    ap.add_argument('--show', action='store_true', help='マス目を表示する')
    a = ap.parse_args()
    size = a.size or {'PX12': 12, 'PX': 8}.get(a.set)
    skip = set(a.skip.split(',')) if a.skip else set()
    icons = load(a.file, a.set)
    if a.name:
        icons = {a.name: icons[a.name]}
    n_err = n_warn = 0
    for name, rows in icons.items():
        res = check(name, rows, None if name in skip else size)
        errs, warns = res[0], res[1]
        margin = res[2] if len(res) > 2 else None
        mark = 'NG ' if errs else ('注意' if warns else 'OK ')
        mtxt = f'余白 上{margin[0]} 右{margin[1]} 下{margin[2]} 左{margin[3]}' if margin else ''
        print(f'{mark} {name:<10} {len(rows[0]) if rows else 0}×{len(rows)}  {mtxt}')
        for e in errs: print('     ✗ ' + e)
        for w_ in warns: print('     ! ' + w_)
        if a.show:
            for r in rows: print('       ' + r.replace('#', '██').replace('.', '··'))
        n_err += len(errs); n_warn += len(warns)
        if a.out and not errs:
            os.makedirs(a.out, exist_ok=True)
            open(os.path.join(a.out, f'{name}.svg'), 'w').write(svg(rows, a.cell, False))
            if a.tone:
                open(os.path.join(a.out, f'{name}-tone.svg'), 'w').write(svg(rows, a.cell, True))
    print(f'\n{len(icons)} 個  問題 {n_err}  注意 {n_warn}' + (f'  SVG → {a.out}' if a.out else ''))
    sys.exit(1 if n_err else 0)


if __name__ == '__main__':
    main()
