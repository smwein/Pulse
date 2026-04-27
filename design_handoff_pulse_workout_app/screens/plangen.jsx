// Pulse — AI plan generation flow

const { TopBar: TBPlan, CoachAvatar: CAPlan, Headline: HLPlan } = window.PulseUI;

function PlanGenScreen({ coach, intensity, onDone, onBack }) {
  const [phase, setPhase] = useState(0); // 0 inputs, 1 generating, 2 done
  const [duration, setDuration] = useState(45);
  const [focus, setFocus] = useState("Lower body");
  const [vibe, setVibe] = useState("Balanced");
  const [progress, setProgress] = useState(0);
  const [logs, setLogs] = useState([]);

  useEffect(() => {
    if (phase !== 1) return;
    const steps = [
      "Reading yesterday's session...",
      "Checking HRV trend (+4 vs 7-day avg)",
      "Selecting block: Lower body strength",
      "Choosing 5 main lifts",
      "Calibrating loads to RPE 7",
      "Adding Zone 2 finisher (10 min)",
      "Locking cooldown",
    ];
    let i = 0;
    const t = setInterval(() => {
      setLogs(l => [...l, steps[i]]);
      setProgress((i + 1) / steps.length);
      i++;
      if (i >= steps.length) {
        clearInterval(t);
        setTimeout(() => setPhase(2), 600);
      }
    }, 480);
    return () => clearInterval(t);
  }, [phase]);

  return (
    <div className="screen">
      <TBPlan
        left={<button className="icon-btn" onClick={onBack}><Icon name="back" size={16}/></button>}
        title="Generate"
      />

      {phase === 0 && (
        <div className="scroll fade-in" style={{ padding: "0 24px 100px" }}>
          <div style={{ marginTop: 12 }}>
            <div className="t-eyebrow">New session</div>
            <HLPlan size={32}>
              Let{`'`}s build <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", color: "var(--accent)" }}>something</span> for today.
            </HLPlan>
          </div>

          <div style={{ marginTop: 28 }}>
            <div className="t-eyebrow" style={{ marginBottom: 10 }}>Duration</div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              {[15, 30, 45, 60].map(m => (
                <button key={m} onClick={() => setDuration(m)}
                  className="pill"
                  style={{
                    padding: "10px 16px",
                    background: duration === m ? "var(--accent)" : "var(--bg-1)",
                    color: duration === m ? "var(--accent-ink)" : "var(--ink-1)",
                    border: duration === m ? "1px solid transparent" : "1px solid var(--line)",
                  }}>
                  {m} MIN
                </button>
              ))}
            </div>
          </div>

          <div style={{ marginTop: 28 }}>
            <div className="t-eyebrow" style={{ marginBottom: 10 }}>Focus</div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              {["Lower body","Upper body","Full body","Conditioning","Mobility"].map(m => (
                <button key={m} onClick={() => setFocus(m)}
                  className="pill"
                  style={{
                    padding: "10px 16px",
                    background: focus === m ? "var(--accent)" : "var(--bg-1)",
                    color: focus === m ? "var(--accent-ink)" : "var(--ink-1)",
                    border: focus === m ? "1px solid transparent" : "1px solid var(--line)",
                  }}>
                  {m.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          <div style={{ marginTop: 28 }}>
            <div className="t-eyebrow" style={{ marginBottom: 10 }}>Vibe</div>
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              {["Easy","Balanced","Push it","All-out"].map(m => (
                <button key={m} onClick={() => setVibe(m)}
                  className="pill"
                  style={{
                    padding: "10px 16px",
                    background: vibe === m ? "var(--accent)" : "var(--bg-1)",
                    color: vibe === m ? "var(--accent-ink)" : "var(--ink-1)",
                    border: vibe === m ? "1px solid transparent" : "1px solid var(--line)",
                  }}>
                  {m.toUpperCase()}
                </button>
              ))}
            </div>
          </div>

          <div className="card" style={{ marginTop: 28, padding: 16, display: "flex", gap: 12 }}>
            <CAPlan coach={coach} size={32}/>
            <div>
              <div className="t-eyebrow" style={{ marginBottom: 4 }}>{coach.name} suggests</div>
              <div className="t-body" style={{ fontSize: 14 }}>
                Based on your last 7 days, lower body at moderate effort would round out the week well.
              </div>
            </div>
          </div>
        </div>
      )}

      {phase === 1 && (
        <div className="fade-in" style={{ padding: "30px 24px", flex: 1, display: "flex", flexDirection: "column", justifyContent: "center" }}>
          <div style={{ display: "grid", placeItems: "center", marginBottom: 30 }}>
            <div style={{ position: "relative", width: 130, height: 130 }}>
              <svg width={130} height={130} style={{ animation: "spinSlow 8s linear infinite" }}>
                <circle cx={65} cy={65} r={58} fill="none" stroke="var(--line)" strokeWidth={1} strokeDasharray="2 6"/>
              </svg>
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
                <div style={{
                  width: 70, height: 70, borderRadius: "50%", background: "var(--accent)",
                  display: "grid", placeItems: "center",
                }} className="glow pulse-dot">
                  <Icon name="spark" size={28} style={{ color: "var(--accent-ink)" }}/>
                </div>
              </div>
            </div>
          </div>
          <div style={{ textAlign: "center" }}>
            <div className="t-eyebrow">Generating</div>
            <HLPlan size={26}>{coach.name} is shaping your session</HLPlan>
          </div>
          <div style={{ marginTop: 26, padding: "0 4px" }}>
            <div style={{ height: 3, background: "var(--bg-2)", borderRadius: 999, overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${progress * 100}%`, background: "var(--accent)", transition: "width .4s var(--e-out)" }}/>
            </div>
            <div style={{ marginTop: 18, fontFamily: "var(--f-mono)", fontSize: 12, color: "var(--ink-2)", lineHeight: 1.7 }}>
              {logs.map((l, i) => (
                <div key={i} className="fade-in" style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <span style={{ color: "var(--accent)" }}>›</span>{l}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {phase === 2 && (
        <div className="scroll fade-in" style={{ padding: "0 24px 110px" }}>
          <div style={{ marginTop: 12 }}>
            <div className="t-eyebrow" style={{ color: "var(--accent)" }}>Ready</div>
            <HLPlan size={32}>
              Engine <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic" }}>Builder</span>
            </HLPlan>
            <div className="t-body" style={{ marginTop: 8 }}>{duration} min · {focus} · {vibe.toLowerCase()}</div>
          </div>

          <div style={{ marginTop: 24, display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8 }}>
            <div className="card" style={{ padding: 14, textAlign: "center" }}>
              <div className="t-mono tick" style={{ fontSize: 22, fontWeight: 600 }}>{duration}</div>
              <div className="t-eyebrow" style={{ fontSize: 9 }}>MINUTES</div>
            </div>
            <div className="card" style={{ padding: 14, textAlign: "center" }}>
              <div className="t-mono tick" style={{ fontSize: 22, fontWeight: 600 }}>{intensity}<span style={{ color: "var(--ink-3)", fontSize: 14 }}>/10</span></div>
              <div className="t-eyebrow" style={{ fontSize: 9 }}>INTENSITY</div>
            </div>
            <div className="card" style={{ padding: 14, textAlign: "center" }}>
              <div className="t-mono tick" style={{ fontSize: 22, fontWeight: 600 }}>~380</div>
              <div className="t-eyebrow" style={{ fontSize: 9 }}>KCAL</div>
            </div>
          </div>

          <div style={{ marginTop: 22 }}>
            <div className="t-eyebrow" style={{ marginBottom: 10 }}>Block summary</div>
            <div className="card">
              {window.PulseData.TODAY_WORKOUT.blocks.map((b, i) => (
                <div key={i} className="row">
                  <div style={{
                    width: 30, height: 30, borderRadius: 8, background: "var(--bg-3)",
                    display: "grid", placeItems: "center", color: "var(--accent)",
                    fontFamily: "var(--f-mono)", fontSize: 11,
                  }}>0{i+1}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontWeight: 500, fontSize: 14 }}>{b.name}</div>
                    <div className="t-small" style={{ fontSize: 12 }}>{b.exercises} exercises</div>
                  </div>
                  <div className="t-mono" style={{ color: "var(--ink-2)", fontSize: 13 }}>{b.duration}m</div>
                </div>
              ))}
            </div>
          </div>

          <div style={{ marginTop: 22, display: "flex", gap: 10 }}>
            <button className="btn btn-ghost" onClick={() => setPhase(0)} style={{ flex: 1 }}>
              Adjust
            </button>
            <button className="btn btn-primary" onClick={onDone} style={{ flex: 2 }}>
              Open workout <Icon name="arrow-right" size={15}/>
            </button>
          </div>
        </div>
      )}

      {phase === 0 && (
        <div style={{ padding: "12px 22px 22px" }}>
          <button className="btn btn-primary btn-block btn-lg" onClick={() => { setPhase(1); setLogs([]); setProgress(0); }}>
            <Icon name="spark" size={16}/> Generate workout
          </button>
        </div>
      )}
    </div>
  );
}

window.PlanGenScreen = PlanGenScreen;
