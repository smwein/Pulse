// Pulse — Workout complete + feedback capture
// 3 steps: 1) Recap, 2) Rate & give feedback, 3) AI adaptation preview

const { TopBar: TBC, CoachAvatar: CAC, Headline: HLC, Ring: RC, ExercisePlaceholder: EPC } = window.PulseUI;

// --- Step 1: Recap ---
function RecapStep({ coach, onNext }) {
  return (
    <div className="screen fade-in is-fullbleed" style={{ background: "var(--bg-0)" }}>
      <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
        <div className="hero-img" style={{ position: "absolute", inset: 0, opacity: 0.55 }}/>
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, oklch(15% 0.005 60 / 0.2) 0%, oklch(15% 0.005 60 / 0.95) 70%)" }}/>
        <div className="grain"/>
      </div>
      <div style={{ position: "relative", zIndex: 1, height: "100%", display: "flex", flexDirection: "column" }}>
        <div style={{ padding: "60px 22px 0" }}>
          <div className="t-mono" style={{ fontSize: 11, color: "var(--accent)", letterSpacing: "0.2em" }}>● COMPLETE</div>
        </div>
        <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "flex-end", padding: "0 22px 16px" }}>
          <HLC size={52}>
            That's<br/>
            <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", color: "var(--accent)" }}>a wrap.</span>
          </HLC>
          <div className="t-body" style={{ marginTop: 12, fontSize: 15, maxWidth: 280 }}>
            42 minutes, 9 moves, 24 sets logged. Strongest effort this week.
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 6, marginTop: 22 }}>
            {[
              { l: "TIME", v: "42:18" },
              { l: "AVG HR", v: "138" },
              { l: "KCAL", v: "388" },
              { l: "VOL", v: "4.8t" },
            ].map(s => (
              <div key={s.l} className="card" style={{ padding: "10px 8px", textAlign: "center" }}>
                <div className="t-mono tick" style={{ fontSize: 16, fontWeight: 600 }}>{s.v}</div>
                <div className="t-eyebrow" style={{ fontSize: 8, marginTop: 2 }}>{s.l}</div>
              </div>
            ))}
          </div>

          <div className="card" style={{ padding: 14, marginTop: 10, display: "flex", gap: 12, alignItems: "flex-start" }}>
            <CAC coach={coach} size={32}/>
            <div style={{ flex: 1 }}>
              <div className="t-eyebrow">{coach.name}</div>
              <div className="t-body" style={{ fontSize: 13, marginTop: 4, lineHeight: 1.5 }}>
                Z3 work was clean. Quick check-in so I can dial in Wednesday's session.
              </div>
            </div>
          </div>
        </div>
        <div style={{ padding: "12px 22px 28px" }}>
          <button className="btn btn-primary btn-block btn-lg" onClick={onNext}>
            Give feedback <Icon name="forward" size={14}/>
          </button>
        </div>
      </div>
    </div>
  );
}

// --- Step 2: Rate ---
function RateStep({ coach, feedback, setFeedback, onBack, onNext }) {
  const w = window.PulseData.TODAY_WORKOUT;
  const intensityLabels = ["", "Way too easy", "A bit easy", "Just right", "Tough", "Brutal"];
  const moodOptions = [
    { id: "great", icon: "spark", label: "Crushed it" },
    { id: "good", icon: "check", label: "Solid" },
    { id: "ok", icon: "minus", label: "Going through the motions" },
    { id: "rough", icon: "alert", label: "Rough day" },
  ];
  const tagOptions = [
    { id: "loved_pace", label: "Loved the pace" },
    { id: "too_long", label: "Too long" },
    { id: "too_short", label: "Too short" },
    { id: "more_strength", label: "More strength" },
    { id: "more_cardio", label: "More cardio" },
    { id: "more_mobility", label: "More mobility" },
    { id: "fresh_moves", label: "Want fresh moves" },
    { id: "kept_form", label: "Form felt clean" },
    { id: "form_struggled", label: "Form struggled" },
    { id: "low_energy", label: "Low energy" },
    { id: "great_music", label: "Music was great" },
    { id: "boring", label: "Got boring" },
  ];

  const toggleTag = (id) => {
    const set = new Set(feedback.tags);
    set.has(id) ? set.delete(id) : set.add(id);
    setFeedback({ ...feedback, tags: [...set] });
  };

  return (
    <div className="screen fade-in" style={{ display: "flex", flexDirection: "column" }}>
      <TBC
        title={null}
        right={<div className="t-mono t-small" style={{ fontSize: 11, letterSpacing: "0.16em" }}>2 / 3</div>}
        left={<button className="icon-btn" onClick={onBack}><Icon name="back" size={16}/></button>}
      />
      <div style={{ flex: 1, overflowY: "auto", padding: "0 22px 16px", scrollbarWidth: "none" }}>
        <div className="t-eyebrow" style={{ color: "var(--accent)" }}>Quick check-in</div>
        <HLC size={32}>
          How did it<br/>
          <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic" }}>feel?</span>
        </HLC>

        {/* Overall rating: 5 stars */}
        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow">OVERALL</div>
          <div style={{ display: "flex", gap: 10, marginTop: 10, alignItems: "center" }}>
            {[1, 2, 3, 4, 5].map(n => (
              <button key={n} onClick={() => setFeedback({ ...feedback, rating: n })}
                style={{
                  width: 44, height: 44, borderRadius: 12, border: "none",
                  background: n <= feedback.rating ? "var(--accent)" : "var(--bg-2)",
                  color: n <= feedback.rating ? "oklch(20% 0.04 var(--accent-h))" : "var(--ink-2)",
                  display: "grid", placeItems: "center", cursor: "pointer",
                  transition: "all 120ms",
                }}>
                <Icon name="star" size={18}/>
              </button>
            ))}
          </div>
        </div>

        {/* Intensity slider */}
        <div style={{ marginTop: 22 }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
            <div className="t-eyebrow">INTENSITY</div>
            <div className="t-small" style={{ fontSize: 12, color: "var(--ink-1)" }}>
              {intensityLabels[feedback.intensity]}
            </div>
          </div>
          <div style={{ marginTop: 10, padding: "0 4px" }}>
            <div style={{ position: "relative", height: 36 }}>
              <div style={{
                position: "absolute", left: 0, right: 0, top: 16, height: 4,
                borderRadius: 999, background: "var(--bg-3)",
              }}/>
              <div style={{
                position: "absolute", left: 0, top: 16, height: 4,
                width: `${((feedback.intensity - 1) / 4) * 100}%`,
                borderRadius: 999, background: "var(--accent)",
              }}/>
              {[1, 2, 3, 4, 5].map(n => (
                <button key={n} onClick={() => setFeedback({ ...feedback, intensity: n })}
                  style={{
                    position: "absolute", left: `${((n - 1) / 4) * 100}%`, top: 8,
                    transform: "translateX(-50%)", width: 20, height: 20, borderRadius: 999,
                    border: "none", cursor: "pointer", padding: 0,
                    background: n === feedback.intensity ? "var(--accent)" : "var(--bg-3)",
                    boxShadow: n === feedback.intensity ? "0 0 0 4px var(--accent-soft)" : "none",
                    transition: "all 120ms",
                  }}/>
              ))}
            </div>
            <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
              <span className="t-small" style={{ fontSize: 10 }}>Easy</span>
              <span className="t-small" style={{ fontSize: 10 }}>Brutal</span>
            </div>
          </div>
        </div>

        {/* Mood */}
        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow">ENERGY</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginTop: 10 }}>
            {moodOptions.map(m => {
              const active = feedback.mood === m.id;
              return (
                <button key={m.id} onClick={() => setFeedback({ ...feedback, mood: m.id })}
                  className="card" style={{
                    padding: "12px 14px", display: "flex", gap: 10, alignItems: "center",
                    background: active ? "var(--accent-soft)" : "var(--bg-1)",
                    borderColor: active ? "var(--accent)" : "var(--line)",
                    cursor: "pointer", textAlign: "left",
                  }}>
                  <Icon name={m.icon} size={16} style={{ color: active ? "var(--accent)" : "var(--ink-1)" }}/>
                  <span style={{ fontSize: 13, color: active ? "var(--ink-0)" : "var(--ink-1)", fontWeight: active ? 500 : 400 }}>
                    {m.label}
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Per-exercise quick rate */}
        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow">PER MOVE</div>
          <div className="card" style={{ padding: 0, marginTop: 10 }}>
            {w.exercises.slice(0, 4).map((ex, i) => {
              const v = feedback.exRatings[ex.id] || null;
              return (
                <div key={ex.id} style={{
                  padding: "12px 14px", display: "flex", gap: 12, alignItems: "center",
                  borderBottom: i < 3 ? "1px solid var(--line-soft)" : "none",
                }}>
                  <div style={{ width: 36, height: 36, borderRadius: 8, overflow: "hidden", flexShrink: 0, position: "relative" }}>
                    <EPC label="" h={45}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                      {ex.name}
                    </div>
                    <div className="t-small" style={{ fontSize: 11 }}>{ex.sets} · {ex.reps}</div>
                  </div>
                  <div style={{ display: "flex", gap: 4 }}>
                    {[
                      { id: "down", icon: "thumbDown" },
                      { id: "up", icon: "thumbUp" },
                    ].map(opt => {
                      const active = v === opt.id;
                      return (
                        <button key={opt.id}
                          onClick={() => setFeedback({
                            ...feedback,
                            exRatings: { ...feedback.exRatings, [ex.id]: active ? null : opt.id },
                          })}
                          style={{
                            width: 32, height: 32, borderRadius: 8, border: "none", cursor: "pointer",
                            background: active ? (opt.id === "up" ? "oklch(72% 0.16 150 / 0.18)" : "oklch(70% 0.18 28 / 0.18)") : "var(--bg-2)",
                            color: active ? (opt.id === "up" ? "var(--good)" : "var(--bad)") : "var(--ink-2)",
                            display: "grid", placeItems: "center",
                          }}>
                          <Icon name={opt.icon} size={14}/>
                        </button>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Tags */}
        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow">QUICK TAGS</div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 10 }}>
            {tagOptions.map(t => {
              const active = feedback.tags.includes(t.id);
              return (
                <button key={t.id} onClick={() => toggleTag(t.id)}
                  className="pill" style={{
                    padding: "8px 12px", fontSize: 12, cursor: "pointer", border: "1px solid",
                    borderColor: active ? "var(--accent)" : "var(--line)",
                    background: active ? "var(--accent-soft)" : "transparent",
                    color: active ? "var(--accent)" : "var(--ink-1)",
                  }}>
                  {active ? "✓ " : ""}{t.label}
                </button>
              );
            })}
          </div>
        </div>

        {/* Note */}
        <div style={{ marginTop: 22 }}>
          <div className="t-eyebrow">A NOTE FOR {coach.name.toUpperCase()} <span style={{ color: "var(--ink-3)" }}>· optional</span></div>
          <textarea
            value={feedback.note}
            onChange={(e) => setFeedback({ ...feedback, note: e.target.value })}
            placeholder="Anything else? Soreness, life stuff, things to try…"
            style={{
              width: "100%", marginTop: 10, padding: 14, borderRadius: 14,
              background: "var(--bg-1)", border: "1px solid var(--line)",
              color: "var(--ink-0)", fontFamily: "var(--f-ui)", fontSize: 14,
              minHeight: 80, resize: "none", outline: "none",
            }}
          />
        </div>
      </div>

      <div style={{ padding: "12px 22px 28px", borderTop: "1px solid var(--line-soft)", background: "var(--bg-0)" }}>
        <button className="btn btn-primary btn-block btn-lg"
          onClick={onNext}
          disabled={!feedback.rating}
          style={{ opacity: feedback.rating ? 1 : 0.4 }}>
          Send to {coach.name} <Icon name="forward" size={14}/>
        </button>
      </div>
    </div>
  );
}

// --- Step 3: AI adaptation preview ---
function AdaptStep({ coach, feedback, onDone }) {
  const [phase, setPhase] = useState("thinking"); // thinking | result

  useEffect(() => {
    const t = setTimeout(() => setPhase("result"), 1900);
    return () => clearTimeout(t);
  }, []);

  // Derive adaptations from feedback
  const adaptations = useMemo(() => {
    const out = [];
    if (feedback.intensity >= 4) {
      out.push({ icon: "down", label: "Dialing back load 5–7%", detail: "Wednesday will start lighter to keep RPE in target." });
    } else if (feedback.intensity <= 2) {
      out.push({ icon: "up", label: "Pushing load up 5%", detail: "Adding a top set to your main lift on Wednesday." });
    } else {
      out.push({ icon: "check", label: "Holding load", detail: "You're in the sweet spot — same rep targets next time." });
    }
    if (feedback.tags.includes("too_long")) {
      out.push({ icon: "minus", label: "Shorter session", detail: "Trimming next workout by ~8 minutes." });
    }
    if (feedback.tags.includes("too_short")) {
      out.push({ icon: "plus", label: "Adding a finisher", detail: "Tacking on a 6-minute conditioning block." });
    }
    if (feedback.tags.includes("more_strength")) {
      out.push({ icon: "dumbbell", label: "More strength volume", detail: "Swapping accessory cardio for a posterior-chain block." });
    }
    if (feedback.tags.includes("more_mobility")) {
      out.push({ icon: "spark", label: "Mobility added", detail: "Inserting a 10-min hip + thoracic flow on Thursday." });
    }
    if (feedback.tags.includes("fresh_moves")) {
      out.push({ icon: "shuffle", label: "Fresh exercises", detail: "Rotating in 3 new movements you haven't seen this week." });
    }
    if (feedback.tags.includes("form_struggled")) {
      out.push({ icon: "play", label: "Tempo work", detail: "Adding a 3-1-1 tempo cue and dropping load 10%." });
    }
    if (feedback.mood === "rough" || feedback.tags.includes("low_energy")) {
      out.push({ icon: "moon", label: "Recovery prioritized", detail: "Wednesday becomes Z2 + mobility, not strength." });
    }
    const downRated = Object.entries(feedback.exRatings).filter(([, v]) => v === "down");
    if (downRated.length) {
      out.push({ icon: "shuffle", label: `Replacing ${downRated.length} move${downRated.length > 1 ? "s" : ""}`, detail: "Subbing in alternatives that hit the same muscles." });
    }
    if (out.length === 1 && feedback.rating >= 4) {
      out.push({ icon: "spark", label: "Building on this", detail: "Wednesday extends the same pattern — slightly more volume." });
    }
    return out.slice(0, 4);
  }, [feedback]);

  const summary = useMemo(() => {
    if (feedback.rating >= 4 && feedback.intensity === 3) return "You're locked in. Holding the line on volume and intensity.";
    if (feedback.intensity >= 4) return "Heard. Pulling back so we don't fry you mid-week.";
    if (feedback.intensity <= 2) return "Time to nudge the dial up. You've earned it.";
    if (feedback.mood === "rough") return "Rough days happen. Wednesday is going to be kind.";
    return "Got the signal. Wednesday is tuned to what you said.";
  }, [feedback]);

  if (phase === "thinking") {
    return (
      <div className="screen fade-in" style={{ display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", padding: "0 40px", textAlign: "center" }}>
        <div className="ring-pulse" style={{ width: 92, height: 92, borderRadius: 999, border: "1.5px solid var(--accent)", display: "grid", placeItems: "center" }}>
          <CAC coach={coach} size={56}/>
        </div>
        <div className="t-eyebrow" style={{ color: "var(--accent)", marginTop: 22 }}>{coach.name} IS THINKING</div>
        <div style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 28, marginTop: 6, letterSpacing: "-0.01em" }}>
          Tuning your plan…
        </div>
        <div className="t-mono" style={{ fontSize: 11, color: "var(--ink-2)", marginTop: 18, lineHeight: 1.7, textAlign: "left", maxWidth: 240 }}>
          <div>→ reading 1 session log</div>
          <div>→ cross-checking 7 day load</div>
          <div>→ adjusting Wed–Fri plan</div>
        </div>
      </div>
    );
  }

  return (
    <div className="screen fade-in" style={{ display: "flex", flexDirection: "column" }}>
      <TBC right={<button className="icon-btn" onClick={onDone}><Icon name="close" size={16}/></button>}/>
      <div style={{ flex: 1, overflowY: "auto", padding: "0 22px 16px", scrollbarWidth: "none" }}>
        <div className="t-eyebrow" style={{ color: "var(--accent)" }}>Plan updated</div>
        <HLC size={32}>
          Here's what<br/>
          <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic" }}>changes.</span>
        </HLC>

        <div className="card" style={{ padding: 14, marginTop: 16, display: "flex", gap: 12, alignItems: "flex-start" }}>
          <CAC coach={coach} size={32}/>
          <div style={{ flex: 1 }}>
            <div className="t-eyebrow">{coach.name}</div>
            <div className="t-body" style={{ fontSize: 14, marginTop: 4, lineHeight: 1.5 }}>{summary}</div>
          </div>
        </div>

        <div className="t-eyebrow" style={{ marginTop: 22, marginBottom: 10 }}>ADJUSTMENTS</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {adaptations.map((a, i) => (
            <div key={i} className="card" style={{ padding: 14, display: "flex", gap: 12, alignItems: "flex-start" }}>
              <div style={{
                width: 32, height: 32, borderRadius: 10, flexShrink: 0,
                background: "var(--accent-soft)", color: "var(--accent)",
                display: "grid", placeItems: "center",
              }}>
                <Icon name={a.icon} size={14}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 500 }}>{a.label}</div>
                <div className="t-small" style={{ fontSize: 12, marginTop: 2, lineHeight: 1.5 }}>{a.detail}</div>
              </div>
            </div>
          ))}
        </div>

        {/* Next session preview */}
        <div className="t-eyebrow" style={{ marginTop: 22, marginBottom: 10 }}>NEXT UP · WED</div>
        <div className="card" style={{ padding: 16 }}>
          <div className="t-eyebrow" style={{ color: "var(--accent)" }}>Mobility + Z2</div>
          <div style={{ fontWeight: 500, fontSize: 18, marginTop: 4, letterSpacing: "-0.01em" }}>
            Hip + thoracic reset
          </div>
          <div className="t-small" style={{ fontSize: 12, marginTop: 4 }}>32 min · 6 moves · low impact</div>
          <div style={{ display: "flex", gap: 6, marginTop: 12 }}>
            <span className="pill" style={{ fontSize: 10 }}>RECOVERY</span>
            <span className="pill" style={{ fontSize: 10 }}>NEW · BASED ON YOUR FEEDBACK</span>
          </div>
        </div>
      </div>

      <div style={{ padding: "12px 22px 28px", borderTop: "1px solid var(--line-soft)", display: "flex", gap: 8 }}>
        <button className="btn btn-ghost" style={{ padding: "14px 16px" }} onClick={onDone}>
          <Icon name="check" size={14}/>
        </button>
        <button className="btn btn-primary" style={{ flex: 1 }} onClick={onDone}>
          Done — see you Wednesday
        </button>
      </div>
    </div>
  );
}

// --- Wrapper ---
function CompleteScreen({ coach, onDone }) {
  const [step, setStep] = useState(0); // 0 recap, 1 rate, 2 adapt
  const [feedback, setFeedback] = useState({
    rating: 0,
    intensity: 3,
    mood: null,
    tags: [],
    exRatings: {},
    note: "",
  });

  if (step === 0) return <RecapStep coach={coach} onNext={() => setStep(1)}/>;
  if (step === 1) return <RateStep coach={coach} feedback={feedback} setFeedback={setFeedback}
    onBack={() => setStep(0)} onNext={() => setStep(2)}/>;
  return <AdaptStep coach={coach} feedback={feedback} onDone={onDone}/>;
}

window.CompleteScreen = CompleteScreen;
