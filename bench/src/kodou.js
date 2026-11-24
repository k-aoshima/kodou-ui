// Kodou-ui の決まりで作った版。依存なし、rAF 1 本、差分更新、仮想スクロール、リングバッファ、canvas の間引き、隠れたら止める
import { SCN, row, logLine, rng, series, nextPoint, STATES } from './scenario.js';
const $ = s => document.querySelector(s);
document.body.innerHTML = `
<div class="app">
  <section class="box"><span class="ttl">sessions</span><div class="vl" id="vl" tabindex="0"><div id="sp"></div></div></section>
  <section class="box"><span class="ttl">log</span><div class="log" id="log"></div></section>
  <section class="box wide"><span class="ttl">cpu</span><div class="cv" id="cvBox"><canvas id="cv"></canvas></div></section>
</div>`;

/* rAF 1 本にまとめ、隠れている間は止める */
const jobs = new Map(); let rafId = 0;
const frame = (k, fn) => { jobs.set(k, fn); if (!rafId) rafId = requestAnimationFrame(() => { rafId = 0; const js = [...jobs.values()]; jobs.clear(); js.forEach(f => f()) }) };
const tasks = []; const every = (ms, fn) => tasks.push({ ms, fn, last: 0 });
let loopId = 0;
function loop(now) { loopId = requestAnimationFrame(loop); for (const t of tasks) if (now - t.last >= t.ms) { const n = Math.floor((now - t.last) / t.ms); t.last = t.last ? t.last + n * t.ms : now; for (let i = 0; i < Math.min(n, 10); i++) t.fn() } }
const start = () => { if (!loopId) loopId = requestAnimationFrame(loop) };
const stop = () => { cancelAnimationFrame(loopId); loopId = 0; tasks.forEach(t => t.last = 0) };
document.addEventListener('visibilitychange', () => document.hidden ? stop() : start());

/* 一覧: 見えている行だけ。行の要素は使い回し、変わった行だけ書き換える */
const H = 22, vl = $('#vl'), sp = $('#sp');
const data = Array.from({ length: SCN.rows }, (_, i) => row(i));
sp.style.height = SCN.rows * H + 'px';
const POOL = Math.ceil(vl.clientHeight / H) + 6, pool = [];
let act = 0;
for (let k = 0; k < POOL; k++) { const r = document.createElement('div'); r.className = 'row'; r.innerHTML = '<span class="h"></span><span class="a"></span><span class="m"></span><span class="s"></span>'; r.dataset.i = -1; sp.appendChild(r); pool.push(r) }
const fill = (r, i) => { const d = data[i], c = r.children; c[0].textContent = d.hash; c[1].textContent = d.who; c[2].textContent = d.msg; c[3].textContent = d.state; r.dataset.s = d.state; r.dataset.i = i; r.style.transform = `translateY(${i * H}px)` };
function draw() {
  const f = Math.max(0, Math.min(SCN.rows - POOL, Math.floor(vl.scrollTop / H) - 3));
  for (let k = 0; k < POOL; k++) { const i = f + k, r = pool[i % POOL]; if (+r.dataset.i !== i) fill(r, i); r.classList.toggle('on', i === act) }
}
vl.addEventListener('scroll', () => frame('vl', draw), { passive: true });
const rr = rng(11);
every(SCN.rowEveryMs, () => {
  const i = Math.floor(rr() * 40);  // 上のほうの行が変わる（見えている行も見えていない行もある）
  data[i] = { ...data[i], state: STATES[(STATES.indexOf(data[i].state) + 1) % 4] };
  const r = pool[i % POOL]; if (+r.dataset.i === i) { r.children[3].textContent = data[i].state; r.dataset.s = data[i].state }
});
window.__select = i => { act = i; const top = i * H; if (top < vl.scrollTop || top + H > vl.scrollTop + vl.clientHeight) vl.scrollTop = top; draw() };

/* ログ: 上限つき。足すのは 1 行、捨てるのは先頭の 1 行 */
const log = $('#log'); let k = 0;
const lineEl = l => { const d = document.createElement('div'); d.className = l.lv; d.innerHTML = `<span class="t">${l.t}</span><span class="lv">${l.lv.toUpperCase()}</span><span class="m"></span>`; d.lastChild.textContent = l.m; return d };
let pending = [];
every(SCN.logEveryMs, () => { pending.push(logLine(k++)); frame('log', () => {
  const frag = document.createDocumentFragment(); pending.forEach(l => frag.appendChild(lineEl(l))); pending = [];
  log.appendChild(frag); while (log.childElementCount > SCN.logCap) log.firstElementChild.remove();
  log.scrollTop = log.scrollHeight;
}) });

/* グラフ: canvas、描く幅の 1 列に 1 点（列ごとの最小と最大） */
const r2 = rng(7), N = SCN.points; let pts = series(N, r2), head = 0;  // pts はリングバッファ。head が一番古い点
const box = $('#cvBox'), cv = $('#cv'), ctx = cv.getContext('2d');
function chart() {
  const w = Math.max(1, box.clientWidth | 0), h = box.clientHeight | 0, dpr = Math.min(2, devicePixelRatio || 1);
  if (cv.width !== w * dpr || cv.height !== h * dpr) { cv.width = w * dpr; cv.height = h * dpr }
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, w, h);
  for (let c = 0; c < w; c++) {
    const a = Math.floor(c * N / w), b = Math.max(a + 1, Math.floor((c + 1) * N / w)); let mn = 1e9, mx = -1e9;
    for (let i = a; i < b; i++) { const x = pts[(head + i) % N]; if (x < mn) mn = x; if (x > mx) mx = x }
    const y1 = Math.round(h - mx / 100 * h), y2 = Math.round(h - mn / 100 * h);
    ctx.fillStyle = mx > 80 ? '#C2410C' : '#1F5FA8'; ctx.fillRect(c, y1, 1, Math.max(2, y2 - y1));
  }
}
every(SCN.pointEveryMs, () => { const prev = pts[(head + N - 1) % N]; pts[head] = nextPoint(prev, r2); head = (head + 1) % N; frame('cv', chart) });
new ResizeObserver(() => frame('cv', chart)).observe(box);

draw(); chart(); start();
requestAnimationFrame(() => requestAnimationFrame(() => { window.__ready = performance.now() }));
