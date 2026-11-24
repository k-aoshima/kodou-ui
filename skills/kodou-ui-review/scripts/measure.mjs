// 画面の軽さを測る。headless Chrome で開き、要素の数・JS のヒープ・見えている間と隠れている間の忙しさを出す。
// 使い方: node measure.mjs <URL かファイル> [秒数]
//   puppeteer-core が要る。測る画面のプロジェクトで npm i -D puppeteer-core し、そのフォルダで動かす（今いるフォルダから探す）。
//   Chrome の場所は環境変数 CHROME で変えられる。
//   ページの使用メモリ（レンダラの footprint）は macOS のときだけ出す。
// 目安: 要素 3,000 以下、隠れている間の忙しさ 1% 以下。外れると終了コード 1。
import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { createRequire } from 'node:module';

let puppeteer;
try { puppeteer = (await import(pathToFileURL(createRequire(resolve('package.json')).resolve('puppeteer-core')).href)).default }
catch { console.error('puppeteer-core が見つかりません。このフォルダで npm i -D puppeteer-core を実行してください'); process.exit(2) }

const target = process.argv[2];
if (!target) { console.error('使い方: node measure.mjs <URL かファイル> [秒数]'); process.exit(2) }
const SEC = +(process.argv[3] || 10);
const url = /^[a-z]+:\/\//.test(target) ? target : pathToFileURL(resolve(target)).href;
const CHROME = process.env.CHROME || ['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium'].find(existsSync);
if (!CHROME) { console.error('Chrome が見つかりません。環境変数 CHROME に場所を入れてください'); process.exit(2) }
const sleep = ms => new Promise(r => setTimeout(r, ms));
const footprint = pid => { try { const m = execFileSync('footprint', [String(pid)], { encoding: 'utf8' }).match(/Footprint: ([\d.]+) (KB|MB|GB)/); return m ? +m[1] * { KB: 1 / 1024, MB: 1, GB: 1024 }[m[2]] : null } catch { return null } };

const browser = await puppeteer.launch({ executablePath: CHROME, headless: true });
const page = await browser.newPage(); await page.setViewport({ width: 1280, height: 800 });
const errors = []; page.on('pageerror', e => errors.push(e.message));
const cdp = await page.createCDPSession(); await cdp.send('Performance.enable');
const metric = async () => Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map(m => [m.name, m.value]));
const busy = (a, b) => (b.TaskDuration - a.TaskDuration) / SEC * 100;
await page.goto(url, { waitUntil: 'load' }); await sleep(3000);

const v0 = await metric(); await sleep(SEC * 1000); const v1 = await metric();
await cdp.send('HeapProfiler.collectGarbage'); await sleep(300);
const m = await metric();
const elements = await page.evaluate(() => document.querySelectorAll('*').length);  // 見本帳のステータスラインと同じ数え方（文字のノードは数えない）
let rendererMB = null;
if (process.platform === 'darwin') {
  const ps = (await (await browser.target().createCDPSession()).send('SystemInfo.getProcessInfo')).processInfo;
  rendererMB = ps.filter(p => p.type === 'renderer').reduce((s, p) => s + (footprint(p.id) || 0), 0) || null;
}
const other = await browser.newPage(); await other.bringToFront(); await sleep(500);
const h0 = await metric(); await sleep(SEC * 1000); const h1 = await metric();
await browser.close();

const rows = [
  ['要素の数', elements.toLocaleString(), '3,000 以下', elements <= 3000],
  ['JS のヒープ', (m.JSHeapUsedSize / 2 ** 20).toFixed(1) + ' MB', '', true],
  ['ページの使用メモリ', rendererMB == null ? '測れない' : rendererMB.toFixed(0) + ' MB', '', true],
  [`見えている間の忙しさ（${SEC} 秒）`, busy(v0, v1).toFixed(1) + '%', '', true],
  [`隠れている間の忙しさ（${SEC} 秒）`, busy(h0, h1).toFixed(1) + '%', '1% 以下', busy(h0, h1) <= 1],
  ['ページのエラー', String(errors.length), '0', errors.length === 0],
];
for (const [k, v, goal, ok] of rows) console.log(`${ok ? '  ' : '✗ '}${k}: ${v}${goal ? `（目安 ${goal}）` : ''}`);
for (const e of errors) console.log('  エラー: ' + e);
console.log('キー入力から描画までの時間は、headless では測れない。画面に出している値を読むか、人が触って確かめる。');
process.exit(rows.every(r => r[3]) ? 0 : 1);
