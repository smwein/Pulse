// Pulse — In-workout variations for design canvas
// Variation A: Cinematic (current direction, full-bleed video, minimal HUD)
// Variation B: Data-Dense (pro athlete dashboard, live metrics, log per set)
// Variation C: Coach-Forward (big spoken cue, simple controls)

const { CoachAvatar: CAV, ExercisePlaceholder: EPV, Ring: RV, PoseFrame: PFV } = window.PulseUI;

// Shared: status bar mock for artboard
function FakeStatusBar({ dark = true }) {
  const c = dark ? "#fff" : "#000";
  return (
    <div style={{
      height: 54, padding: "0 28px",
      display: "flex", alignItems: "center", justifyContent: "space-between",
      color: c, fontFamily: "-apple-system, system-ui, sans-serif",
      fontWeight: 600, fontSize: 17, position: "relative", zIndex: 60,
    }}>
      <span style={{ paddingTop: 18 }}>9:41</span>
      <div style={{
        position: "absolute", top: 11, left: "50%", transform: "translateX(-50%)",
        width: 126, height: 37, borderRadius: 24, background: "#000",
      }}/>
      <span style={{ paddingTop: 18, fontSize: 14, opacity: 0.8 }}>•••</span>
    </div>
  );
}

function HomeIndicator() {
  return (
    <div style={{
      position: "absolute", bottom: 0, left: 0, right: 0, zIndex: 60,
      height: 34, display: "flex", justifyContent: "center", alignItems: "flex-end",
      paddingBottom: 8, pointerEvents: "none",
    }}>
      <div style={{ width: 139, height: 5, borderRadius: 100, background: "rgba(255,255,255,0.7)" }}/>
    </div>
  );
}

function PhoneShell({ children, dark = true }) {
  return (
    <div style={{
      width: 402, height: 874, borderRadius: 48, overflow: "hidden",
      position: "relative", background: dark ? "#000" : "#F2F2F7",
      boxShadow: "0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)",
    }}>
      <div style={{ position: "absolute", inset: 0, background: "var(--bg-0)" }}>{children}</div>
      <FakeStatusBar dark={dark}/>
      <HomeIndicator/>
    </div>
  );
}

// ── Variation A: Cinematic ───────────────────────────────────────────────
function InWorkoutCinematic({ coach }) {
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", display: "flex", flexDirection: "column" }}>
      {/* fullbleed video */}
      <div style={{ position: "absolute", inset: 0 }}>
        <EPV label="" h={45}/>
        <div style={{
          position: "absolute", inset: 0,
          background: "linear-gradient(180deg, oklch(0% 0 0 / 0.8) 0%, oklch(0% 0 0 / 0.25) 35%, oklch(0% 0 0 / 0.5) 70%, oklch(8% 0.005 60) 100%)",
        }}/>
      </div>

      {/* top */}
      <div style={{ position: "relative", zIndex: 2, paddingTop: 60 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "0 22px" }}>
          <button className="icon-btn" style={{ background: "oklch(0% 0 0 / 0.4)", backdropFilter: "blur(12px)", flexShrink: 0 }}>
            <Icon name="close" size={16}/>
          </button>
          <div style={{ flex: 1, textAlign: "center", minWidth: 0 }}>
            <div className="t-h3" style={{ fontSize: 14, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>Engine Builder</div>
            <div className="t-mono" style={{ fontSize: 10, color: "var(--ink-3)", letterSpacing: "0.12em" }}>MOVE 2 OF 9</div>
          </div>
          <button className="icon-btn" style={{ background: "oklch(0% 0 0 / 0.4)", flexShrink: 0 }}><Icon name="more" size={16}/></button>
        </div>
        <div style={{ display: "flex", gap: 3, padding: "12px 22px 0" }}>
          {Array.from({ length: 9 }).map((_, i) => (
            <div key={i} style={{
              flex: 1, height: 3, borderRadius: 2,
              background: i <= 1 ? "var(--accent)" : "oklch(100% 0 0 / 0.18)",
            }}/>
          ))}
        </div>
      </div>

      {/* center body */}
      <div style={{ position: "relative", zIndex: 2, flex: 1, display: "flex", flexDirection: "column", justifyContent: "center", padding: "0 28px" }}>
        <div className="t-eyebrow" style={{ color: "oklch(100% 0 0 / 0.65)" }}>Quads · Glutes</div>
        <div style={{ marginTop: 6 }}>
          <div style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 22, color: "var(--accent)", lineHeight: 1 }}>
            Set 2 of 4
          </div>
          <div style={{ fontWeight: 600, fontSize: 38, letterSpacing: "-0.02em", lineHeight: 1.05, marginTop: 6 }}>
            Goblet Squat
          </div>
        </div>
        <div style={{ display: "flex", gap: 18, marginTop: 30 }}>
          <div>
            <div className="t-eyebrow">Reps</div>
            <div className="t-mono tick" style={{ fontSize: 32, fontWeight: 600 }}>8</div>
          </div>
          <div style={{ paddingLeft: 18, borderLeft: "1px solid oklch(100% 0 0 / 0.15)" }}>
            <div className="t-eyebrow">Load</div>
            <div className="t-mono tick" style={{ fontSize: 32, fontWeight: 600 }}>20kg</div>
          </div>
          <div style={{ paddingLeft: 18, borderLeft: "1px solid oklch(100% 0 0 / 0.15)" }}>
            <div className="t-eyebrow">Time</div>
            <div className="t-mono tick" style={{ fontSize: 32, fontWeight: 600 }}>00:24</div>
          </div>
        </div>
        <div className="t-small" style={{ marginTop: 24, fontStyle: "italic", color: "oklch(100% 0 0 / 0.6)", fontFamily: "var(--f-display)", fontSize: 17 }}>
          ”Knees track toes. Drive from midfoot.”
        </div>
      </div>

      {/* bottom controls */}
      <div style={{ position: "relative", zIndex: 2, padding: "12px 22px 50px" }}>
        <div style={{
          display: "flex", gap: 10, alignItems: "center",
          padding: "8px 12px", marginBottom: 14,
          background: "oklch(100% 0 0 / 0.08)", backdropFilter: "blur(20px)",
          borderRadius: 999, border: "1px solid oklch(100% 0 0 / 0.1)",
        }}>
          <CAV coach={coach} size={26}/>
          <div className="t-small" style={{ fontSize: 13, color: "oklch(100% 0 0 / 0.85)", flex: 1 }}>
            Brace your core. Drive through midfoot.
          </div>
        </div>
        <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
          <button className="icon-btn" style={{ background: "oklch(100% 0 0 / 0.08)" }}><Icon name="back" size={16}/></button>
          <button style={{
            flex: 1, height: 60, borderRadius: 999,
            background: "var(--accent)", color: "var(--accent-ink)",
            display: "flex", alignItems: "center", justifyContent: "center", gap: 10,
            fontWeight: 500, fontSize: 16,
          }} className="glow">
            <Icon name="pause" size={20}/> Working · 00:24
          </button>
          <button className="icon-btn" style={{ background: "oklch(100% 0 0 / 0.08)" }}><Icon name="check" size={16}/></button>
        </div>
      </div>
    </div>
  );
}

// ── Variation B: Data-Dense Dashboard ────────────────────────────────────
function InWorkoutDataDense({ coach }) {
  // simulated HR series
  const hr = [122, 124, 128, 132, 136, 140, 142, 144, 145, 144, 146, 148, 147, 145];
  const max = Math.max(...hr);
  const points = hr.map((v, i) => `${(i / (hr.length - 1)) * 280},${60 - ((v - 110) / (max - 110)) * 50}`).join(" ");

  return (
    <div style={{ position: "absolute", inset: 0, background: "var(--bg-0)", display: "flex", flexDirection: "column" }}>
      {/* top */}
      <div style={{ paddingTop: 60 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 22px" }}>
          <button className="icon-btn"><Icon name="close" size={16}/></button>
          <div style={{ textAlign: "center" }}>
            <div className="t-mono" style={{ fontSize: 11, color: "var(--ink-2)", letterSpacing: "0.16em" }}>SESSION 02:14:08</div>
          </div>
          <button className="icon-btn"><Icon name="bell" size={16}/></button>
        </div>
      </div>

      {/* PiP video + main numbers */}
      <div style={{ padding: "16px 14px 0" }}>
        <div className="card" style={{ padding: 14, position: "relative" }}>
          <div style={{ display: "flex", gap: 14 }}>
            <div style={{
              width: 96, height: 96, borderRadius: 14, overflow: "hidden", flexShrink: 0,
              position: "relative",
            }}>
              <EPV label="" h={45}/>
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", background: "oklch(0% 0 0 / 0.25)" }}>
                <Icon name="play" size={18}/>
              </div>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div className="t-eyebrow">Exercise 02 / 09</div>
              <div style={{ fontWeight: 600, fontSize: 22, marginTop: 3, letterSpacing: "-0.02em" }}>Goblet Squat</div>
              <div className="t-small" style={{ fontSize: 12 }}>Quads · Glutes</div>
              <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                <span className="pill" style={{ padding: "3px 8px", fontSize: 10 }}>RPE 7</span>
                <span className="pill" style={{ padding: "3px 8px", fontSize: 10 }}>4 × 8</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* live metrics grid */}
      <div style={{ padding: "10px 14px", display: "grid", gridTemplateColumns: "1.4fr 1fr 1fr", gap: 8 }}>
        <div className="card" style={{ padding: 12 }}>
          <div className="t-eyebrow">HEART RATE</div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 2 }}>
            <span className="t-mono tick" style={{ fontSize: 28, fontWeight: 600, color: "var(--accent)" }}>147</span>
            <span className="t-small" style={{ fontSize: 11 }}>bpm</span>
          </div>
          <svg width="100%" height="40" viewBox="0 0 280 60" style={{ marginTop: 4 }}>
            <polyline points={points} fill="none" stroke="var(--accent)" strokeWidth="1.5"/>
          </svg>
        </div>
        <div className="card" style={{ padding: 12 }}>
          <div className="t-eyebrow">ZONE</div>
          <div className="t-mono tick" style={{ fontSize: 26, fontWeight: 600, marginTop: 2, color: "oklch(78% 0.16 70)" }}>Z3</div>
          <div className="t-small" style={{ fontSize: 11 }}>Threshold</div>
        </div>
        <div className="card" style={{ padding: 12 }}>
          <div className="t-eyebrow">KCAL</div>
          <div className="t-mono tick" style={{ fontSize: 26, fontWeight: 600, marginTop: 2 }}>284</div>
          <div className="t-small" style={{ fontSize: 11 }}>burned</div>
        </div>
      </div>

      {/* set log */}
      <div style={{ padding: "8px 14px", flex: 1, overflowY: "auto" }}>
        <div className="card" style={{ padding: 0 }}>
          <div style={{ padding: "12px 16px", display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--line-soft)" }}>
            <div className="t-eyebrow">SET LOG</div>
            <div className="t-mono t-small" style={{ fontSize: 11 }}>2 / 4</div>
          </div>
          {[
            { n: 1, reps: 8, load: "20kg", rpe: 6, done: true },
            { n: 2, reps: 8, load: "20kg", rpe: 7, done: false, current: true },
            { n: 3, reps: 8, load: "—", rpe: "—", done: false },
            { n: 4, reps: 8, load: "—", rpe: "—", done: false },
          ].map(s => (
            <div key={s.n} style={{
              display: "grid", gridTemplateColumns: "30px 1fr 1fr 1fr 30px",
              gap: 4, padding: "12px 16px", alignItems: "center",
              background: s.current ? "var(--accent-soft)" : "transparent",
              borderBottom: "1px solid var(--line-soft)",
            }}>
              <div className="t-mono" style={{ fontSize: 13, color: s.current ? "var(--accent)" : "var(--ink-2)", fontWeight: s.current ? 600 : 400 }}>
                {String(s.n).padStart(2, "0")}
              </div>
              <div className="t-mono tick" style={{ fontSize: 14 }}>{s.reps}<span style={{ color: "var(--ink-3)", fontSize: 11, marginLeft: 2 }}>reps</span></div>
              <div className="t-mono tick" style={{ fontSize: 14 }}>{s.load}</div>
              <div className="t-mono tick" style={{ fontSize: 14 }}>RPE {s.rpe}</div>
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
          <CAV coach={coach} size={28}/>
          <div className="t-small" style={{ fontSize: 12, flex: 1 }}>
            HR up 8% vs last set. Keep tempo, finish strong.
          </div>
        </div>
      </div>

      {/* controls */}
      <div style={{ padding: "10px 14px 50px", display: "flex", gap: 8 }}>
        <button className="btn btn-ghost" style={{ padding: "12px 14px" }}>
          <Icon name="back" size={16}/>
        </button>
        <button className="btn btn-primary" style={{ flex: 1 }}>
          <Icon name="check" size={16}/> Log set 2
        </button>
        <button className="btn btn-ghost" style={{ padding: "12px 14px" }}>
          <Icon name="skip" size={16}/>
        </button>
      </div>
    </div>
  );
}

// ── Variation C: Coach-Forward ────────────────────────────────────────────
function InWorkoutCoachForward({ coach }) {
  return (
    <div style={{ position: "absolute", inset: 0, background: "var(--bg-1)", display: "flex", flexDirection: "column" }}>
      {/* top — minimal */}
      <div style={{ paddingTop: 60 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 22px" }}>
          <button className="icon-btn"><Icon name="close" size={16}/></button>
          <div style={{ display: "flex", gap: 3 }}>
            {Array.from({ length: 9 }).map((_, i) => (
              <div key={i} style={{ width: 14, height: 3, borderRadius: 2, background: i <= 1 ? "var(--accent)" : "var(--bg-3)" }}/>
            ))}
          </div>
          <button className="icon-btn"><Icon name="more" size={16}/></button>
        </div>
      </div>

      {/* big circular video */}
      <div style={{ padding: "20px 32px 0", display: "grid", placeItems: "center" }}>
        <div style={{
          width: 280, height: 280, borderRadius: "50%",
          overflow: "hidden", position: "relative",
          border: "1px solid var(--line)",
        }}>
          <div className="hero-img" style={{ position: "absolute", inset: 0 }}>
            <PFV/>
          </div>
          <div style={{ position: "absolute", inset: 0, background: "radial-gradient(circle, transparent 50%, oklch(0% 0 0 / 0.45) 100%)" }}/>
          <div style={{
            position: "absolute", bottom: 18, left: "50%", transform: "translateX(-50%)",
            display: "flex", alignItems: "center", gap: 6,
            padding: "6px 12px", borderRadius: 999,
            background: "oklch(0% 0 0 / 0.5)", backdropFilter: "blur(10px)",
          }}>
            <span style={{ width: 6, height: 6, borderRadius: 999, background: "var(--accent)" }} className="pulse-dot"/>
            <span className="t-mono" style={{ fontSize: 10, letterSpacing: "0.14em" }}>FORM DEMO</span>
          </div>
        </div>
      </div>

      {/* exercise + cue */}
      <div style={{ padding: "20px 32px 0", textAlign: "center" }}>
        <div className="t-eyebrow">SET 2 OF 4 · 8 REPS · 20KG</div>
        <div style={{ marginTop: 6 }}>
          <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 30 }}>Goblet</span>
          <span style={{ fontWeight: 600, fontSize: 28, marginLeft: 6 }}>Squat</span>
        </div>
      </div>

      {/* coach big quote */}
      <div style={{ padding: "20px 28px 12px", flex: 1, display: "flex", alignItems: "center" }}>
        <div style={{
          display: "flex", gap: 14, padding: "16px 18px",
          background: "var(--bg-2)", borderRadius: 22, border: "1px solid var(--line)",
          alignItems: "flex-start",
        }}>
          <CAV coach={coach} size={40}/>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow" style={{ marginBottom: 6 }}>{coach.name} · LIVE</div>
            <div style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 19, lineHeight: 1.3, color: "var(--ink-0)" }}>
              ”Take a breath. Brace your core. Slow on the way down — explode up.”
            </div>
          </div>
        </div>
      </div>

      {/* big controls */}
      <div style={{ padding: "0 22px 50px", display: "flex", flexDirection: "column", gap: 8 }}>
        <button style={{
          height: 72, borderRadius: 999,
          background: "var(--accent)", color: "var(--accent-ink)",
          display: "flex", alignItems: "center", justifyContent: "center", gap: 12,
          fontSize: 18, fontWeight: 500,
        }} className="glow">
          <Icon name="check" size={22}/> Done with set
        </button>
        <div style={{ display: "flex", gap: 8 }}>
          <button className="btn btn-ghost" style={{ flex: 1 }}>
            <Icon name="pause" size={14}/> Pause
          </button>
          <button className="btn btn-ghost" style={{ flex: 1 }}>
            <Icon name="skip" size={14}/> Skip
          </button>
          <button className="btn btn-ghost" style={{ flex: 1 }}>
            <Icon name="spark" size={14}/> Swap
          </button>
        </div>
      </div>
    </div>
  );
}

window.PulseInWorkoutVariations = { PhoneShell, InWorkoutCinematic, InWorkoutDataDense, InWorkoutCoachForward };
