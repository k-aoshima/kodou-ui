#!/usr/bin/env python3
"""Kodou-ui の点検のうち、スクリプトで測れるものを 1 回でまとめて回す。

  python3 check.py page.html                 # コントラスト・アイコン・決まりの検出
  python3 check.py page.html src/ --measure  # 加えて要素の数と軽さ（Node・puppeteer-core・Chrome が要る）

HTML ごとに、トークン（:root の --fg と --bg）があれば contrast.py、
アイコンの定数（const PX12 = / const PX =）があれば icon.py を回す。
lint.py はすべてのファイルに回す。最後に、どれが通ったかを表で出す。

終了コード: 0 はすべて通った、1 は基準を割るものがあった、2 は回せなかった。
CI に載せるときは、このコマンドの終了コードを見る。
"""
import argparse, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable

def run(cmd, quiet):
    r = subprocess.run(cmd, capture_output=True, text=True)
    out = (r.stdout + r.stderr).rstrip()
    if out and (not quiet or r.returncode):
        print(out + '\n')
    return r.returncode

def html_files(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in {'node_modules', '.git', 'dist', 'build'}]
                for f in sorted(files):
                    if f.endswith(('.html', '.htm')):
                        yield os.path.join(root, f)
        elif p.endswith(('.html', '.htm')):
            yield p

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('paths', nargs='+', help='HTML・CSS・JS のファイルかフォルダ')
    ap.add_argument('--measure', action='store_true', help='measure.mjs も回す（HTML ごと）')
    ap.add_argument('--quiet', '-q', action='store_true', help='通ったものの詳細は出さない')
    a = ap.parse_args()
    for p in a.paths:
        if not os.path.exists(p):
            print(f'見つかりません: {p}', file=sys.stderr); return 2

    results = []  # (対象, 点検, 終了コード)
    for f in html_files(a.paths):
        text = open(f, encoding='utf-8', errors='replace').read()
        if re.search(r':root\s*\{[^}]*--fg\s*:', text) and re.search(r':root\s*\{[^}]*--bg\s*:', text):
            print(f'== コントラスト {f}')
            results.append((f, 'コントラスト', run([PY, os.path.join(HERE, 'contrast.py'), f], a.quiet)))
        for name in ('PX12', 'PX'):
            if re.search(r'const\s+' + name + r'\s*=\s*\{', text):
                print(f'== アイコン（{name}） {f}')
                results.append((f, f'アイコン {name}', run([PY, os.path.join(HERE, 'icon.py'), f, '--set', name], a.quiet)))
        if a.measure:
            print(f'== 軽さ {f}')
            results.append((f, '軽さ', run(['node', os.path.join(HERE, 'measure.mjs'), f], a.quiet)))

    print('== 決まりの検出 ' + ' '.join(a.paths))
    results.append((' '.join(a.paths), '決まりの検出', run([PY, os.path.join(HERE, 'lint.py'), *a.paths], False)))

    mark = {0: 'OK', 1: 'NG'}
    print('| 結果 | 点検 | 対象 |\n|---|---|---|')
    for target, what, code in results:
        print(f'| {mark.get(code, "回せない")} | {what} | {target} |')
    codes = [c for _, _, c in results]
    if any(c not in (0, 1) for c in codes):
        return 2
    return 1 if any(codes) else 0

if __name__ == '__main__':
    sys.exit(main())
