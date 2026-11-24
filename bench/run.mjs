// 3 つの版を headless Chrome で測る。node run.mjs [回数]
import puppeteer from 'puppeteer-core';
import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import { writeFileSync } from 'node:fs';
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const RUNS = +(process.argv[2] || 3), STREAM = 20000, HIDDEN = 10000;
const VARIANTS = ['kodou', 'react-tuned', 'react-plain'];
const sleep = ms => new Promise(r => setTimeout(r, ms));
const fp = pid => { try { const m = execFileSync('footprint', [String(pid)], { encoding: 'utf8' }).match(/Footprint: ([\d.]+) (KB|MB|GB)/); return m ? +m[1] * { KB: 1 / 1024, MB: 1, GB: 1024 }[m[2]] : null } catch { return null } };
const med = a => { const s = [...a].sort((x, y) => x - y); return s[s.length >> 1] };

async function once(name) {
  const browser = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--window-size=1280,800', '--js-flags=--expose-gc'] });
  const page = await browser.newPage(); await page.setViewport({ width: 1280, height: 800 });
  const cdp = await page.createCDPSession(); await cdp.send('Performance.enable');
  const bcdp = await browser.target().createCDPSession();
  const metric = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map(m => [m.name, m.value]));
  const gc = async () => { await cdp.send('HeapProfiler.collectGarbage'); await sleep(300) };
  const procs = async () => (await bcdp.send('SystemInfo.getProcessInfo')).processInfo;
  await page.goto(pathToFileURL(`dist/${name}.html`).href);
  await page.waitForFunction('window.__ready', { timeout: 60000 });
  const ready = await page.evaluate(() => window.__ready);
  await sleep(5000);
  // 流しているあいだの 20 秒
  await page.evaluate(() => { const iv = []; let last = performance.now(); window.__iv = iv; const f = t => { iv.push(t - last); last = t; if (window.__iv === iv) requestAnimationFrame(f) }; requestAnimationFrame(f) });
  const m0 = await metric(); await sleep(STREAM); const m1 = await metric();
  const iv = await page.evaluate(() => { const a = window.__iv; window.__iv = null; return a });
  // 選ぶ操作: 選んでから 2 コマ目の描画までの時間
  const sel = await page.evaluate(async () => { const out = []; for (let n = 0; n < 20; n++) { const i = (n * 997) % 10000; const t0 = performance.now(); window.__select(i); await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); out.push(performance.now() - t0) } return out });
  await gc(); const m2 = await metric();
  const ps = await procs(); const rend = ps.filter(p => p.type === 'renderer'), gpu = ps.filter(p => p.type === 'GPU');
  const rendMB = rend.reduce((s, p) => s + (fp(p.id) || 0), 0), gpuMB = gpu.reduce((s, p) => s + (fp(p.id) || 0), 0);
  // 隠れているあいだの 10 秒（別のタブを前に出す）
  const other = await browser.newPage(); await other.goto('about:blank'); await other.bringToFront(); await sleep(500);
  const hidden = await page.evaluate(() => document.hidden);
  const h0 = await metric(); await sleep(HIDDEN); const h1 = await metric();
  await browser.close();
  const busy = (a, b, ms) => (b.TaskDuration - a.TaskDuration) * 1000 / ms * 100;
  return {
    ready, heapMB: m2.JSHeapUsedSize / 2 ** 20, nodes: m2.Nodes, rendererMB: rendMB, gpuMB,
    busyPct: busy(m0, m1, STREAM), scriptPct: (m1.ScriptDuration - m0.ScriptDuration) * 1000 / STREAM * 100,
    layoutPerSec: (m1.LayoutCount - m0.LayoutCount) / (STREAM / 1000), styleRecalcPerSec: (m1.RecalcStyleCount - m0.RecalcStyleCount) / (STREAM / 1000),
    frameP95: med(iv.slice().sort((a, b) => a - b).slice(Math.floor(iv.length * .95))), frameMax: Math.max(...iv), longFrames: iv.filter(x => x > 50).length, frames: iv.length,
    selectMs: med(sel), hidden, hiddenBusyPct: busy(h0, h1, HIDDEN),
  };
}

const res = {};
for (let r = 0; r < RUNS; r++) for (const v of VARIANTS) { const o = await once(v); (res[v] ||= []).push(o); console.error(v, r + 1, JSON.stringify(o)) }
const keys = Object.keys(res.kodou[0]).filter(k => k !== 'hidden');
const summary = Object.fromEntries(VARIANTS.map(v => [v, Object.fromEntries(keys.map(k => [k, +med(res[v].map(o => o[k])).toFixed(2)]).concat([['hidden', res[v].every(o => o.hidden)]]))]));
const out = { date: new Date().toISOString(), chrome: execFileSync(CHROME, ['--version'], { encoding: 'utf8' }).trim(), runs: RUNS, summary, raw: res };
writeFileSync(`results-${new Date().toISOString().slice(0, 10)}.json`, JSON.stringify(out, null, 2));
console.table(summary);
