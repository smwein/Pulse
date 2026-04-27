// Pulse — Home screen

const { TopBar, CoachAvatar, Ring, WorkoutTypeChip, Sparkline, ExercisePlaceholder, Headline } = window.PulseUI;

function HomeScreen({ coach, onOpenWorkout, onOpenChat, onOpenPlan, intensity }) {
  const w = window.PulseData.TODAY_WORKOUT;
  const stats = window.PulseData.STATS;
  const week = window.PulseData.WEEK;

  const greeting = (() => {
    const h = new Date().getHours();
    if (h < 5) return "Late night";
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  })();

  return (
    <div className="screen fade-in">
      <TopBar
        left={<CoachAvatar coach={coach} size={36} />}
        right={
          <button className="icon-btn" onClick={onOpenChat} aria-label="Coach">
            <Icon name="spark" size={18} />
          </button>
        }
      />

      <div className="scroll" style={{ paddingBottom: 110 }}>
        <div style={{ padding: "4px 22px 18px" }} className="stagger">
          <div className="t-eyebrow" style={{ marginBottom: 6 }}>Tuesday · Apr 22</div>
          <Headline size={34}>
            {greeting}, Alex.<br/>
            <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontWeight: 400, color: "var(--ink-2)" }}>
              ready when you are.
            </span>
          </Headline>
        </div>

        {/* Hero card — today's workout */}
        <div style={{ padding: "0 14px" }}>
          <button
            onClick={onOpenWorkout}
            style={{
              display: "block", width: "100%", textAlign: "left",
              borderRadius: "var(--r-xl)",
              overflow: "hidden",
              border: "1px solid var(--line)",
              background: "var(--bg-1)",
              position: "relative",
            }}
            className="slide-up"
          >
            <div style={{ position: "relative", height: 240 }}>
              <ExercisePlaceholder label="Today · 04:42 generated" h={45} />
              <div style={{
                position: "absolute", inset: 0,
                background: "linear-gradient(180deg, transparent 40%, oklch(15% 0.005 60 / 0.85) 100%)",
              }}/>
              <div style={{ position: "absolute", top: 14, left: 14, display: "flex", gap: 6 }}>
                <span className="pill is-accent">
                  <Icon name="spark" size={11}/> AI · Today
                </span>
                <span className="pill"><Icon name="timer" size={11}/> {w.duration} min</span>
              </div>
              <div style={{ position: "absolute", bottom: 14, right: 14 }}>
                <div style={{
                  width: 56, height: 56, borderRadius: 999, background: "var(--accent)",
                  color: "var(--accent-ink)", display: "grid", placeItems: "center",
                }} className="glow">
                  <Icon name="play" size={22}/>
                </div>
              </div>
            </div>
            <div style={{ padding: "18px 20px 20px" }}>
              <div className="t-eyebrow">{w.type} · Intensity {intensity}/10</div>
              <div style={{ marginTop: 4 }}>
                <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 28, lineHeight: 1, marginRight: 8 }}>{w.title.split(" ")[0]}</span>
                <span style={{ fontWeight: 600, fontSize: 24 }}>{w.title.split(" ").slice(1).join(" ")}</span>
              </div>
              <div className="t-small" style={{ marginTop: 6 }}>{w.subtitle}</div>
            </div>
          </button>
        </div>

        {/* Why this workout — coach note */}
        <div style={{ padding: "16px 14px 4px" }}>
          <div className="card" style={{ padding: 16, display: "flex", gap: 12, alignItems: "flex-start" }}>
            <CoachAvatar coach={coach} size={32}/>
            <div style={{ flex: 1 }}>
              <div className="t-eyebrow" style={{ marginBottom: 4 }}>{coach.name} · why this</div>
              <div className="t-body" style={{ fontSize: 14 }}>{w.why}</div>
              <button onClick={onOpenChat} style={{ marginTop: 10, color: "var(--accent)", fontSize: 13, display: "inline-flex", alignItems: "center", gap: 4 }}>
                Ask {coach.name} <Icon name="arrow-right" size={13}/>
              </button>
            </div>
          </div>
        </div>

        {/* Snapshot row */}
        <div style={{ padding: "20px 14px 4px" }}>
          <div className="row-end" style={{ marginBottom: 10, padding: "0 6px" }}>
            <div className="t-eyebrow">This week</div>
            <button onClick={onOpenPlan} className="t-small" style={{ color: "var(--ink-1)", display: "inline-flex", gap: 4, alignItems: "center" }}>
              View plan <Icon name="arrow-right" size={12}/>
            </button>
          </div>
          <div style={{ display: "grid", gridTemplateColumns: "1.2fr 1fr 1fr", gap: 8 }}>
            <div className="card" style={{ padding: 14, display: "flex", gap: 12, alignItems: "center" }}>
              <Ring value={stats.weeklyMinutes / stats.weeklyTarget} size={56} stroke={5} label={stats.weeklyMinutes} sublabel="min"/>
              <div>
                <div className="t-eyebrow">Goal</div>
                <div className="t-mono tick" style={{ fontSize: 14, color: "var(--ink-1)" }}>{stats.weeklyTarget} min</div>
              </div>
            </div>
            <div className="card" style={{ padding: 14 }}>
              <div className="t-eyebrow">Streak</div>
              <div style={{ display: "flex", alignItems: "baseline", gap: 4, marginTop: 4 }}>
                <Icon name="flame" size={18} style={{ color: "var(--accent)" }}/>
                <div className="t-mono tick" style={{ fontSize: 26, fontWeight: 600 }}>{stats.streak}</div>
              </div>
              <div className="t-small" style={{ fontSize: 11 }}>days</div>
            </div>
            <div className="card" style={{ padding: 14 }}>
              <div className="t-eyebrow">Load</div>
              <div style={{ marginTop: 6 }}>
                <Sparkline data={stats.recentSessions} width={80} height={26}/>
              </div>
              <div className="t-small" style={{ fontSize: 11, marginTop: 4 }}>+12% trend</div>
            </div>
          </div>
        </div>

        {/* Week strip */}
        <div style={{ padding: "20px 0 8px" }}>
          <div className="t-eyebrow" style={{ padding: "0 22px 10px" }}>Up next</div>
          <div style={{
            display: "flex", gap: 10, padding: "0 22px",
            overflowX: "auto", scrollbarWidth: "none",
          }}>
            {week.slice(2).map((d) => (
              <div key={d.day} className="card" style={{
                minWidth: 130, padding: 14, flexShrink: 0,
              }}>
                <div className="t-eyebrow" style={{ fontSize: 10 }}>{d.day} · {d.date}</div>
                <div style={{ marginTop: 8, marginBottom: 10 }}>
                  <WorkoutTypeChip type={d.type} size={28}/>
                </div>
                <div className="t-h3" style={{ fontSize: 14 }}>{d.workout}</div>
                <div className="t-small" style={{ fontSize: 11, marginTop: 4 }}>{d.duration} min</div>
              </div>
            ))}
          </div>
        </div>

        {/* Quick actions */}
        <div style={{ padding: "20px 22px 28px" }}>
          <div className="t-eyebrow" style={{ marginBottom: 10 }}>Quick start</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
            <button className="card" style={{ padding: 16, textAlign: "left" }} onClick={onOpenPlan}>
              <Icon name="spark" size={18} style={{ color: "var(--accent)" }}/>
              <div style={{ fontWeight: 500, fontSize: 14, marginTop: 8 }}>Generate workout</div>
              <div className="t-small" style={{ fontSize: 12 }}>15–60 min, your gear</div>
            </button>
            <button className="card" style={{ padding: 16, textAlign: "left" }} onClick={onOpenChat}>
              <Icon name="wave" size={18} style={{ color: "var(--accent)" }}/>
              <div style={{ fontWeight: 500, fontSize: 14, marginTop: 8 }}>Talk to {coach.name}</div>
              <div className="t-small" style={{ fontSize: 12 }}>Ask, swap, adjust</div>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

window.HomeScreen = HomeScreen;
