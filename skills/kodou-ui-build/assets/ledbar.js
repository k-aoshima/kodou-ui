/* LED の帯（Kodou-ui の ledBar）。依存なし。進捗バーとメーターはこれで描く。
   - 4px のブロックを 2px あけて並べる（高さ 8px）。埋まった所は色、残りは薄い溝。割合はブロックの数で見せ、数字も横に出す。
   - 内訳（キャッシュ、眠っている分など）は同じ色の斜線で、色だけでなく形でも分ける。
   - projected: この調子で進んだときの見込み。中を抜いた枠のブロックで延ばす。
   - stopAt: 止める水準。そこから右は地を薄い赤にし、超えて使った分は赤の斜線。1px の赤い縦線も引く。
   - elapsed: 時間の経過。上に小さな ▼ を置く。
   1 枚の canvas に、整数の位置で、にじまないように描く。色はトークン（CSS 変数）から読むので、明るい地と暗い地の両方で使える。

   使い方:
     ledBar(canvas, { segs: [{ value: 0.48 }, { value: 0.14, hatch: true }], projected: 0.85, stopAt: 0.85, elapsed: 0.62 });
     ledBar(canvas, { segs: [{ value: done / total }] });          // 進捗
     ledBar(canvas, { segs: [{ value: used / max, color: 'var(--yellow)' }] });   // 境目を超えたメーター（色に加えて「注意」の文字も横に出す）
   大きさが変わったら描き直す: new ResizeObserver(() => ledBar(canvas, opts)).observe(canvas)
*/
function ledBar(cv, { segs = [], projected = null, stopAt = null, elapsed = null, cell = 4, gap = 2, height = 8 } = {}) {
  const css = getComputedStyle(cv);
  const tok = (v, fb) => { const m = /^var\((--[\w-]+)\)$/.exec(v || ''); return m ? (css.getPropertyValue(m[1]).trim() || fb) : (v || fb) };
  const accent = tok('var(--accent)', '#0058A0'), red = tok('var(--red)', '#BE3F0E'), fg = tok('var(--fg)', '#20242B'), track = tok('var(--rule-soft)', 'rgba(32,36,43,.10)');
  const w = cv.clientWidth, top = elapsed != null ? 6 : (stopAt != null ? 2 : 0), H = top + height + (stopAt != null ? 2 : 0), dpr = Math.min(2, devicePixelRatio || 1);
  cv.style.height = H + 'px'; cv.width = Math.round(w * dpr); cv.height = Math.round(H * dpr);
  const ctx = cv.getContext('2d'); ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.imageSmoothingEnabled = false; ctx.clearRect(0, 0, w, H);
  const pitch = cell + gap, n = Math.max(1, Math.floor((w + gap) / pitch));
  let acc = 0; const ends = segs.filter(x => x.value > 0).map(x => (acc += x.value, [acc, x]));
  const hatch = (x, y, ww, hh, c) => { ctx.fillStyle = c; for (let yy = 0; yy < hh; yy++) for (let xx = yy % 3; xx < ww; xx += 3) ctx.fillRect(x + xx, y + yy, 1, 1) };
  for (let i = 0; i < n; i++) {
    const x = Math.round(i * pitch), mid = (i + .5) / n, over = stopAt != null && mid > stopAt;
    ctx.fillStyle = track; ctx.fillRect(x, top, cell, height);
    if (over) { ctx.globalAlpha = .14; ctx.fillStyle = red; ctx.fillRect(x, top, cell, height); ctx.globalAlpha = 1 }
    const hit = mid <= acc ? ends.find(e => mid <= e[0]) : null;
    if (hit) { const c = tok(hit[1].color, accent); if (over || hit[1].hatch) hatch(x, top, cell, height, over ? red : c); else { ctx.fillStyle = c; ctx.fillRect(x, top, cell, height) } }
    else if (projected != null && mid <= projected) { ctx.globalAlpha = .8; ctx.strokeStyle = accent; ctx.lineWidth = 1; ctx.strokeRect(x + .5, top + .5, cell - 1, height - 1); ctx.globalAlpha = 1 }
  }
  if (stopAt != null) { ctx.fillStyle = red; ctx.fillRect(Math.round(w * Math.min(1, stopAt)), top - 2, 1, height + 4) }
  if (elapsed != null) { ctx.fillStyle = fg; const cx = Math.round(w * Math.min(1, Math.max(0, elapsed))); for (let k = 0; k < 4; k++) ctx.fillRect(cx - (3 - k), k, 7 - 2 * k, 1) }
}
