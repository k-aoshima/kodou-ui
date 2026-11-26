#!/usr/bin/env python3
"""Swift のベンチを回す。版ごとに KodouBench.app を 1 回ずつ起動し、中央値をまとめる。

  python3 bench/swift/run.py [回数=3] [--stream 60] [--only kodou,web]

測っているあいだ、1280×800 の窓が手前に出る（ほかの窓の下に隠れると止まる版があるため、浮かせて出す）。
結果は bench/swift/results-<日付>.json に書く。
"""
import json, os, subprocess, sys, datetime, platform

HERE = os.path.dirname(os.path.abspath(__file__))
EXE = os.path.join(HERE, 'build', 'KodouBench.app', 'Contents', 'MacOS', 'KodouBench')
HTML = os.path.join(HERE, '..', 'dist', 'kodou.html')
VARIANTS = ['kodou', 'lazy', 'tuned', 'plain', 'web', 'empty']

def opt(k, d):
    a = sys.argv
    return a[a.index(k) + 1] if k in a else d

def main():
    args = [x for i, x in enumerate(sys.argv[1:]) if not x.startswith('--') and (i == 0 or not sys.argv[i].startswith('--'))]
    runs = int(args[0]) if args else 3
    stream = opt('--stream', '60')
    variants = opt('--only', ','.join(VARIANTS)).split(',')
    subprocess.run([os.path.join(HERE, 'build.sh')], check=True, stdout=subprocess.DEVNULL)
    if not os.path.exists(HTML):
        sys.exit('bench/dist/kodou.html がありません。先に bench/build.sh を回してください')
    raw = {v: [] for v in variants}
    tmp = os.path.join(HERE, 'build', 'one.json')
    for r in range(runs):
        for v in variants:
            if os.path.exists(tmp):
                os.remove(tmp)
            subprocess.run([EXE, '--variant', v, '--stream', stream, '--html', os.path.abspath(HTML), '--out', tmp],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=int(stream) + 180)
            o = json.load(open(tmp))
            raw[v].append(o)
            print(v, r + 1, json.dumps({k: (round(x, 1) if isinstance(x, float) else x) for k, x in o.items() if k != 'memParts'}, ensure_ascii=False), file=sys.stderr)
    med = lambda a: sorted(a)[len(a) // 2]
    keys = [k for k, x in raw[variants[0]][0].items() if isinstance(x, (int, float))]
    summary = {v: {k: round(med([o[k] for o in raw[v]]), 2) for k in keys} for v in variants}
    for v in variants:
        parts = {}
        for o in raw[v]:
            for k, x in o['memParts'].items():
                parts.setdefault(k, []).append(x)
        summary[v]['memParts'] = {k: round(med(x), 1) for k, x in parts.items()}
    out = {'date': datetime.datetime.now().isoformat(timespec='seconds'), 'macos': platform.mac_ver()[0],
           'machine': subprocess.run(['sysctl', '-n', 'machdep.cpu.brand_string'], capture_output=True, text=True).stdout.strip(),
           'runs': runs, 'streamSec': int(stream), 'summary': summary, 'raw': raw}
    path = os.path.join(HERE, f'results-{datetime.date.today().isoformat()}.json')
    json.dump(out, open(path, 'w'), indent=2, ensure_ascii=False)
    cols = ['memMB', 'busyPct', 'frameP95', 'longFrames', 'selectMs', 'readyMs', 'hiddenBusyPct']
    print('variant'.ljust(8) + ''.join(c.rjust(14) for c in cols))
    for v in variants:
        print(v.ljust(8) + ''.join(str(summary[v][c]).rjust(14) for c in cols))
    print('→', os.path.relpath(path))

if __name__ == '__main__':
    main()
