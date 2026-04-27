// Pulse — Workout detail with video

const { TopBar: TBWD, CoachAvatar: CAWD, ExercisePlaceholder: EPWD, Headline: HLWD } = window.PulseUI;

function WorkoutDetailScreen({ coach, onStart, onBack }) {
  const w = window.PulseData.TODAY_WORKOUT;
  return (
    <div className="screen is-fullbleed">
      <div className="scroll" style={{ paddingBottom: 110 }}>
        {/* Hero video */}
        <div style={{ position: "relative", height: 360 }}>
          <EPWD label="Engine Builder · preview" h={45}/>
          <div style={{
            position: "absolute", inset: 0,
            background: "linear-gradient(180deg, oklch(15% 0.005 60 / 0.8) 0%, transparent 25%, transparent 60%, oklch(15% 0.005 60) 100%)",
          }}/>
          <div style={{ position: "absolute", top: 60, left: 14, right: 14, display: "flex", justifyContent: "space-between" }}>
            <button className="icon-btn" onClick={onBack} style={{ background: "oklch(0% 0 0 / 0.4)", backdropFilter: "blur(12px)" }}>
              <Icon name="back" size={16}/>
            </button>
            <button className="icon-btn" style={{ background: "oklch(0% 0 0 / 0.4)", backdropFilter: "blur(12px)" }}>
              <Icon name="more" size={16}/>
            </button>
          </div>
          <div style={{ position: "absolute", bottom: 24, left: 22, right: 22 }}>
            <div className="t-eyebrow" style={{ color: "oklch(100% 0 0 / 0.7)" }}>{w.type} · {w.duration} min</div>
            <div style={{ marginTop: 6 }}>
              <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 36 }}>Engine</span>
              <span style={{ fontWeight: 600, fontSize: 32, marginLeft: 8 }}>Builder</span>
            </div>
            <div className="t-body" style={{ fontSize: 14, marginTop: 4 }}>{w.subtitle}</div>
          </div>
          <div style={{ position: "absolute", left: "50%", top: "50%", transform: "translate(-50%, -50%)" }}>
            <div style={{
              width: 64, height: 64, borderRadius: 999,
              background: "oklch(100% 0 0 / 0.15)", backdropFilter: "blur(16px)",
              border: "1px solid oklch(100% 0 0 / 0.3)",
              display: "grid", placeItems: "center",
            }}>
              <Icon name="play" size={26}/>
            </div>
          </div>
        </div>

        {/* Stats row */}
        <div style={{ padding: "0 22px", marginTop: -16, position: "relative", zIndex: 2 }}>
          <div className="card" style={{ padding: 0, display: "grid", gridTemplateColumns: "repeat(4, 1fr)" }}>
            {[
              { label: "MIN", val: w.duration },
              { label: "RPE", val: `${w.intensity}/10` },
              { label: "KCAL", val: w.kcal },
              { label: "MOVES", val: w.exercises.length },
            ].map((s, i) => (
              <div key={s.label} style={{ padding: "14px 0", textAlign: "center", borderRight: i < 3 ? "1px solid var(--line-soft)" : "none" }}>
                <div className="t-mono tick" style={{ fontSize: 18, fontWeight: 600 }}>{s.val}</div>
                <div className="t-eyebrow" style={{ fontSize: 9, marginTop: 2 }}>{s.label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Coach note */}
        <div style={{ padding: "20px 22px 0" }}>
          <div className="card" style={{ padding: 16, display: "flex", gap: 12 }}>
            <CAWD coach={coach} size={32}/>
            <div>
              <div className="t-eyebrow">Why this — {coach.name}</div>
              <div className="t-body" style={{ marginTop: 6, fontSize: 14 }}>{w.why}</div>
            </div>
          </div>
        </div>

        {/* Blocks & exercises */}
        <div style={{ padding: "20px 22px" }}>
          <div className="row-end" style={{ marginBottom: 12 }}>
            <div className="t-eyebrow">The session</div>
            <div className="t-mono t-small" style={{ fontSize: 11 }}>{w.exercises.length} MOVES</div>
          </div>

          {w.blocks.map((block, bi) => {
            const blockEx = w.exercises.filter(e => e.kind === block.kind);
            return (
              <div key={block.kind} style={{ marginBottom: 18 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 10 }}>
                  <div style={{
                    fontFamily: "var(--f-mono)", fontSize: 10, color: "var(--accent)",
                    border: "1px solid var(--accent)", padding: "2px 6px", borderRadius: 4,
                  }}>
                    0{bi+1}
                  </div>
                  <div style={{ fontWeight: 500, fontSize: 14, textTransform: "capitalize" }}>{block.name}</div>
                  <div className="t-mono t-small" style={{ marginLeft: "auto", fontSize: 11 }}>{block.duration}m</div>
                </div>
                <div className="card" style={{ overflow: "hidden" }}>
                  {blockEx.map((ex, ei) => (
                    <div key={ex.id} className="row" style={{ alignItems: "stretch", padding: 0 }}>
                      <div style={{
                        width: 64, height: 64,
                        flexShrink: 0,
                        position: "relative",
                        margin: 12, borderRadius: 12, overflow: "hidden",
                      }}>
                        <EPWD label="" h={45 + ei * 12}/>
                        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", background: "oklch(0% 0 0 / 0.25)" }}>
                          <Icon name="play" size={14}/>
                        </div>
                      </div>
                      <div style={{ flex: 1, padding: "14px 14px 14px 0", display: "flex", flexDirection: "column", justifyContent: "center" }}>
                        <div style={{ fontWeight: 500, fontSize: 14 }}>{ex.name}</div>
                        <div className="t-small" style={{ marginTop: 3, fontSize: 12, display: "flex", gap: 6 }}>
                          <span>{ex.sets}</span>
                          <span style={{ color: "var(--ink-3)" }}>·</span>
                          <span className="t-mono">{ex.reps}</span>
                          {ex.load && <><span style={{ color: "var(--ink-3)" }}>·</span><span className="t-mono" style={{ color: "var(--accent)" }}>{ex.load}</span></>}
                        </div>
                      </div>
                      <div style={{ padding: "0 14px", display: "grid", placeItems: "center", color: "var(--ink-3)" }}>
                        <Icon name="chevron-right" size={16}/>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Sticky CTA */}
      <div style={{
        position: "absolute", left: 14, right: 14, bottom: 22,
        background: "oklch(20% 0.006 60 / 0.85)", backdropFilter: "blur(20px)",
        border: "1px solid var(--line)",
        borderRadius: 999, padding: 6,
        display: "flex", alignItems: "center", gap: 8, zIndex: 6,
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, paddingLeft: 12 }}>
          <Icon name="timer" size={14} style={{ color: "var(--ink-2)" }}/>
          <span className="t-mono" style={{ fontSize: 13 }}>{w.duration}:00</span>
        </div>
        <button className="btn btn-primary" style={{ flex: 1 }} onClick={onStart}>
          <Icon name="play" size={14}/> Start workout
        </button>
      </div>
    </div>
  );
}

window.WorkoutDetailScreen = WorkoutDetailScreen;
