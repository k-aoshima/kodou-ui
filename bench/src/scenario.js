// 3 つの版で同じにする中身。数と速さを変えるときはここだけ直す
export const SCN = {
  rows: 10000,        // 一覧の行数（セッションやコミットの一覧に当たる）
  rowEveryMs: 200,    // 一覧の 1 行の状態が変わる間隔（5 行/秒）
  logEveryMs: 20,     // ログが 1 行増える間隔（50 行/秒）
  logCap: 2000,       // ログに残す行の上限（どの版も同じ上限のリングバッファ）
  points: 20000,      // グラフの点の数
  pointEveryMs: 100,  // グラフに 1 点足す間隔（10 点/秒）
};
const VERBS = ['直す', '足す', '消す', '揃える', '分ける', '速くする', '見直す', '軽くする'];
const OBJ = ['入力欄', 'ステータスライン', 'ログ', '表の並べ替え', 'トークン', 'ツリー', 'ダイアログ', 'グラフの目盛り', 'リスト', 'タグ入力'];
const WHO = ['aki', 'mika', 'ren', 'bot'];
export const STATES = ['idle', 'run', 'wait', 'done'];
const h32 = i => { let x = (i + 1) * 2654435761 >>> 0; x ^= x >>> 15; x = Math.imul(x, 2246822519) >>> 0; x ^= x >>> 13; return x >>> 0 };
export const row = i => { const h = h32(i); return { id: i, hash: h.toString(16).padStart(8, '0').slice(0, 7), who: WHO[h % 4], msg: `${OBJ[(h >>> 3) % 10]}を${VERBS[(h >>> 7) % 8]}`, state: STATES[h % 4] } };
const SRC = [['info', 'GET /api/session 200 12ms'], ['info', 'GET /api/usage 200 8ms'], ['warn', 'slow query: SELECT * FROM events 412ms'], ['info', 'POST /api/run 202 4ms'], ['error', 'job 7f3a: exit 1  TypeError: cannot read "chips" of undefined'], ['info', 'GET /health 200 1ms']];
export const logLine = k => { const [lv, m] = SRC[k % SRC.length]; return { k, lv, t: `00:${String((k / 50 | 0) % 60).padStart(2, '0')}:${String(k % 50).padStart(2, '0')}`, m } };
// 決まった順の乱数（どの版も同じ値になる）
export function rng(seed = 7) { return () => (seed = (seed * 16807) % 2147483647) / 2147483647 }
export function series(n, r) { const d = new Float32Array(n); let v = 30; for (let i = 0; i < n; i++) { v += (r() - .5) * 6 + (40 - v) * .01; if (r() < .0015) v += 40; v = Math.max(1, Math.min(99, v)); d[i] = v } return d }
export const nextPoint = (prev, r) => { let v = prev + (r() - .5) * 6 + (40 - prev) * .01; if (r() < .0015) v += 40; return Math.max(1, Math.min(99, v)) };
