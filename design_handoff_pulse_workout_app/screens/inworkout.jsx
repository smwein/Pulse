// Pulse — In-workout (Variation B: Data-dense)

const { CoachAvatar: CAIW, ExercisePlaceholder: EPIW, Ring: RIW } = window.PulseUI;

function InWorkoutScreen({ coach, onExit }) {
  const w = window.PulseData.TODAY_WORKOUT;
  const [idx, setIdx] = useState(1);
  const [setNum, setSetNum] = useState(2);
  const [phase, setPhase] = useState("work"); // work | rest
  const [secs, setSecs] = useState(24);
  const [playing, setPlaying] = useState(true);
  const [setLog, setSetLog] = useState({
    [w.exercises[1].id]: { 1: { reps: w.exercises[1].reps, load: w.exercises[1].load || "BW", rpe: 6, done: true } }
  });
  const [hr, setHr] = useState(147);

  const ex = w.exercises[idx];
  const totalSets = parseInt(ex.sets) || 1;
  const restTime = ex.rest || 0;

  useEffect(() => {
    if (!playing) return;
    const t = setInterval(() => {
      setSecs(s => s + 1);
      setHr(h => Math.max(120, Math.min(168, h + (Math.random() * 4 - 2))));
    }, 1000);
    return () => clearInterval(t);
  }, [playing]);

  useEffect(() => {
    if (phase === "rest" && secs >= restTime && restTime > 0) {
      setPhase("work"); setSecs(0);
    }
  }, [phase, secs, restTime]);

  const fmt = (s) => `${String(Math.floor(s/60)).padStart(2,"0")}:${String(s%60).padStart(2,"0")}`;

  const logCurrentSet = () => {
    const exLog = { ...(setLog[ex.id] || {}) };
    exLog[setNum] = { reps: ex.reps, load: ex.load || "BW", rpe: 7, done: true };
    setSetLog({ ...setLog, [ex.id]: exLog });
    if (setNum < totalSets) {
      setSetNum(setNum + 1);
      setPhase("rest"); setSecs(0);
    } else {
      const next = idx + 1;
      if (next < w.exercises.length) {
        setIdx(next); setSetNum(1); setPhase("work"); setSecs(0);
      } else {
        onExit("complete");
      }
    }
  };

  // HR sparkline data — simulated
  const hrSeries = useMemo(() => {
    const out = []; let v = 130;
    for (let i = 0; i < 16; i++) { v += Math.random() * 6 - 3; out.push(v); }
    out[out.length - 1] = hr;
    return out;
  }, [hr]);
  const hrMax = Math.max(...hrSeries), hrMin = Math.min(...hrSeries);
  const hrPoints = hrSeries.map((v, i) =>
    `${(i / (hrSeries.length - 1)) * 280},${50 - ((v - hrMin) / Math.max(1, hrMax - hrMin)) * 40}`
  ).join(" ");

  const zone = hr < 130 ? { z: "Z2", h: 130, label: "Easy" }
    : hr < 150 ? { z: "Z3", h: 70, label: "Threshold" }
    : { z: "Z4", h: 25, label: "Hard" };

  const sessionElapsed = idx * 240 + setNum * 60 + secs;
  const kcal = Math.round(sessionElapsed * 0.18) + 150;

  // Sets to render in the log: previous, current, upcoming
  const sets = Array.from({ length: totalSets }, (_, i) => {
    const n = i + 1;
    const logged = setLog[ex.id]?.[n];
    return {
      n,
      done: !!logged,
      current: !logged && n === setNum,
      reps: logged?.reps ?? ex.reps,
      load: logged?.load ?? (n <= setNum ? (ex.load || "BW") : "—"),
      rpe: logged?.rpe ?? (n < setNum ? 7 : "—"),
    };
  });

  const isRest = phase === "rest";

  return (
    <div className="screen is-fullbleed" style={{ background: "var(--bg-0)", display: "flex", flexDirection: "column" }}>
      {/* Top bar */}
      <div style={{ padding: "60px 22px 0", display: "flex", alignItems: "center", gap: 10 }}>
        <button className="icon-btn" onClick={() => onExit("abort")} style={{ flexShrink: 0 }}>
          <Icon name="close" size={16}/>
        </button>
        <div style={{ flex: 1, textAlign: "center", minWidth: 0 }}>
          <div className="t-mono" style={{ fontSize: 11, color: "var(--ink-2)", letterSpacing: "0.16em" }}>SESSION {fmt(sessionElapsed)}</div>
        </div>
        <button className="icon-btn" style={{ flexShrink: 0 }}><Icon name="bell" size={16}/></button>
      </div>

      {/* Progress segments */}
      <div style={{ display: "flex", gap: 3, padding: "10px 22px 0" }}>
        {w.exercises.map((_, i) => (
          <div key={i} style={{
            flex: 1, height: 3, borderRadius: 2,
            background: i < idx ? "var(--accent)" : i === idx ? "oklch(72% 0.18 var(--accent-h) / 0.5)" : "var(--bg-3)",
          }}/>
        ))}
      </div>

      {/* Exercise card with PiP video */}
      <div style={{ padding: "14px 14px 0" }}>
        <div className="card" style={{ padding: 14 }}>
          <div style={{ display: "flex", gap: 14 }}>
            <div style={{
              width: 96, height: 96, borderRadius: 14, overflow: "hidden", flexShrink: 0,
              position: "relative",
            }}>
              <EPIW label="" h={45}/>
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", background: "oklch(0% 0 0 / 0.25)" }}>
                <Icon name={playing ? "pause" : "play"} size={18}/>
              </div>
              <div style={{
                position: "absolute", top: 6, left: 6, padding: "2px 6px", borderRadius: 999,
                background: "oklch(0% 0 0 / 0.6)", display: "flex", alignItems: "center", gap: 4,
              }}>
                <span style={{ width: 5, height: 5, borderRadius: 999, background: "var(--accent)" }} className="pulse-dot"/>
                <span className="t-mono" style={{ fontSize: 9, letterSpacing: "0.1em" }}>FORM</span>
              </div>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="t-eyebrow">Exercise {String(idx + 1).padStart(2,"0")} / {String(w.exercises.length).padStart(2,"0")}</div>
              <div style={{ fontWeight: 600, fontSize: 22, marginTop: 3, letterSpacing: "-0.02em" }}>{ex.name}</div>
              <div className="t-small" style={{ fontSize: 12 }}>{ex.focus}</div>
              <div style={{ display: "flex", gap: 6, marginTop: 10 }}>
                <span className="pill" style={{ padding: "3px 8px", fontSize: 10 }}>{ex.sets}</span>
                <span className="pill" style={{ padding: "3px 8px", fontSize: 10 }}>{ex.reps}</span>
                {ex.load && <span className="pill is-accent" style={{ padding: "3px 8px", fontSize: 10 }}>{ex.load}</span>}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Live metrics */}
      <div style={{ padding: "8px 14px 0", display: "grid", gridTemplateColumns: "1.4fr 1fr 1fr", gap: 8 }}>
        <div className="card" style={{ padding: 12 }}>
          <div className="t-eyebrow">HEART RATE</div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 2 }}>
            <span className="t-mono tick" style={{ fontSize: 26, fontWeight: 600, color: "var(--accent)" }}>{Math.round(hr)}</span>
            <span className="t-small" style={{ fontSize: 11 }}>bpm</span>
          </div>
          <svg width="100%" height="36" viewBox="0 0 280 50" style={{ marginTop: 4 }}>
            <polyline points={hrPoints} fill="none" stroke="var(--accent)" strokeWidth="1.5" strokeLinecap="round"/>
          </svg>
        </div>
        <div className="card" style={{ padding: 12 }}>
          <div className="t-eyebrow">ZONE</div>
          <div className="t-mono tick" style={{ fontSize: 24, fontWeight: 600, marginTop: 2, color: `oklch(78% 0.16 ${zone.h})` }}>{zone.z}</div>
          <div className="t-small" style={{ fontSize: 11 }}>{zone.label}</div>
        </div>
        <div className="card" style={{ padding: 12 }}>
          <div className="t-eyebrow">KCAL</div>
          <div className="t-mono tick" style={{ fontSize: 24, fontWeight: 600, marginTop: 2 }}>{kcal}</div>
          <div className="t-small" style={{ fontSize: 11 }}>burned</div>
        </div>
      </div>

      {/* Set log / rest content */}
      <div style={{ padding: "8px 14px 0", flex: 1, overflowY: "auto", scrollbarWidth: "none" }}>
        {!isRest ? (
          <>
            <div className="card" style={{ padding: 0 }}>
              <div style={{ padding: "12px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--line-soft)", gap: 8 }}>
                <div className="t-eyebrow" style={{ whiteSpace: "nowrap" }}>SET LOG</div>
                <div className="t-mono t-small" style={{ fontSize: 11, whiteSpace: "nowrap", flexShrink: 0 }}>{setNum} / {totalSets}</div>
              </div>
              {sets.map(s => (
                <div key={s.n} style={{
                  display: "grid", gridTemplateColumns: "30px 1fr 1fr 1fr 30px",
                  gap: 4, padding: "12px 16px", alignItems: "center",
                  background: s.current ? "var(--accent-soft)" : "transparent",
                  borderBottom: "1px solid var(--line-soft)",
                }}>
                  <div className="t-mono" style={{ fontSize: 13, color: s.current ? "var(--accent)" : s.done ? "var(--ink-1)" : "var(--ink-3)", fontWeight: s.current ? 600 : 400 }}>
                    {String(s.n).padStart(2, "0")}
                  </div>
                  <div className="t-mono tick" style={{ fontSize: 14, color: s.current || s.done ? "var(--ink-0)" : "var(--ink-3)" }}>
                    {s.reps}
                  </div>
                  <div className="t-mono tick" style={{ fontSize: 14, color: s.current || s.done ? "var(--ink-0)" : "var(--ink-3)" }}>
                    {s.load}
                  </div>
                  <div className="t-mono tick" style={{ fontSize: 14, color: s.current || s.done ? "var(--ink-0)" : "var(--ink-3)" }}>
                    RPE {s.rpe}
                  </div>
                  {s.done ? (
                    <div style={{ width: 22, height: 22, borderRadius: 999, background: "var(--good)", color: "oklch(20% 0.04 150)", display: "grid", placeItems: "center" }}>
                      <Icon name="check" size={12}/>
                    </div>
                  ) : s.current ? (
                    <Icon name="play" size={14} style={{ color: "var(--accent)" }}/>
                  ) : (
                    <div style={{ width: 22, height: 22, borderRadius: 999, border: "1px solid var(--line)" }}/>
                  )}
                </div>
              ))}
            </div>
            <div className="card" style={{ padding: 14, marginTop: 8, display: "flex", gap: 10, alignItems: "center" }}>
              <CAIW coach={coach} size={28}/>
              <div className="t-small" style={{ fontSize: 12, flex: 1 }}>
                {ex.videoLabel ? `”${ex.videoLabel}”` : "Brace your core. Drive through midfoot."}
              </div>
            </div>
          </>
        ) : (
          <div style={{ textAlign: "center", padding: "20px 0" }}>
            <div className="t-eyebrow" style={{ color: "var(--accent)" }}>REST</div>
            <div style={{ display: "grid", placeItems: "center", margin: "12px 0" }}>
              <RIW value={Math.min(1, secs / restTime)} size={160} stroke={5}
                label={fmt(Math.max(0, restTime - secs))} sublabel="REMAINING"/>
            </div>
            <div className="t-body" style={{ fontSize: 14 }}>
              Up next: <span style={{ color: "var(--ink-0)", fontWeight: 500 }}>set {setNum} of {totalSets}</span>
            </div>
            <button onClick={() => { setPhase("work"); setSecs(0); }}
              className="btn btn-ghost" style={{ marginTop: 14 }}>
              <Icon name="skip" size={14}/> Skip rest
            </button>
          </div>
        )}
      </div>

      {/* Controls */}
      <div style={{ padding: "10px 14px 50px", display: "flex", gap: 8 }}>
        <button className="btn btn-ghost" style={{ padding: "14px" }}
          onClick={() => { if (idx > 0) { setIdx(idx-1); setSetNum(1); setPhase("work"); setSecs(0); } }}>
          <Icon name="back" size={16}/>
        </button>
        {!isRest ? (
          <button className="btn btn-primary" style={{ flex: 1 }} onClick={logCurrentSet}>
            <Icon name="check" size={16}/> Log set {setNum}
          </button>
        ) : (
          <button className="btn btn-primary" style={{ flex: 1 }} onClick={() => { setPhase("work"); setSecs(0); }}>
            <Icon name="play" size={16}/> Start set {setNum}
          </button>
        )}
        <button className="btn btn-ghost" style={{ padding: "14px" }} onClick={() => setPlaying(!playing)}>
          <Icon name={playing ? "pause" : "play"} size={16}/>
        </button>
      </div>
    </div>
  );
}

window.InWorkoutScreen = InWorkoutScreen;
