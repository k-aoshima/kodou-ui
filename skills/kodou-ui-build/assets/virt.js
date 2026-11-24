/* 見えている分だけ描く（Kodou-ui の virt）。依存なし。
   行の高さがそろう集まり（リスト、ツリー、表、候補、ログ、プロセス）は、件数が少なくてもこれで描く。
   - 行の要素は「窓の行数＋上下の数行」だけ作り、スクロールしたら中身を差し替えて使い回す。何千件でも要素の数は変わらない。
   - 行はふつうの並びのまま置き（DOM の順＝見た目の順なので読み上げが崩れない）、上下の空白の高さで全体の高さを保つ。
   - 行の中身（fill）は、その行に出す番号が変わったときか、データが変わったときだけ書き換える。選択などの印（mark）は毎回 class を切り替えるだけ。
   - フォーカスは箱（owner）に置いたままにし、選んでいる行は aria-activedescendant で示す。行の要素は使い回されるので、行にフォーカスを置かない。
   - 窓の高さは CSS の max-height か height から読む（画面外の節では寸法が 0 になるため）。

   使い方:
     const v = virt(box, {
       H: 24,                                   // 行の高さ（px）。省くと中身を入れた行で 1 度だけ測る
       make: () => { const r = document.createElement('div'); r.className = 'row'; return r },
       fill: (r, i) => { r.textContent = items[i].name },          // i 番目の中身を入れる
       mark: (r, i) => r.classList.toggle('on', i === act),         // 印だけ付け直す
       id: 'files-',                            // 行の id の頭（aria-activedescendant に使う）
     });
     v.set(items.length);       // 数か中身が変わったら
     v.mark(prev); v.to(act); v.active(act);   // 選択を動かしたら
     box.addEventListener('click', e => { const i = v.index(e.target); ... });  // イベントは箱で 1 つだけ受ける
*/
function virt(box, {
  H = 0, parent = box, make, fill, mark = () => {},
  gap = () => document.createElement('div'),       // 上下の空白を作る（表なら <tr><td colspan>）
  gapH = (el, px) => { el.style.height = px },     // 空白の高さを付ける
  stick = () => 0,                                 // 上に貼りつく見出しの高さ（to で隠れないように）
  id = '', owner = box, pad = 3, onScroll,
} = {}) {
  const cs = getComputedStyle(box), view = parseFloat(cs.maxHeight) || parseFloat(cs.height) || 300;
  const top = gap(), bot = gap(), pool = [];
  for (const g of [top, bot]) { g.classList.add('v-gap'); g.setAttribute('aria-hidden', 'true') }
  parent.append(top, bot);
  let n = 0, f = 0, act = -1, raf = 0;
  const h = () => H || 24;
  const offset = () => top.getBoundingClientRect().top - box.getBoundingClientRect().top + box.scrollTop;  // 箱の上端から行の始まりまで（見出しや余白）
  const setGap = (el, px) => { const v = px + 'px'; if (el._h !== v) { gapH(el, v); el._h = v } };
  function draw() {
    const rows = Math.ceil(view / h()) + pad * 2, m = Math.min(rows, n);
    while (pool.length < m) { const r = make(); r._i = -1; parent.insertBefore(r, bot); pool.push(r) }  // 要る数まで作り足す
    while (pool.length > m) pool.pop().remove();                                                          // 減ったら外す
    f = Math.max(0, Math.min(n - m, Math.floor((box.scrollTop - offset()) / h()) - pad));
    setGap(top, f * h()); setGap(bot, (n - f - m) * h());
    for (let k = 0; k < m; k++) {
      const r = pool[k], i = f + k;
      if (r._i !== i) { fill(r, i); r._i = i; if (id) r.id = id + i }
      mark(r, i);
    }
    if (!H && pool[0]) { const mh = pool[0].getBoundingClientRect().height; if (mh) { H = mh; draw(); return } }  // 行の高さを 1 度だけ測る
    if (id) { const r = row(act); r ? owner.setAttribute('aria-activedescendant', r.id) : owner.removeAttribute('aria-activedescendant') }
  }
  const row = i => (i >= f && i < f + pool.length && pool[i - f]._i === i ? pool[i - f] : null);
  box.addEventListener('scroll', () => { if (onScroll) onScroll(); if (!raf) raf = requestAnimationFrame(() => { raf = 0; draw() }) }, { passive: true });
  return {
    draw, row,
    get size() { return n },
    /** いま作っている行の要素の数 */
    get count() { return pool.length },
    /** 数か中身が変わったとき。dirty を false にすると、番号が変わった行だけ書き直す */
    set(count, dirty = true) { n = count; if (dirty) pool.forEach(r => { r._i = -1 }); draw() },
    /** i 番目の行だけ書き直す（見えていなければ何もしない） */
    refill(i) { const r = row(i); if (r) { fill(r, i); mark(r, i) } },
    /** i 番目の行の印だけ付け直す */
    mark(i) { const r = row(i); if (r) mark(r, i) },
    /** i 番目の行が窓に入るようにスクロールする（描いていない行でも番号から位置が分かる） */
    to(i) {
      const y = offset() + i * h(), st = box.scrollTop, s = stick(), vh = box.clientHeight || view;
      if (y < st + s) box.scrollTop = y - s; else if (y + h() > st + vh) box.scrollTop = y + h() - vh;
      draw();
    },
    /** 選んでいる行を読み上げに伝える（aria-activedescendant）。id を渡したときだけ効く */
    active(i) { act = i; if (id) draw() },
    /** クリックされた要素から行の番号を引く */
    index(el) { const r = el && pool.find(p => p === el || p.contains(el)); return r ? r._i : -1 },
  };
}
