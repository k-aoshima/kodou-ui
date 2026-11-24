// React で作った比較の版。TUNED=false は「よくある作り方」（MUI の Table に全行、Recharts に全点）、
// TUNED=true は「React でよく勧められる手当て」（react-window で見える行だけ、memo、グラフの点を描く幅まで間引く）
import { useEffect, useRef, useState, memo, useCallback } from 'react';
import { createRoot } from 'react-dom/client';
import { Box, Paper, Table, TableBody, TableRow, TableCell, Typography } from '@mui/material';
import { LineChart, Line, XAxis, YAxis, ResponsiveContainer } from 'recharts';
import { List, useListRef } from 'react-window';
import { SCN, row, logLine, rng, series, nextPoint, STATES } from './scenario.js';

const TUNED = globalThis.__TUNED === true;
const H = 22;
const cell = { py: 0, px: 0.75, height: H, borderBottom: 'none', fontSize: 13, whiteSpace: 'nowrap' };

function useRows() {
  const [rows, setRows] = useState(() => Array.from({ length: SCN.rows }, (_, i) => row(i)));
  useEffect(() => {
    const r = rng(11);
    const id = setInterval(() => {
      const i = Math.floor(r() * 40);
      setRows(prev => { const next = prev.slice(); next[i] = { ...prev[i], state: STATES[(STATES.indexOf(prev[i].state) + 1) % 4] }; return next });
    }, SCN.rowEveryMs);
    return () => clearInterval(id);
  }, []);
  return rows;
}

function useLog() {
  const [lines, setLines] = useState([]);
  useEffect(() => {
    let k = 0;
    const id = setInterval(() => setLines(prev => { const next = prev.length >= SCN.logCap ? prev.slice(prev.length - SCN.logCap + 1) : prev.slice(); next.push(logLine(k++)); return next }), SCN.logEveryMs);
    return () => clearInterval(id);
  }, []);
  return lines;
}

function usePoints() {
  const [pts, setPts] = useState(() => { const r = rng(7); const s = series(SCN.points, r); return { r, arr: Array.from(s, (v, i) => ({ x: i, v })), n: SCN.points } });
  useEffect(() => {
    const id = setInterval(() => setPts(p => { const v = nextPoint(p.arr[p.arr.length - 1].v, p.r); const arr = p.arr.slice(1); arr.push({ x: p.n, v }); return { r: p.r, arr, n: p.n + 1 } }), SCN.pointEveryMs);
    return () => clearInterval(id);
  }, []);
  return pts.arr;
}

const stateColor = s => s === 'run' ? '#1F5FA8' : s === 'wait' ? '#C2410C' : undefined;

/* よくある作り方: 全行を TableRow で描く */
function PlainSessions({ rows, act }) {
  const refs = useRef({});
  useEffect(() => { refs.current[act]?.scrollIntoView({ block: 'nearest' }) }, [act]);
  return (
    <Box sx={{ height: '100%', overflow: 'auto' }}>
      <Table size="small"><TableBody>
        {rows.map(d => (
          <TableRow key={d.id} selected={d.id === act} ref={el => { if (d.id === act) refs.current[act] = el }}>
            <TableCell sx={cell}>{d.hash}</TableCell><TableCell sx={cell}>{d.who}</TableCell>
            <TableCell sx={cell}>{d.msg}</TableCell><TableCell sx={{ ...cell, color: stateColor(d.state) }}>{d.state}</TableCell>
          </TableRow>
        ))}
      </TableBody></Table>
    </Box>
  );
}

/* 手当てした作り方: react-window で見える行だけ、行は memo */
const SessionRow = memo(function SessionRow({ index, style, rows, act }) {
  const d = rows[index];
  return (
    <Box style={style} sx={{ display: 'grid', gridTemplateColumns: '8ch 6ch 1fr 6ch', gap: '1ch', px: 0.75, fontSize: 13, whiteSpace: 'nowrap', overflow: 'hidden', bgcolor: index === act ? 'action.selected' : undefined }}>
      <span>{d.hash}</span><span>{d.who}</span><span>{d.msg}</span><span style={{ color: stateColor(d.state) }}>{d.state}</span>
    </Box>
  );
});
function TunedSessions({ rows, act }) {
  const ref = useListRef();
  useEffect(() => { ref.current?.scrollToRow({ index: act, align: 'smart' }) }, [act]);
  return <List listRef={ref} rowComponent={SessionRow} rowCount={rows.length} rowHeight={H} rowProps={{ rows, act }} style={{ height: '100%' }} />;
}

const lvColor = lv => lv === 'error' ? '#C2410C' : lv === 'warn' ? '#8A5A00' : undefined;
function PlainLog({ lines }) {
  const ref = useRef(null);
  useEffect(() => { if (ref.current) ref.current.scrollTop = ref.current.scrollHeight }, [lines]);
  return (
    <Box ref={ref} sx={{ height: '100%', overflow: 'auto' }}>
      {lines.map(l => (
        <Box key={l.k} sx={{ display: 'grid', gridTemplateColumns: '9ch 6ch 1fr', gap: '1ch', whiteSpace: 'nowrap', fontSize: 12 }}>
          <span>{l.t}</span><Typography component="span" sx={{ fontSize: 12, color: lvColor(l.lv) }}>{l.lv.toUpperCase()}</Typography><span>{l.m}</span>
        </Box>
      ))}
    </Box>
  );
}
const LogRow = memo(function LogRow({ index, style, lines }) {
  const l = lines[index];
  return (
    <Box style={style} sx={{ display: 'grid', gridTemplateColumns: '9ch 6ch 1fr', gap: '1ch', whiteSpace: 'nowrap', fontSize: 12 }}>
      <span>{l.t}</span><span style={{ color: lvColor(l.lv) }}>{l.lv.toUpperCase()}</span><span>{l.m}</span>
    </Box>
  );
});
function TunedLog({ lines }) {
  const ref = useListRef();
  useEffect(() => { if (lines.length) ref.current?.scrollToRow({ index: lines.length - 1, align: 'end' }) }, [lines]);
  return <List listRef={ref} rowComponent={LogRow} rowCount={lines.length} rowHeight={19} rowProps={{ lines }} style={{ height: '100%' }} />;
}

/* グラフ: よくある作り方は全点、手当ては描く幅の 1 列に最小と最大の 2 点 */
function decimate(arr, cols) {
  const n = arr.length, out = [];
  for (let c = 0; c < cols; c++) {
    const a = Math.floor(c * n / cols), b = Math.max(a + 1, Math.floor((c + 1) * n / cols)); let mn = arr[a], mx = arr[a];
    for (let i = a; i < b; i++) { if (arr[i].v < mn.v) mn = arr[i]; if (arr[i].v > mx.v) mx = arr[i] }
    if (mn.x < mx.x) out.push(mn, mx); else out.push(mx, mn);
  }
  return out;
}
function Chart({ pts }) {
  const data = TUNED ? decimate(pts, 1200) : pts;
  return (
    <ResponsiveContainer width="100%" height="100%">
      <LineChart data={data} margin={{ top: 4, right: 8, bottom: 0, left: 0 }}>
        <XAxis dataKey="x" hide /><YAxis domain={[0, 100]} width={28} />
        <Line type="linear" dataKey="v" stroke="#1F5FA8" dot={false} isAnimationActive={false} strokeWidth={1} />
      </LineChart>
    </ResponsiveContainer>
  );
}

function Panel({ title, wide, children }) {
  return (
    <Paper variant="outlined" sx={{ position: 'relative', p: '14px 8px 8px', minWidth: 0, gridColumn: wide ? '1 / -1' : undefined, borderRadius: 0 }}>
      <Typography component="span" sx={{ position: 'absolute', top: '-0.8em', left: 10, px: 0.75, bgcolor: 'background.paper', fontWeight: 600, fontSize: 13 }}>{title}</Typography>
      {children}
    </Paper>
  );
}

function App() {
  const rows = useRows(), lines = useLog(), pts = usePoints();
  const [act, setAct] = useState(0);
  window.__select = useCallback(i => setAct(i), []);
  useEffect(() => { requestAnimationFrame(() => requestAnimationFrame(() => { window.__ready = performance.now() })) }, []);
  const Sessions = TUNED ? TunedSessions : PlainSessions, Log = TUNED ? TunedLog : PlainLog;
  return (
    <Box sx={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gridTemplateRows: '420px 300px', gap: '20px', p: '24px 16px', bgcolor: '#F4F4EF', fontFamily: 'ui-monospace, monospace' }}>
      <Panel title="sessions"><Sessions rows={rows} act={act} /></Panel>
      <Panel title="log"><Log lines={lines} /></Panel>
      <Panel title="cpu" wide><Chart pts={pts} /></Panel>
    </Box>
  );
}
createRoot(document.getElementById('root')).render(<App />);
