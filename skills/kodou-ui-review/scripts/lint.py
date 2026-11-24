#!/usr/bin/env python3
"""Kodou-ui の決まりのうち、ファイルを読むだけで見つけられるものを探す。

AI を使わず、決まった規則で HTML・CSS・JS（jsx・tsx・vue・svelte も）を読む。
見つけたものは「[重さ] 場所 規則: 問題 → 直し方」の形で出す。

  python3 lint.py page.html src/          # ファイルかフォルダ（中を探す）
  python3 lint.py page.html --json        # 機械向けの出力
  python3 lint.py --rules                 # 規則の一覧

終了コード: 0 は見つからなかった、1 は見つかった、2 は読めなかった。
その行だけ外すときは、同じ行か 1 行前に `kodou-lint: ignore 規則名` と書く。
"""
import argparse, json, os, re, sys

EXT = {'.html', '.htm', '.css', '.js', '.mjs', '.jsx', '.ts', '.tsx', '.vue', '.svelte'}
SKIP_DIRS = {'node_modules', '.git', 'dist', 'build', '.next', 'vendor'}

# 規則: 名前 → (重さ, 問題, 直し方)
RULES = {
    'blocking-dialog': ('中', '画面を止める確認やお知らせ（confirm / alert / prompt）を使っている。流れが止まり、確認は慣れて読まれなくなる',
                        '取り消せる操作は確認をやめて取り消しを出す。取り返しのつかない操作だけ、その場の [y/N] で確かめる'),
    'vague-status':    ('中', '「処理中…」「完了しました」だけの表示。何を対象に何をしたのかが見えない',
                        '対象と件数・時間を実際の値で出す（例: 「3 / 12 件 src/ui を検査中」「12 件を削除しました（u で戻す）」）'),
    'apply-button':    ('中', '「検索」「適用」ボタンで結果を変えている。打つたびに絞れる手応えを捨てている',
                        'ボタンをやめ、1 文字ごとに結果を描き変える'),
    'left-accent-bar': ('中', '左端に色の縦線を引いて選択や強調を示している',
                        '選んだ行は反転表示（--sel-bg / --sel-fg）にし、強調は面の色で示す'),
    'focus-hidden':    ('重い', 'フォーカスの枠を消しているか点線にしている。キーボードでどこにいるか分からない',
                        'フォーカスはアクセント色 2px の実線にする（outline: 2px solid var(--accent)）'),
    'no-reduced-motion': ('中', '動き（transition / animation）があるのに prefers-reduced-motion で止めていない',
                          '@media (prefers-reduced-motion: reduce) で動きを止める'),
    'layout-motion':   ('軽い', '幅・高さ・位置・余白を動かしている。描き直しが重く、カクつく',
                        '動かすのは transform と opacity だけにする'),
    'crt-effect':      ('軽い', '走査線やにじみで CRT を再現している。読みにくくなるだけで対話は増えない',
                        '形は古く、描画はくっきり。走査線・グロー・ちらつきを外す'),
    'hidden-loop':     ('中', 'タイマーやアニメーションのループを、頁が隠れている間も止めていない',
                        'visibilitychange で document.hidden を見て止める。画面外の部品は IntersectionObserver で止める'),
    'tiny-text':       ('軽い', '読ませる文字が 11px 未満',
                        'データは 12px 以上、文は 15px 以上にする'),
}

def css_rules(css):
    """いちばん内側の `セレクタ { 宣言 }` を、開始位置つきで返す。"""
    for m in re.finditer(r'([^{}]+)\{([^{}]*)\}', css):
        yield m.start(2), m.group(1).strip(), m.group(2)

def segments(text, ext):
    """(種類, 開始位置, 中身) を返す。種類は css / js / html。"""
    if ext == '.css':
        return [('css', 0, text)]
    if ext in {'.js', '.mjs', '.ts'}:
        return [('js', 0, text)]
    segs = []
    for m in re.finditer(r'<style[^>]*>(.*?)</style>', text, re.S | re.I):
        segs.append(('css', m.start(1), m.group(1)))
    for m in re.finditer(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', text, re.S | re.I):
        segs.append(('js', m.start(1), m.group(1)))
    if ext in {'.jsx', '.tsx'}:
        segs.append(('js', 0, text))
    segs.append(('html', 0, text))
    return segs

def check(path):
    text = open(path, encoding='utf-8', errors='replace').read()
    ext = os.path.splitext(path)[1].lower()
    lines = text.split('\n')
    starts = [0]
    for ln in lines:
        starts.append(starts[-1] + len(ln) + 1)

    def line_of(pos):
        lo, hi = 0, len(starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if starts[mid] <= pos: lo = mid
            else: hi = mid - 1
        return lo + 1

    found = []
    def add(rule, pos, what):
        ln = line_of(pos)
        near = '\n'.join(lines[max(0, ln - 2):ln])
        if re.search(r'kodou-lint:\s*ignore\b[^\n]*\b' + re.escape(rule) + r'\b', near):
            return
        sev, msg, fix = RULES[rule]
        found.append({'rule': rule, 'severity': sev, 'file': path, 'line': ln, 'what': what.strip()[:80], 'message': msg, 'fix': fix})

    segs = segments(text, ext)
    css_all = ''.join(s for k, _, s in segs if k == 'css')
    js_all = ''.join(s for k, _, s in segs if k == 'js')
    has_motion = False

    for kind, base, body in segs:
        if kind == 'css':
            for off, sel, decl in css_rules(body):
                pos = base + off
                if re.search(r'border-left\s*:\s*(?:[2-9]|\d{2,})px\s+solid', decl) or re.search(r'border-left-width\s*:\s*(?:[2-9]|\d{2,})px', decl) \
                   or re.search(r'box-shadow\s*:\s*inset\s+(?:[2-9]|\d{2,})px\s+0', decl):
                    add('left-accent-bar', pos, sel)
                if ':focus' in sel:
                    if re.search(r'outline[^;]*\bdotted\b', decl):
                        add('focus-hidden', pos, sel)
                    elif re.search(r'outline\s*:\s*(none|0)\b', decl) and not re.search(r'box-shadow|border', decl):
                        add('focus-hidden', pos, sel)
                t = re.search(r'transition(?:-property)?\s*:\s*([^;]+)', decl)
                if t and t.group(1).strip() not in ('none', '0s'):
                    has_motion = True
                    if re.search(r'\b(width|height|top|left|right|bottom|margin[\w-]*|padding[\w-]*|all)\b', t.group(1)):
                        add('layout-motion', pos, f'{sel} {{ transition: {t.group(1).strip()} }}')
                if re.search(r'animation(?:-name)?\s*:\s*(?!none)[\w-]', decl):
                    has_motion = True
                if re.search(r'scan-?line', sel, re.I) or re.search(r'text-shadow\s*:\s*0\s+0\s+(?:[4-9]|\d{2,})px', decl):
                    add('crt-effect', pos, sel)
                fs = re.search(r'font-size\s*:\s*(\d+(?:\.\d+)?)px', decl)
                if fs and float(fs.group(1)) < 11:
                    add('tiny-text', pos, f'{sel} {{ font-size: {fs.group(1)}px }}')
        elif kind == 'js':
            for m in re.finditer(r'(?<![\w.$])(?:window\.)?(confirm|alert|prompt)\s*\(', body):
                add('blocking-dialog', base + m.start(), m.group(0))
            for m in re.finditer(r'''(['"`])\s*(処理中|読み込み中|実行中|Loading|Processing)\s*(?:…|\.\.\.|・・・)?\s*\1''', body):
                add('vague-status', base + m.start(), m.group(0))
            for m in re.finditer(r'''(['"`])\s*(完了しました|処理が完了しました)[。!！]?\s*\1''', body):
                add('vague-status', base + m.start(), m.group(0))
        else:
            for m in re.finditer(r'>\s*(処理中|読み込み中|Loading|Processing)\s*(?:…|\.\.\.)?\s*<', body):
                add('vague-status', base + m.start(), m.group(0))
            for m in re.finditer(r'>\s*完了しました。?\s*<', body):
                add('vague-status', base + m.start(), m.group(0))
            for m in re.finditer(r'<button\b[^>]*>\s*(検索|適用|絞り込む|Search|Apply|Filter)\s*</button>', body, re.I):
                add('apply-button', base + m.start(), m.group(0))

    if has_motion and css_all and 'prefers-reduced-motion' not in css_all:
        add('no-reduced-motion', segs[0][1] if segs else 0, '動きのある CSS')
    # setInterval と、自分を呼び直す requestAnimationFrame（名前つきの関数を渡すもの）をループとみなす
    loop = re.search(r'setInterval\s*\(', js_all)
    if not loop:
        for m in re.finditer(r'requestAnimationFrame\s*\(\s*([A-Za-z_$][\w$]*)\s*\)', js_all):
            if re.search(r'(?:function\s+|(?:const|let|var)\s+)' + re.escape(m.group(1)) + r'\b', js_all):
                loop = m; break
    if loop and not re.search(r'visibilitychange|document\.hidden|visibilityState|IntersectionObserver', js_all):
        first = [s for s in segs if s[0] == 'js' and loop.group(0) in s[2]]
        pos = first[0][1] + first[0][2].index(loop.group(0)) if first else 0
        add('hidden-loop', pos, loop.group(0))
    return found

def walk(paths):
    for p in paths:
        if os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
                for f in sorted(files):
                    if os.path.splitext(f)[1].lower() in EXT:
                        yield os.path.join(root, f)
        else:
            yield p

ORDER = {'重い': 0, '中': 1, '軽い': 2}

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('paths', nargs='*')
    ap.add_argument('--json', action='store_true', help='JSON で出す')
    ap.add_argument('--rules', action='store_true', help='規則の一覧を出す')
    a = ap.parse_args()
    if a.rules:
        for k, (sev, msg, fix) in RULES.items():
            print(f'{k:<18} [{sev}] {msg}\n{"":<18} → {fix}')
        return 0
    if not a.paths:
        ap.print_usage(sys.stderr); return 2
    found = []
    try:
        for f in walk(a.paths):
            found += check(f)
    except OSError as e:
        print(f'読めません: {e}', file=sys.stderr); return 2
    found.sort(key=lambda x: (ORDER[x['severity']], x['file'], x['line']))
    if a.json:
        print(json.dumps(found, ensure_ascii=False, indent=2))
    else:
        for x in found:
            print(f'[{x["severity"]}] {x["file"]}:{x["line"]} {x["rule"]}: {x["message"]}\n       {x["what"]}\n       → {x["fix"]}')
        print(f'\n{len(found)} 件' if found else '決まりに反するものは見つかりませんでした。')
    return 1 if found else 0

if __name__ == '__main__':
    sys.exit(main())
