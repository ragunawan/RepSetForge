import { useState, useEffect, useRef } from "react";

// ─── RepSetForge tokens (dark, v1.5 mono-throughout) ───
const T = {
  surface: "#0D0F12", raised: "#16191E", input: "#1D2127", hairline: "#262B33",
  t1: "#F2F4F7", t2: "#8B93A1", t3: "#5A6270",
  signal: "#30E585", signalDim: "rgba(48,229,133,.14)", onSignal: "#07130C",
  pr: "#F5C542", prDim: "rgba(245,197,66,.14)", warn: "#FF7A59",
  mono: "ui-monospace,'SF Mono',SFMono-Regular,Menlo,monospace",
};
const fmt = (s) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
const fmtH = (s) => `${String(Math.floor(s / 3600)).padStart(2, "0")}:${fmt(s % 3600)}`;
const e1rm = (w, r) => Math.round(w * (1 + r / 30));

const INIT = [
  { name: "Bench Press", detail: "Chest · Sternal head · Triceps", best: { w: 100, r: 8 }, oneRM: 128,
    target: "≥ 102.5 kg × 8 @ 8 RPE (+2.5%)", tw: 102.5, tr: 8, trpe: 8,
    trend: [42, 39, 38, 33, 30, 27, 22, 18, 15],
    sets: [
      { type: "W₁", w: 80, r: 10, rpe: null, rest: 90, prev: "60×10", done: false },
      { type: "1", w: 102.5, r: 8, rpe: 8, rest: 150, prev: "100×8", done: false },
      { type: "2", w: 102.5, r: 8, rpe: 8, rest: 150, prev: "100×8", done: false },
      { type: "3", w: 102.5, r: 7, rpe: null, rest: 150, prev: "100×7", done: false },
    ] },
  { name: "Incline DB Press", detail: "Chest · Clavicular head", best: { w: 34, r: 10 }, oneRM: 45,
    target: "≥ 32 kg × 10 @ 8 RPE", tw: 32, tr: 10, trpe: 8,
    trend: [40, 38, 36, 35, 32, 30, 27, 24, 22],
    sets: [
      { type: "1", w: 32, r: 10, rpe: 8, rest: 90, prev: "32×10", done: false },
      { type: "2", w: 32, r: 10, rpe: null, rest: 90, prev: "32×10", done: false },
      { type: "3", w: 32, r: 9, rpe: null, rest: 90, prev: "32×9", done: false },
    ] },
  { name: "Cable Fly", detail: "Chest · Isolation", best: { w: 22.5, r: 12 }, oneRM: 31,
    target: "≥ 20 kg × 12", tw: 20, tr: 12, trpe: null,
    trend: [38, 37, 35, 34, 33, 31, 30, 28, 27],
    sets: [
      { type: "1", w: 20, r: 12, rpe: null, rest: 60, prev: "20×12", done: false },
      { type: "2", w: 20, r: 12, rpe: null, rest: 60, prev: "20×12", done: false },
    ] },
];

const LADDER = [
  { lbl: "100 kg × 8", e: "e1RM 127", state: "done", date: "Jun 30" },
  { lbl: "100 kg × 9", e: "e1RM 130 (+2%)", state: "done", date: "Jul 5" },
  { lbl: "100 kg × 10", e: "e1RM 133 (+2%) · current", state: "cur", date: "Jul 10" },
  { lbl: "100 kg × 12", e: "e1RM 140 (+5%)", state: "todo" },
  { lbl: "102.5 kg × 8", e: "e1RM 130 (−7%) · level up", state: "todo" },
];

export default function RepSetForge() {
  const [view, setView] = useState("home"); // 'home' | 'workout'
  const [range, setRange] = useState("W"); // W | M | Y
  const [offset, setOffset] = useState(0); // periods back from current
  const dragX = useRef(null);
  const [exs, setExs] = useState(INIT);
  const [page, setPage] = useState(0);
  const [elapsed, setElapsed] = useState(2538);
  const [cumRest, setCumRest] = useState(0);
  const [rest, setRest] = useState(null); // {left,total}
  const [touched, setTouched] = useState({}); // "p-i-field" -> true (ghost cleared)
  const [sel, setSel] = useState(null); // {i, field}
  const [chartOpen, setChartOpen] = useState({});
  const [panel, setPanel] = useState(null); // 'prog' | 'index' | 'summary'
  const [prFlash, setPrFlash] = useState(null);
  const [toast, setToast] = useState(null);
  const restRef = useRef(null);

  useEffect(() => { const t = setInterval(() => setElapsed((e) => e + 1), 1000); return () => clearInterval(t); }, []);
  useEffect(() => {
    if (!rest) return;
    restRef.current = setInterval(() => {
      setRest((r) => { if (!r) return null; setCumRest((c) => c + 1); return { ...r, left: r.left - 1 }; });
    }, 1000);
    return () => clearInterval(restRef.current);
  }, [rest !== null]);

  const ex = exs[page];
  const totalSets = exs.reduce((a, e) => a + e.sets.length, 0);
  const doneSets = exs.reduce((a, e) => a + e.sets.filter((s) => s.done).length, 0);
  const vol = exs.reduce((a, e) => a + e.sets.filter((s) => s.done && s.type !== "W₁").reduce((v, s) => v + s.w * s.r, 0), 0);
  const anyDoneHere = ex.sets.some((s) => s.done);
  const expanded = chartOpen[page] ?? !anyDoneHere;
  const prs = exs.flatMap((e) => e.sets.filter((s) => s.done && s.pr).map((s) => ({ ex: e.name, w: s.w, r: s.r })));

  const key = (i, f) => `${page}-${i}-${f}`;
  const isGhost = (i, f) => !touched[key(i, f)] && !ex.sets[i].done;

  const mut = (fn) => setExs((prev) => prev.map((e, p) => (p === page ? fn(structuredClone(e)) : e)));

  const complete = (i) => {
    const s = ex.sets[i];
    if (s.done) { mut((e) => { e.sets[i].done = false; e.sets[i].pr = false; return e; }); return; }
    const isPR = s.type !== "W₁" && (s.w > ex.best.w || (s.w === ex.best.w && s.r > ex.best.r));
    mut((e) => { e.sets[i].done = true; e.sets[i].pr = isPR; return e; });
    setTouched((t) => ({ ...t, [key(i, "w")]: true, [key(i, "r")]: true, [key(i, "rpe")]: true }));
    setRest({ left: s.rest, total: s.rest });
    setSel(null);
    if (isPR) { setPrFlash(i); setTimeout(() => setPrFlash(null), 2200); }
    if (!anyDoneHere) setChartOpen((c) => ({ ...c, [page]: false }));
  };

  const step = (d) => { if (!sel) return; const { i, field } = sel; mut((e) => {
    const s = e.sets[i];
    if (field === "w") s.w = Math.max(0, +(s.w + d * 2.5).toFixed(1));
    if (field === "r") s.r = Math.max(0, s.r + d);
    if (field === "rpe") s.rpe = Math.min(10, Math.max(5, (s.rpe ?? 7.5) + d * 0.5));
    if (field === "rest") s.rest = Math.max(0, s.rest + d * 15);
    return e; });
    setTouched((t) => ({ ...t, [key(sel.i, sel.field)]: true }));
  };

  const applyTarget = () => { mut((e) => { e.sets.forEach((s) => { if (!s.done && s.type !== "W₁") { s.w = e.tw; s.r = e.tr; if (e.trpe) s.rpe = e.trpe; } }); return e; });
    setToast("Target applied to pending sets"); setTimeout(() => setToast(null), 1800); };

  const addSet = () => mut((e) => { const last = e.sets[e.sets.length - 1];
    e.sets.push({ ...last, type: String(e.sets.filter((s) => s.type !== "W₁").length + 1), done: false, pr: false }); return e; });

  const S = { // shared styles
    label9: { font: `700 9px ${T.mono}`, letterSpacing: ".09em", color: T.t3 },
    chip: (on) => ({ font: `600 10px ${T.mono}`, padding: "3px 8px", borderRadius: 12, cursor: "pointer",
      background: on ? T.signalDim : T.input, color: on ? T.signal : T.t2, border: `1px solid ${on ? T.signal : T.hairline}` }),
    field: (i, f, w) => ({ display: "inline-block", width: w, padding: "5px 4px", textAlign: "center", cursor: "pointer",
      font: `500 13px ${T.mono}`, fontVariantNumeric: "tabular-nums", borderRadius: 8,
      background: T.input, color: isGhost(i, f) ? T.t3 : T.t1,
      border: `1px solid ${sel && sel.i === i && sel.field === f ? T.signal : T.hairline}` }),
    card: { background: T.raised, border: `1px solid ${T.hairline}`, borderRadius: 10, padding: 12, margin: "0 14px 10px" },
  };

  // ── body metrics: deterministic series so scrolling back is stable ──
  const weightAt = (daysAgo) => +(82.4 + daysAgo * 0.012 + Math.sin(daysAgo * 0.7) * 0.25 + Math.sin(daysAgo * 0.13) * 0.35).toFixed(1);
  const periodDays = range === "W" ? 7 : range === "M" ? 30 : 365;
  const points = range === "Y" ? 12 : range === "M" ? 10 : 7;
  const series = Array.from({ length: points }, (_, k) => {
    const daysAgo = offset * periodDays + Math.round(((points - 1 - k) * periodDays) / (points - 1));
    return weightAt(daysAgo);
  });
  const bfAt = (daysAgo) => +(17.8 + daysAgo * 0.006 + Math.sin(daysAgo * 0.31) * 0.3 + Math.cos(daysAgo * 0.09) * 0.4).toFixed(1);
  const bfSeries = Array.from({ length: points }, (_, k) => {
    const daysAgo = offset * periodDays + Math.round(((points - 1 - k) * periodDays) / (points - 1));
    return bfAt(daysAgo);
  });
  const delta = (arr) => +(arr[arr.length - 1] - arr[0]).toFixed(1);
  const periodLabel = (off) => {
    const d = new Date(2026, 6, 15 - off * periodDays);
    const s2 = new Date(2026, 6, 15 - off * periodDays - periodDays + 1);
    const f = (x) => x.toLocaleDateString("en-US", { month: "short", day: range === "Y" ? undefined : "numeric" }).toUpperCase();
    return range === "Y" ? `${s2.getFullYear()}` : `${f(s2)} – ${f(d)}`;
  };
  const onDragStart = (e) => { dragX.current = e.clientX ?? e.touches?.[0]?.clientX; };
  const onDragEnd = (e) => {
    if (dragX.current == null) return;
    const x = e.clientX ?? e.changedTouches?.[0]?.clientX;
    const dx = x - dragX.current; dragX.current = null;
    if (dx > 40) setOffset((o) => o + 1);          // swipe right → older
    if (dx < -40) setOffset((o) => Math.max(0, o - 1)); // swipe left → newer
  };
  const DualChart = ({ w, b }) => {
    const wMin = Math.min(...w), wMax = Math.max(...w), wSpan = wMax - wMin || 1;
    const bMin = Math.min(...b), bMax = Math.max(...b), bSpan = bMax - bMin || 1;
    const pts = (arr, min, span) => arr.map((v, i) => `${(i / (arr.length - 1)) * 100},${34 - ((v - min) / span) * 26}`).join(" ");
    const dW = delta(w), dB = delta(b);
    const ax = { font: `500 8px ${T.mono}`, fontVariantNumeric: "tabular-nums", color: T.t3, lineHeight: 1 };
    return (
      <div>
        <div style={{ display: "flex", justifyContent: "space-between", font: `500 11px ${T.mono}`, fontVariantNumeric: "tabular-nums" }}>
          <span style={{ color: T.signal }}>WEIGHT <b style={{ fontWeight: 600 }}>{w[w.length - 1]} kg</b> <span style={{ color: dW < 0 ? T.signal : T.t3 }}>({dW > 0 ? "+" : ""}{dW})</span></span>
          <span style={{ color: T.t2 }}>BODY FAT <b style={{ fontWeight: 600, color: T.t1 }}>{b[b.length - 1]}%</b> <span style={{ color: T.t3 }}>({dB > 0 ? "+" : ""}{dB})</span></span>
        </div>
        <div style={{ display: "flex", alignItems: "stretch", gap: 4, marginTop: 6 }}>
          {/* left axis: weight */}
          <div style={{ display: "flex", flexDirection: "column", justifyContent: "space-between", textAlign: "right", ...ax, color: T.signal }}>
            <span>{wMax.toFixed(1)}</span><span>{wMin.toFixed(1)}</span></div>
          <svg viewBox="0 0 100 40" preserveAspectRatio="none" style={{ flex: 1, height: 64, display: "block", borderLeft: `1px solid ${T.hairline}`, borderRight: `1px solid ${T.hairline}`, borderBottom: `1px solid ${T.hairline}` }}>
            <polyline points={pts(w, wMin, wSpan)} fill="none" stroke={T.signal} strokeWidth="1.8" />
            <polyline points={pts(b, bMin, bSpan)} fill="none" stroke={T.t2} strokeWidth="1.4" strokeDasharray="3,2" />
          </svg>
          {/* right axis: body fat % */}
          <div style={{ display: "flex", flexDirection: "column", justifyContent: "space-between", ...ax }}>
            <span>{bMax.toFixed(1)}</span><span>{bMin.toFixed(1)}</span></div>
        </div>
        <div style={{ display: "flex", gap: 12, marginTop: 5, font: `500 9px ${T.mono}`, color: T.t3 }}>
          <span><span style={{ color: T.signal }}>—</span> WEIGHT (LEFT)</span>
          <span><span style={{ color: T.t2 }}>- -</span> BODY FAT % (RIGHT)</span>
        </div>
      </div>
    );
  };

  // ─────────────── HOME ───────────────
  if (view === "home") {
    const wkVol = [44, 52, 38, 58, 62, 55, 70, 88];
    return (
      <div style={{ minHeight: "100vh", background: "#07080A", display: "flex", alignItems: "center", justifyContent: "center", padding: 20, fontFamily: T.mono }}>
        <div style={{ width: 340, height: 720, background: T.surface, borderRadius: 40, border: `1px solid ${T.hairline}`, overflow: "hidden", position: "relative", display: "flex", flexDirection: "column", color: T.t1 }}>
          <div style={{ padding: "14px 18px 8px", flexShrink: 0 }}>
            <div style={{ display: "flex", justifyContent: "space-between", font: `600 12px ${T.mono}`, color: T.t2 }}><span>9:41</span><span>69%</span></div>
            <div style={{ font: `800 24px ${T.mono}`, letterSpacing: "-.03em", marginTop: 8 }}>Home</div>
          </div>
          <div style={{ flex: 1, overflowY: "auto", paddingBottom: 80 }}>
            {/* resume banner */}
            <div onClick={() => setView("workout")} style={{ ...S.card, borderColor: T.signal, display: "flex", justifyContent: "space-between", alignItems: "center", cursor: "pointer" }}>
              <div>
                <div style={{ ...S.label9, color: T.signal }}>WORKOUT IN PROGRESS</div>
                <div style={{ font: `700 14px ${T.mono}`, marginTop: 3 }}>Push Day A</div>
                <div style={{ font: `500 11px ${T.mono}`, color: T.t2, fontVariantNumeric: "tabular-nums", marginTop: 2 }}>{fmtH(elapsed)} · {doneSets} sets done</div>
              </div>
              <span style={S.chip(true)}>Resume ›</span>
            </div>
            {/* week strip */}
            <div style={S.card}>
              <div style={{ display: "flex", justifyContent: "space-between" }}><span style={S.label9}>THIS WEEK</span>
                <span style={{ font: `600 10px ${T.mono}`, color: T.signal }}>7 WK STREAK</span></div>
              <div style={{ display: "flex", justifyContent: "space-between", textAlign: "center", marginTop: 8, fontVariantNumeric: "tabular-nums" }}>
                {[["3/4", "SESSIONS"], ["24.6k", "VOL KG"], ["54", "SETS"], ["2", "PRS", T.pr]].map(([v, l, c]) => (
                  <div key={l}><div style={{ font: `600 16px ${T.mono}`, color: c || T.t1 }}>{v}</div><div style={{ ...S.label9, marginTop: 2 }}>{l}</div></div>))}
              </div>
              <div style={{ display: "flex", alignItems: "flex-end", gap: 3, height: 24, marginTop: 8 }}>
                {wkVol.map((h, i) => <div key={i} style={{ flex: 1, height: `${h}%`, borderRadius: 2, background: i === wkVol.length - 1 ? T.signal : T.input }} />)}
              </div>
            </div>
            {/* next session */}
            <div style={S.card}>
              <div style={S.label9}>RECOMMENDED NEXT</div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
                <div>
                  <div style={{ font: `700 14px ${T.mono}` }}>Pull Day B</div>
                  <div style={{ font: `500 11px ${T.mono}`, color: T.t2, marginTop: 2 }}>Last done 3 days ago · back undertrained</div>
                </div>
                <span style={S.chip(true)}>Start</span>
              </div>
            </div>
            {/* body: weight + body fat %, W/M/Y, scrollable periods */}
            <div style={S.card}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <span style={S.label9}>BODY</span>
                <span style={{ display: "flex", gap: 4 }}>
                  {["W", "M", "Y"].map((r) => <span key={r} onClick={() => { setRange(r); setOffset(0); }} style={S.chip(range === r)}>{r}</span>)}
                </span>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, font: `600 10px ${T.mono}`, color: T.t3 }}>
                <span onClick={() => setOffset((o) => o + 1)} style={{ cursor: "pointer", color: T.t2 }}>‹ {periodLabel(offset + 1)}</span>
                <b style={{ color: T.t1 }}>{periodLabel(offset)}</b>
                <span onClick={() => setOffset((o) => Math.max(0, o - 1))} style={{ cursor: "pointer", opacity: offset === 0 ? 0.3 : 1, color: T.t2 }}>{offset === 0 ? "NOW" : periodLabel(offset - 1)} ›</span>
              </div>
              <div onPointerDown={onDragStart} onPointerUp={onDragEnd} onTouchStart={onDragStart} onTouchEnd={onDragEnd}
                style={{ marginTop: 8, touchAction: "pan-y", cursor: "grab" }}>
                <DualChart w={series} b={bfSeries} />
              </div>
              <div style={{ font: `500 9px ${T.mono}`, color: T.t3, marginTop: 6 }}>Swipe charts or tap arrows for previous periods</div>
            </div>
          </div>
          {/* tab bar */}
          <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: 60, background: T.raised, borderTop: `1px solid ${T.hairline}`, display: "flex", alignItems: "center", justifyContent: "space-around" }}>
            {["HOME", "HIST"].map((t, i) => <span key={t} style={{ ...S.label9, color: i === 0 ? T.t1 : T.t3 }}>{t}</span>)}
            <span onClick={() => setView("workout")} style={{ width: 44, height: 44, borderRadius: "50%", background: T.signal, color: T.onSignal, display: "flex", alignItems: "center", justifyContent: "center", font: `800 16px ${T.mono}`, marginTop: -20, cursor: "pointer", boxShadow: `0 4px 14px ${T.signalDim}` }}>▶</span>
            {["PROG", "LIB"].map((t) => <span key={t} style={{ ...S.label9 }}>{t}</span>)}
          </div>
        </div>
      </div>
    );
  }

  // ─────────────── FOCUS VIEW ───────────────

  const Field = ({ i, f, w, val }) => (
    <span style={S.field(i, f, w)} onClick={() => !ex.sets[i].done && setSel(sel?.i === i && sel?.field === f ? null : { i, field: f })}>{val}</span>
  );

  return (
    <div style={{ minHeight: "100vh", background: "#07080A", display: "flex", alignItems: "center", justifyContent: "center", padding: 20, fontFamily: T.mono }}>
      <div style={{ width: 340, height: 720, background: T.surface, borderRadius: 40, border: `1px solid ${T.hairline}`, overflow: "hidden", position: "relative", display: "flex", flexDirection: "column", color: T.t1 }}>

        {/* status + telemetry */}
        <div style={{ padding: "14px 18px 0", flexShrink: 0 }}>
          <div style={{ display: "flex", justifyContent: "space-between", font: `600 12px ${T.mono}`, color: T.t2 }}><span>9:41</span><span>69%</span></div>
          <div style={{ marginTop: 10, font: `600 11px ${T.mono}`, fontVariantNumeric: "tabular-nums", lineHeight: 1.75 }}>
            <div style={{ display: "flex", justifyContent: "space-between", color: T.t2 }}><span>SESSION:</span><b style={{ color: T.t1, fontWeight: 600 }}>{fmtH(elapsed)}</b></div>
            <div style={{ display: "flex", justifyContent: "space-between", color: T.t2 }}>
              <span>WORK: <b style={{ color: T.t1, fontWeight: 600 }}>{fmtH(Math.max(0, elapsed - cumRest))}</b></span>
              <span>REST: <b style={{ color: T.t1, fontWeight: 600 }}>{fmtH(cumRest)}</b></span>
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", color: T.t3 }}><span>{Math.round((doneSets / totalSets) * 100)}% · {(vol / 1000).toFixed(1)}k KG</span><span>SET {doneSets}/{totalSets}</span></div>
          </div>
          <div style={{ height: 4, borderRadius: 2, background: T.input, marginTop: 8, overflow: "hidden" }}>
            <div style={{ height: "100%", width: `${(doneSets / totalSets) * 100}%`, background: T.signal, transition: "width .3s" }} />
          </div>
        </div>

        {/* scroll body */}
        <div style={{ flex: 1, overflowY: "auto", paddingBottom: 140 }}>
          {/* identity */}
          <div style={{ display: "flex", gap: 10, alignItems: "center", padding: "12px 18px 10px" }}>
            <div style={{ width: 42, height: 42, borderRadius: 10, background: T.input, border: `1px solid ${T.hairline}`, display: "flex", alignItems: "center", justifyContent: "center", font: `700 12px ${T.mono}`, color: T.t2 }}>
              {ex.name.split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase()}</div>
            <div style={{ flex: 1 }}>
              <div style={{ font: `800 16px ${T.mono}`, letterSpacing: "-.02em" }}>{ex.name}</div>
              <div style={{ font: `500 11px ${T.mono}`, color: T.t2, marginTop: 2 }}>{ex.detail}</div>
            </div>
          </div>
          <div style={{ height: 1, background: T.hairline }} />

          {/* chart — expanded / collapsed */}
          {expanded ? (
            <div style={{ padding: "8px 12px 4px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", padding: "0 4px" }}>
                <span style={S.chip(true)}>Weight × Reps</span>
                <span style={{ display: "flex", gap: 5 }}><span style={S.chip(false)}>3M</span><span style={S.chip(false)}>%1RM</span></span>
              </div>
              <div style={{ height: 110, position: "relative", marginTop: 8 }}>
                <span style={{ position: "absolute", top: 8, left: 4, font: `600 9px ${T.mono}`, color: T.warn }}>— 75% · {Math.round(ex.oneRM * 0.75)} kg</span>
                <svg viewBox="0 0 100 50" preserveAspectRatio="none" style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
                  <line x1="0" y1="10" x2="100" y2="10" stroke={T.warn} strokeWidth="0.5" strokeDasharray="2,2" />
                  {ex.trend.map((v, i) => <rect key={i} x={4 + i * 10.6} y={v + 4} width="6" height={46 - v} fill={T.input} />)}
                  <polyline points={ex.trend.map((v, i) => `${7 + i * 10.6},${v}`).join(" ")} fill="none" stroke={T.signal} strokeWidth="1.6" />
                </svg>
              </div>
              <div style={{ display: "flex", gap: 6, marginTop: 6, padding: "0 4px 8px" }}>
                <span style={S.chip(false)}>1RM {ex.oneRM} kg</span>
                <span style={{ ...S.chip(false), color: T.pr, borderColor: T.pr, background: T.prDim }}>PR {ex.best.w}×{ex.best.r}</span>
              </div>
            </div>
          ) : (
            <div onClick={() => setChartOpen((c) => ({ ...c, [page]: true }))}
              style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "9px 18px", cursor: "pointer" }}>
              <span style={S.label9}>CHART</span>
              <span style={{ font: `500 11px ${T.mono}`, color: T.t2, fontVariantNumeric: "tabular-nums" }}>1RM {ex.oneRM} · <span style={{ color: T.pr }}>PR {ex.best.w}×{ex.best.r}</span> ▾</span>
            </div>
          )}
          <div style={{ height: 1, background: T.hairline }} />

          {/* coaching prompt */}
          <div onClick={applyTarget} style={{ background: T.signalDim, borderTop: `1px solid ${T.signal}`, borderBottom: `1px solid ${T.signal}`, padding: "8px 18px", cursor: "pointer" }}>
            <span style={{ font: `500 11px ${T.mono}`, color: T.t1 }}>↑ Same as last session — tap to apply</span>
            <div style={{ font: `600 11px ${T.mono}`, color: T.signal, marginTop: 2 }}>Target: {ex.target}</div>
          </div>

          {/* set table */}
          <table style={{ width: "100%", borderCollapse: "collapse", padding: "0 6px" }}>
            <thead><tr>{["#", "WEIGHT", "REPS", "RPE", "REST", "✓"].map((h, i) => (
              <th key={h} style={{ ...S.label9, padding: "8px 2px 4px", textAlign: i >= 1 && i <= 4 ? "left" : "center", paddingLeft: i === 1 ? 6 : undefined }}>{h}</th>))}</tr></thead>
            <tbody>
              {ex.sets.map((s, i) => (
                <tr key={i} style={{ opacity: s.done ? 0.55 : 1, background: prFlash === i ? T.prDim : "transparent", transition: "background .4s" }}>
                  <td style={{ textAlign: "center", font: `700 11px ${T.mono}`, color: s.type === "W₁" ? T.pr : T.t2, width: 34 }}>{s.type}</td>
                  <td style={{ padding: "4px 2px 4px 6px" }}><Field i={i} f="w" w={58} val={s.w} /></td>
                  <td style={{ padding: "4px 2px" }}><Field i={i} f="r" w={38} val={s.r} /></td>
                  <td style={{ padding: "4px 2px" }}><Field i={i} f="rpe" w={38} val={s.rpe ?? "—"} /></td>
                  <td style={{ padding: "4px 2px" }}><Field i={i} f="rest" w={48} val={fmt(s.rest)} /></td>
                  <td style={{ textAlign: "center", width: 44 }}>
                    <span onClick={() => complete(i)} style={{ display: "inline-flex", width: 26, height: 26, borderRadius: 8, alignItems: "center", justifyContent: "center", cursor: "pointer", font: `700 13px ${T.mono}`,
                      background: s.done ? T.signal : "transparent", color: s.done ? T.onSignal : T.t3,
                      border: `1.5px solid ${s.done ? T.signal : T.hairline}`, transition: "transform .25s cubic-bezier(.34,1.56,.64,1)", transform: s.done ? "scale(1)" : "scale(.95)" }}>
                      {s.done ? "✓" : "○"}</span>
                    {s.pr && <div style={{ font: `800 8px ${T.mono}`, color: T.pr, marginTop: 2 }}>PR</div>}
                  </td>
                </tr>))}
            </tbody>
          </table>
          <div onClick={addSet} style={{ font: `600 12px ${T.mono}`, color: T.t2, padding: "8px 18px", cursor: "pointer" }}>+ Add set</div>
          <div onClick={() => setPanel("summary")} style={{ margin: "6px 18px", padding: 12, textAlign: "center", borderRadius: 12, background: T.input, border: `1px solid ${T.hairline}`, font: `700 13px ${T.mono}`, cursor: "pointer" }}>Finish workout</div>
        </div>

        {/* stepper (appears when a field is selected) */}
        {sel && (
          <div style={{ position: "absolute", bottom: 128, left: 14, right: 14, background: T.raised, border: `1px solid ${T.hairline}`, borderRadius: 16, padding: "10px 14px", display: "flex", alignItems: "center", justifyContent: "space-between", boxShadow: "0 6px 20px rgba(0,0,0,.45)" }}>
            <span style={S.label9}>{sel.field.toUpperCase()} · SET {ex.sets[sel.i].type}</span>
            <span style={{ display: "flex", gap: 8, alignItems: "center" }}>
              <span onClick={() => step(-1)} style={{ ...S.chip(false), padding: "6px 14px", fontSize: 13 }}>−</span>
              <b style={{ font: `600 16px ${T.mono}`, fontVariantNumeric: "tabular-nums", minWidth: 52, textAlign: "center" }}>
                {sel.field === "rest" ? fmt(ex.sets[sel.i].rest) : sel.field === "rpe" ? ex.sets[sel.i].rpe ?? "—" : ex.sets[sel.i][sel.field]}</b>
              <span onClick={() => step(1)} style={{ ...S.chip(true), padding: "6px 14px", fontSize: 13 }}>+</span>
              <span onClick={() => setSel(null)} style={{ color: T.t3, marginLeft: 4, cursor: "pointer" }}>✕</span>
            </span>
          </div>
        )}

        {/* toast */}
        {toast && <div style={{ position: "absolute", bottom: 128, left: 14, right: 14, background: T.raised, border: `1px solid ${T.signal}`, borderRadius: 12, padding: "9px 14px", font: `600 12px ${T.mono}` }}>✓ {toast}</div>}

        {/* bottom pill: rest countdown OR pager */}
        <div style={{ position: "absolute", bottom: 14, left: 12, right: 12, background: T.raised, border: `1px solid ${rest && rest.left < 0 ? T.warn : T.hairline}`, borderRadius: 24, padding: "10px 14px", display: "flex", alignItems: "center", gap: 10, boxShadow: "0 6px 20px rgba(0,0,0,.5)" }}>
          {rest ? (<>
            <b style={{ font: `700 14px ${T.mono}`, fontVariantNumeric: "tabular-nums", color: rest.left < 0 ? T.warn : T.signal, minWidth: 48 }}>{rest.left < 0 ? "+" + fmt(-rest.left) : fmt(rest.left)}</b>
            <div style={{ flex: 1, height: 5, borderRadius: 3, background: T.input, overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${Math.min(100, ((rest.total - rest.left) / rest.total) * 100)}%`, background: rest.left < 0 ? T.warn : T.signal, transition: "width 1s linear" }} /></div>
            <span onClick={() => setRest((r) => ({ ...r, left: r.left + 30, total: r.total + 30 }))} style={S.chip(false)}>+30s</span>
            <span onClick={() => setRest(null)} style={{ font: `600 11px ${T.mono}`, color: T.t3, cursor: "pointer" }}>Skip</span>
          </>) : (<>
            <span onClick={() => setView("home")} style={{ color: T.t3, cursor: "pointer", font: `600 13px ${T.mono}` }}>⌄</span>
            <span onClick={() => setPanel("index")} style={{ color: T.t3, cursor: "pointer", font: `600 13px ${T.mono}` }}>☰</span>
            <span onClick={() => setPanel("prog")} style={S.chip(false)}>PROG</span>
            <div style={{ flex: 1, display: "flex", justifyContent: "center", gap: 16, alignItems: "center" }}>
              <span onClick={() => { setPage((p) => Math.max(0, p - 1)); setSel(null); }} style={{ color: page > 0 ? T.t1 : T.t3, cursor: "pointer" }}>‹</span>
              <span onClick={() => setPanel("index")} style={{ font: `600 12px ${T.mono}`, color: T.t2, cursor: "pointer" }}>{page + 1} / {exs.length}</span>
              <span onClick={() => { setPage((p) => Math.min(exs.length - 1, p + 1)); setSel(null); }} style={{ color: page < exs.length - 1 ? T.t1 : T.t3, cursor: "pointer" }}>›</span>
            </div>
            <span style={{ color: T.t3 }}>↗</span>
          </>)}
        </div>

        {/* ── sheets ── */}
        {panel && (
          <div style={{ position: "absolute", inset: 0, background: "rgba(0,0,0,.55)", display: "flex", alignItems: "flex-end" }} onClick={() => setPanel(null)}>
            <div onClick={(e) => e.stopPropagation()} style={{ width: "100%", maxHeight: "86%", overflowY: "auto", background: T.surface, borderTop: `1px solid ${T.hairline}`, borderRadius: "22px 22px 0 0", padding: "14px 0 24px" }}>
              <div style={{ width: 36, height: 4, borderRadius: 2, background: T.hairline, margin: "0 auto 12px" }} />

              {panel === "index" && (<div style={{ padding: "0 18px" }}>
                <div style={{ ...S.label9, marginBottom: 8 }}>EXERCISE INDEX · READ-ONLY</div>
                {exs.map((e, p) => { const d = e.sets.filter((s) => s.done).length; return (
                  <div key={p} onClick={() => { setPage(p); setPanel(null); setSel(null); }} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "10px 0", borderBottom: `1px solid ${T.hairline}`, cursor: "pointer" }}>
                    <div><div style={{ font: `700 13px ${T.mono}`, color: p === page ? T.signal : T.t1 }}>{e.name}</div>
                      <div style={{ font: `500 11px ${T.mono}`, color: T.t2, fontVariantNumeric: "tabular-nums" }}>{d}/{e.sets.length} sets{e.sets.some((s) => s.pr) ? " · PR" : ""}</div></div>
                    <span style={{ color: T.t3 }}>≡</span></div>); })}
              </div>)}

              {panel === "prog" && (<div>
                <div style={{ ...S.label9, padding: "0 18px 6px" }}>PROGRESSION RULE · DOUBLE PROGRESSION</div>
                {[["Rep range", "8 – 12"], ["RPE", "≤ 9"], ["Sets per session", "≥ 2"], ["Weight increment", "+2.5 kg"]].map(([l, v]) => (
                  <div key={l} style={{ display: "flex", justifyContent: "space-between", padding: "9px 18px", borderBottom: `1px solid ${T.hairline}`, font: `500 12px ${T.mono}` }}>
                    <span style={{ color: T.t2 }}>{l}</span><b style={{ fontVariantNumeric: "tabular-nums", fontWeight: 600 }}>{v} ▸</b></div>))}
                <div style={{ ...S.label9, padding: "14px 18px 6px" }}>LADDER</div>
                {LADDER.map((l, i) => (
                  <div key={i} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "8px 18px", opacity: l.state === "done" ? 0.55 : 1, background: l.state === "cur" ? T.signalDim : "transparent" }}>
                    <div><div style={{ font: `600 13px ${T.mono}`, fontVariantNumeric: "tabular-nums", color: l.state === "todo" ? T.t2 : T.t1 }}>{l.lbl}</div>
                      <div style={{ font: `500 10px ${T.mono}`, color: l.state === "todo" ? T.t3 : T.signal }}>{l.e}</div></div>
                    <div style={{ textAlign: "right" }}>
                      {[0, 1].map((n) => <span key={n} style={{ display: "inline-flex", width: 16, height: 16, borderRadius: 5, margin: "0 0 0 4px", alignItems: "center", justifyContent: "center", font: `700 9px ${T.mono}`,
                        background: l.state !== "todo" && (l.state === "done" || n === 0) ? T.signal : "transparent", color: T.onSignal,
                        border: `1px solid ${l.state !== "todo" && (l.state === "done" || n === 0) ? T.signal : T.hairline}` }}>{l.state !== "todo" && (l.state === "done" || n === 0) ? "✓" : ""}</span>)}
                      {l.date && <div style={{ font: `500 9px ${T.mono}`, color: T.t3, marginTop: 2 }}>{l.date}</div>}</div>
                  </div>))}
              </div>)}

              {panel === "summary" && (<div style={{ padding: "0 18px" }}>
                <div style={{ font: `800 18px ${T.mono}`, letterSpacing: "-.02em" }}>Workout done</div>
                <div style={{ display: "flex", justifyContent: "space-between", textAlign: "center", margin: "14px 0", fontVariantNumeric: "tabular-nums" }}>
                  {[[fmtH(elapsed).slice(0, 5), "DURATION"], [doneSets, "SETS"], [exs.reduce((a, e) => a + e.sets.filter((s) => s.done).reduce((r, s) => r + s.r, 0), 0), "REPS"], [(vol / 1000).toFixed(1) + "k", "VOL KG"]].map(([v, l]) => (
                    <div key={l}><div style={{ font: `600 17px ${T.mono}` }}>{v}</div><div style={{ ...S.label9, marginTop: 2 }}>{l}</div></div>))}
                </div>
                {prs.length > 0 && (<div style={{ background: T.prDim, border: `1px solid ${T.pr}`, borderRadius: 10, padding: "10px 12px", marginBottom: 10 }}>
                  <div style={{ ...S.label9, color: T.pr }}>{prs.length} PERSONAL RECORD{prs.length > 1 ? "S" : ""}</div>
                  {prs.map((p, i) => <div key={i} style={{ display: "flex", justifyContent: "space-between", font: `600 13px ${T.mono}`, marginTop: 6, fontVariantNumeric: "tabular-nums" }}><span>{p.ex}</span><span style={{ color: T.pr }}>{p.w} × {p.r}</span></div>)}
                </div>)}
                <div style={{ font: `500 12px ${T.mono}`, color: T.t2, padding: "8px 0", borderTop: `1px solid ${T.hairline}` }}>✓ Saved to Apple Health · visible in Fitness</div>
                <div onClick={() => setPanel(null)} style={{ marginTop: 8, padding: 13, textAlign: "center", borderRadius: 12, background: T.signal, color: T.onSignal, font: `700 14px ${T.mono}`, cursor: "pointer" }}>Done</div>
              </div>)}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
