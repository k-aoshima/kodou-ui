/* Kodou-ui の共通の関数。tools/build-assets.py が見本帳から書き出す（手で直さない）。
   読む順: tokens.css → kodou.css →（body の最後で）virt.js・ledbar.js・kodou.js・icons.js → 部品の JS
   - $ / $$ / esc / css: 要素を取る、HTML に入れる文字を逃がす、CSS 変数を読む
   - frame(key, fn): 描き直しを 1 フレームに 1 回へまとめる
   - every(el, ms, fn): タイマーは 1 本。頁が隠れている間と el が画面外の間は止まる
   - place(pop, anchor): 重ねるもの（popover）を基準の要素の下に置く
   - sl.msg(text): ステータスライン（#slMsg）に一言出す。無ければ何もしない
   - ⌥ を押している間、[data-key] を持つ要素の上にキーの札を出す
*/
'use strict';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();

/* 描き直しは1フレームに1回へまとめる */
const jobs = new Map(); let rafId = 0;
function frame(key, fn) { jobs.set(key, fn); if (!rafId) rafId = requestAnimationFrame(() => { rafId = 0; const js = [...jobs.values()]; jobs.clear(); js.forEach(f => f()) }) }

/* タイマーは1本。頁が隠れている間と、部品が画面外の間は止める */
const tasks = []; const onScreen = new WeakMap();
const io = new IntersectionObserver(es => es.forEach(e => onScreen.set(e.target, e.isIntersecting)), { rootMargin: '80px' });
function every(el, ms, fn) { tasks.push({ el, ms, fn, last: 0 }); if (el) io.observe(el) }
let loopId = 0;
function loop(now) { loopId = requestAnimationFrame(loop); for (const t of tasks) { if (t.el && !onScreen.get(t.el)) continue; if (now - t.last >= t.ms) { t.last = now; t.fn(now) } } }
const startLoop = () => { if (!loopId) loopId = requestAnimationFrame(loop); document.body.classList.remove('paused') };
const stopLoop = () => { cancelAnimationFrame(loopId); loopId = 0; document.body.classList.add('paused') };
document.addEventListener('visibilitychange', () => document.hidden ? stopLoop() : startLoop());

/* 重ねるもの（popover）を基準の要素の下に置く。スクロールしたら閉じる */
function place(pop, anchor) {
  const r = anchor.getBoundingClientRect();
  pop.style.minWidth = r.width + 'px';
  pop.style.top = Math.min(r.bottom + 2, innerHeight - pop.offsetHeight - 30) + 'px';
  pop.style.left = Math.max(8, Math.min(r.left, innerWidth - pop.offsetWidth - 8)) + 'px';
}
addEventListener('scroll', () => { $$('.pop:popover-open').forEach(p => p.hidePopover()) }, { passive: true });

/* ⌥ を押している間だけ、画面に見えている部品の上に使えるキーを重ねる。札は押した時にだけ作り、離したら消す */
(() => {
  let layer = null;
  const show = () => {
    if (layer) return; layer = document.createElement('div'); layer.className = 'kh-layer'; layer.setAttribute('aria-hidden', 'true');
    const H = innerHeight; let html = '';
    for (const el of document.querySelectorAll('[data-key]')) { const r = el.getBoundingClientRect(); if (r.bottom < 0 || r.top > H || !r.width) continue; html += `<span class="kh" style="left:${Math.max(4, r.left + 6)}px;top:${Math.max(30, r.top - 9)}px">${esc(el.dataset.key)}</span>` }
    layer.innerHTML = html; document.body.appendChild(layer); sl.msg('いま見えている部品で使えるキーです。⌥ を離すと消えます');
  };
  const hide = () => { if (layer) { layer.remove(); layer = null } };
  addEventListener('keydown', e => { if (e.key === 'Alt') { e.preventDefault(); show() } else if (layer && !e.altKey) hide() });
  addEventListener('keyup', e => { if (e.key === 'Alt') hide() });
  addEventListener('blur', hide); addEventListener('scroll', hide, { passive: true });
})();

/* スピナーの文字と、数の並びを ▁▂▃ の 1 行にする spark（いくつかの部品で使う） */
const SP = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏';
const SPK = '▁▂▃▄▅▆▇█';
const spark = a => { const mx = Math.max(...a), mn = Math.min(...a); return a.map(v => SPK[Math.round((v - mn) / Math.max(1e-9, mx - mn) * 7)]).join('') };

/* ステータスライン: #slMsg があれば一言出す */
const sl = { msg(t) { const el = document.getElementById('slMsg'); if (el) frame('slmsg', () => { el.textContent = t }) } };

startLoop();
