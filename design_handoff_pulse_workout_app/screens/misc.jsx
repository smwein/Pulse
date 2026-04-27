// Pulse — Calendar / Library / Stats / Profile / Chat

const { TopBar: TBM, CoachAvatar: CAM, WorkoutTypeChip: WTM, BarChart: BCM, Headline: HLM, Ring: RM } = window.PulseUI;

// ---------------- Calendar ----------------
function CalendarScreen({ coach, onOpenWorkout }) {
  const week = window.PulseData.WEEK;
  const monthDays = Array.from({ length: 30 }, (_, i) => i + 1);
  const completedDays = [4, 7, 9, 11, 14, 16, 18, 21];
  const today = 22;

  return (
    <div className="screen fade-in">
      <TBM
        left={<div><div className="t-eyebrow">April</div><div className="t-h2">Plan</div></div>}
        right={<button className="icon-btn"><Icon name="settings" size={16}/></button>}
      />
      <div className="scroll" style={{ paddingBottom: 110 }}>
        {/* Month dots */}
        <div style={{ padding: "0 22px 22px" }}>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 6 }}>
            {["M","T","W","T","F","S","S"].map((d,i) => (
              <div key={i} className="t-eyebrow" style={{ textAlign: "center", fontSize: 9 }}>{d}</div>
            ))}
            {monthDays.map(d => {
              const isDone = completedDays.includes(d);
              const isToday = d === today;
              return (
                <div key={d} style={{
                  aspectRatio: "1", display: "grid", placeItems: "center",
                  borderRadius: "50%",
                  background: isToday ? "var(--accent)" : isDone ? "var(--bg-2)" : "transparent",
                  border: isToday ? "none" : isDone ? "none" : "1px solid var(--line-soft)",
                  color: isToday ? "var(--accent-ink)" : isDone ? "var(--ink-0)" : "var(--ink-3)",
                  fontFamily: "var(--f-mono)", fontSize: 11, fontWeight: isToday ? 600 : 400,
                }}>
                  {d}
                  {isDone && !isToday && <span style={{
                    position: "absolute", marginTop: 22, width: 4, height: 4, borderRadius: 999, background: "var(--accent)"
                  }}/>}
                </div>
              );
            })}
          </div>
        </div>

        <div style={{ padding: "0 22px 12px" }}>
          <div className="t-eyebrow">This week</div>
        </div>

        <div style={{ padding: "0 14px" }}>
          {week.map((d, i) => (
            <button key={i} onClick={() => d.isToday && onOpenWorkout()}
              style={{
                width: "100%", textAlign: "left",
                display: "flex", alignItems: "center", gap: 14,
                padding: 14,
                background: d.isToday ? "var(--bg-2)" : "transparent",
                borderRadius: 16,
                border: d.isToday ? "1px solid var(--accent)" : "1px solid transparent",
                marginBottom: 4,
              }}>
              <div style={{ textAlign: "center", width: 40 }}>
                <div className="t-eyebrow" style={{ fontSize: 9 }}>{d.day}</div>
                <div className="t-mono" style={{ fontSize: 18, marginTop: 2, fontWeight: 500, color: d.isToday ? "var(--accent)" : "var(--ink-1)" }}>{d.date}</div>
              </div>
              <WTM type={d.type} size={36}/>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, fontSize: 15 }}>{d.workout}</div>
                <div className="t-small" style={{ fontSize: 12, marginTop: 2 }}>{d.type} · {d.duration} min</div>
              </div>
              {d.done ? (
                <div style={{
                  width: 28, height: 28, borderRadius: 999, background: "var(--good)",
                  color: "oklch(20% 0.04 150)", display: "grid", placeItems: "center",
                }}>
                  <Icon name="check" size={14}/>
                </div>
              ) : d.isToday ? (
                <Icon name="play" size={18} style={{ color: "var(--accent)" }}/>
              ) : (
                <Icon name="chevron-right" size={16} style={{ color: "var(--ink-3)" }}/>
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------- Library ----------------
function LibraryScreen() {
  const [filter, setFilter] = useState("All");
  const [q, setQ] = useState("");
  const cats = ["All", "Strength", "HIIT", "Mobility", "Recovery"];
  const items = window.PulseData.LIBRARY.filter(e =>
    (filter === "All" || e.kind === filter) &&
    (q === "" || e.name.toLowerCase().includes(q.toLowerCase()))
  );

  return (
    <div className="screen fade-in">
      <TBM left={<div><div className="t-eyebrow">Browse</div><div className="t-h2">Library</div></div>}/>
      <div style={{ padding: "0 22px 16px" }}>
        <div style={{
          display: "flex", alignItems: "center", gap: 8,
          background: "var(--bg-1)", border: "1px solid var(--line)",
          borderRadius: 999, padding: "12px 16px",
        }}>
          <Icon name="search" size={16} style={{ color: "var(--ink-3)" }}/>
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search exercises..."
            style={{ flex: 1, border: 0, background: "transparent", outline: "none", fontSize: 14 }}/>
        </div>
        <div style={{ display: "flex", gap: 6, marginTop: 14, overflowX: "auto", scrollbarWidth: "none" }}>
          {cats.map(c => (
            <button key={c} onClick={() => setFilter(c)}
              className="pill"
              style={{
                padding: "8px 14px",
                background: filter === c ? "var(--ink-0)" : "var(--bg-1)",
                color: filter === c ? "var(--bg-0)" : "var(--ink-2)",
                border: filter === c ? "1px solid transparent" : "1px solid var(--line)",
              }}>{c.toUpperCase()}</button>
          ))}
        </div>
      </div>

      <div className="scroll" style={{ padding: "0 14px 110px" }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
          {items.map((e, i) => (
            <button key={i} className="card" style={{ padding: 0, textAlign: "left", overflow: "hidden" }}>
              <div style={{ position: "relative", aspectRatio: "1", borderTopLeftRadius: 22, borderTopRightRadius: 22, overflow: "hidden" }}>
                <div className="hero-img" style={{ position: "absolute", inset: 0, "--accent-h": (i * 33) % 360 }}>
                  <window.PulseUI.PoseFrame/>
                </div>
                <div style={{ position: "absolute", top: 8, right: 8, padding: "3px 8px", background: "oklch(0% 0 0 / 0.5)", borderRadius: 999, fontSize: 10, fontFamily: "var(--f-mono)" }}>
                  {e.level.slice(0,3).toUpperCase()}
                </div>
                <div style={{ position: "absolute", bottom: 8, left: 8 }}>
                  <Icon name="play" size={20}/>
                </div>
              </div>
              <div style={{ padding: 12 }}>
                <div style={{ fontWeight: 500, fontSize: 13, lineHeight: 1.2 }}>{e.name}</div>
                <div className="t-small" style={{ fontSize: 11, marginTop: 4 }}>{e.focus}</div>
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------- Stats ----------------
function StatsScreen() {
  const s = window.PulseData.STATS;
  return (
    <div className="screen fade-in">
      <TBM left={<div><div className="t-eyebrow">April</div><div className="t-h2">Progress</div></div>}/>
      <div className="scroll" style={{ padding: "0 22px 110px" }}>
        {/* Hero stat */}
        <div className="card" style={{ padding: 20, marginBottom: 12 }}>
          <div className="t-eyebrow">Weekly volume</div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 6, marginTop: 6 }}>
            <span style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 56, color: "var(--accent)", lineHeight: 0.9 }}>
              {s.weeklyMinutes}
            </span>
            <span className="t-mono" style={{ color: "var(--ink-2)", fontSize: 16 }}>/ {s.weeklyTarget} min</span>
          </div>
          <div style={{ marginTop: 16, display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
            <BCM data={s.recentSessions} width={210} height={70}/>
            <div style={{ textAlign: "right" }}>
              <div className="t-eyebrow">Trend</div>
              <div className="t-mono" style={{ color: "var(--good)", fontSize: 14 }}>+12%</div>
            </div>
          </div>
        </div>

        {/* HR zones */}
        <div className="card" style={{ padding: 18, marginBottom: 12 }}>
          <div className="row-end" style={{ marginBottom: 14 }}>
            <div className="t-eyebrow">HR zones · this week</div>
            <div className="t-mono t-small" style={{ fontSize: 11 }}>HOURS</div>
          </div>
          {[
            { k: "z1", label: "Z1 · Recovery", h: 160, val: s.zones.z1 },
            { k: "z2", label: "Z2 · Easy", h: 130, val: s.zones.z2 },
            { k: "z3", label: "Z3 · Steady", h: 70, val: s.zones.z3 },
            { k: "z4", label: "Z4 · Threshold", h: 30, val: s.zones.z4 },
            { k: "z5", label: "Z5 · Max", h: 15, val: s.zones.z5 },
          ].map(z => (
            <div key={z.k} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
              <div style={{ width: 84, fontSize: 12, color: "var(--ink-2)" }}>{z.label}</div>
              <div style={{ flex: 1, height: 8, background: "var(--bg-3)", borderRadius: 4, overflow: "hidden" }}>
                <div style={{
                  height: "100%", width: `${(z.val / 50) * 100}%`,
                  background: `oklch(72% 0.16 ${z.h})`, borderRadius: 4,
                  transition: "width .6s var(--e-out)",
                }}/>
              </div>
              <div className="t-mono tick" style={{ width: 28, textAlign: "right", fontSize: 12 }}>{z.val}</div>
            </div>
          ))}
        </div>

        {/* Mini grid */}
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginBottom: 12 }}>
          <div className="card" style={{ padding: 16 }}>
            <div className="t-eyebrow">Streak</div>
            <div className="t-mono tick" style={{ fontSize: 28, fontWeight: 600, marginTop: 4 }}>{s.streak}d</div>
            <div className="t-small" style={{ fontSize: 11 }}>Personal best</div>
          </div>
          <div className="card" style={{ padding: 16 }}>
            <div className="t-eyebrow">Lifted</div>
            <div className="t-mono tick" style={{ fontSize: 22, fontWeight: 600, marginTop: 4 }}>{(s.totalLifted / 1000).toFixed(1)}<span style={{ fontSize: 14, color: "var(--ink-3)" }}>t</span></div>
            <div className="t-small" style={{ fontSize: 11 }}>This month</div>
          </div>
        </div>

        {/* PRs */}
        <div className="card" style={{ padding: "8px 0" }}>
          <div style={{ padding: "10px 18px" }}>
            <div className="t-eyebrow">Recent PRs</div>
          </div>
          {s.prs.map(pr => (
            <div key={pr.lift} className="row" style={{ padding: "12px 18px" }}>
              <Icon name="bolt" size={16} style={{ color: "var(--accent)" }}/>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, fontSize: 14 }}>{pr.lift}</div>
                <div className="t-small" style={{ fontSize: 11 }}>{pr.date}</div>
              </div>
              <div className="t-mono" style={{ fontSize: 14, color: "var(--accent)" }}>{pr.weight}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------- Profile ----------------
function ProfileScreen({ coach, onChangeCoach, onTweaks }) {
  const COACHES = window.PulseData.COACHES;
  const items = [
    { icon: "spark", label: "Coach", value: coach.name },
    { icon: "bell", label: "Notifications", value: "On" },
    { icon: "heart", label: "Health & devices", value: "Apple Watch" },
    { icon: "lock", label: "Privacy", value: "" },
    { icon: "settings", label: "Preferences", value: "" },
  ];

  return (
    <div className="screen fade-in">
      <TBM
        left={<div><div className="t-eyebrow">You</div><div className="t-h2">Profile</div></div>}
        right={<button className="icon-btn" onClick={onTweaks}><Icon name="settings" size={16}/></button>}
      />
      <div className="scroll" style={{ padding: "0 22px 110px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 14, padding: "10px 4px 22px" }}>
          <div style={{
            width: 64, height: 64, borderRadius: "50%",
            background: "linear-gradient(135deg, oklch(60% 0.06 60), oklch(30% 0.02 60))",
            display: "grid", placeItems: "center",
            fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 28,
          }}>A</div>
          <div>
            <div className="t-h2" style={{ fontSize: 20 }}>Alex Mercer</div>
            <div className="t-small">Member since Feb 2026 · 86 sessions</div>
          </div>
        </div>

        <div className="card" style={{ padding: 16, marginBottom: 12 }}>
          <div className="t-eyebrow" style={{ marginBottom: 12 }}>Coach</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
            {Object.values(COACHES).map(c => {
              const on = coach.id === c.id;
              return (
                <button key={c.id} onClick={() => onChangeCoach(c.id)}
                  style={{
                    padding: 12, textAlign: "left",
                    background: on ? "var(--bg-2)" : "var(--bg-0)",
                    border: `1px solid ${on ? `oklch(72% 0.18 ${c.accent})` : "var(--line-soft)"}`,
                    borderRadius: 14,
                    display: "flex", gap: 10, alignItems: "center",
                  }}>
                  <CAM coach={c} size={32}/>
                  <div>
                    <div style={{ fontSize: 13, fontWeight: 500 }}>{c.name}</div>
                    <div className="t-small" style={{ fontSize: 11 }}>{c.role}</div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        <div className="card">
          {items.slice(1).map(it => (
            <div key={it.label} className="row">
              <Icon name={it.icon} size={16} style={{ color: "var(--ink-2)" }}/>
              <div style={{ flex: 1, fontSize: 14 }}>{it.label}</div>
              {it.value && <div className="t-small" style={{ fontSize: 12 }}>{it.value}</div>}
              <Icon name="chevron-right" size={14} style={{ color: "var(--ink-3)" }}/>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------- Chat ----------------
function ChatScreen({ coach, onClose }) {
  const [messages, setMessages] = useState([
    { role: "coach", text: `Morning. I lined up Engine Builder for today — lower body strength + Z2 finisher. Anything you want to swap?` },
  ]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const scrollRef = useRef(null);

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages, busy]);

  const send = async (text) => {
    if (!text.trim() || busy) return;
    const next = [...messages, { role: "user", text }];
    setMessages(next);
    setDraft("");
    setBusy(true);
    try {
      const sys = `You are ${coach.name}, ${coach.style} You coach a user named Alex who just completed a heavy upper-body session yesterday. Today's plan is "Engine Builder" — 42 min, lower body strength + Zone 2 finisher. Keep replies short (1-3 sentences), helpful, in-character. Never use emojis.`;
      const reply = await window.claude.complete({
        messages: [
          { role: "user", content: sys + "\n\nUser: " + text }
        ],
      });
      setMessages(m => [...m, { role: "coach", text: reply.trim() }]);
    } catch (e) {
      setMessages(m => [...m, { role: "coach", text: "Lost connection. Try again in a sec." }]);
    } finally {
      setBusy(false);
    }
  };

  const suggestions = ["Make it shorter", "Skip legs today", "How was yesterday?", "Add core work"];

  return (
    <div className="screen fade-in">
      <TBM
        left={<button className="icon-btn" onClick={onClose}><Icon name="back" size={16}/></button>}
        title={coach.name}
        sub={coach.role.toUpperCase()}
        right={<button className="icon-btn"><Icon name="more" size={16}/></button>}
      />
      <div ref={scrollRef} className="scroll" style={{ padding: "8px 18px 12px" }}>
        {messages.map((m, i) => (
          <div key={i} style={{
            display: "flex", marginBottom: 10,
            justifyContent: m.role === "user" ? "flex-end" : "flex-start",
            alignItems: "flex-end", gap: 8,
          }}>
            {m.role === "coach" && <CAM coach={coach} size={26}/>}
            <div style={{
              maxWidth: "78%",
              padding: "10px 14px",
              borderRadius: m.role === "user" ? "18px 18px 4px 18px" : "18px 18px 18px 4px",
              background: m.role === "user" ? "var(--accent)" : "var(--bg-2)",
              color: m.role === "user" ? "var(--accent-ink)" : "var(--ink-0)",
              fontSize: 14, lineHeight: 1.4,
            }}>
              {m.text}
            </div>
          </div>
        ))}
        {busy && (
          <div style={{ display: "flex", gap: 8, alignItems: "center", marginLeft: 36 }}>
            <CAM coach={coach} size={26}/>
            <div style={{ padding: "10px 14px", background: "var(--bg-2)", borderRadius: "18px 18px 18px 4px", display: "flex", gap: 4 }}>
              <span className="pulse-dot" style={{ width: 6, height: 6, borderRadius: 999, background: "var(--ink-2)", animationDelay: "0s" }}/>
              <span className="pulse-dot" style={{ width: 6, height: 6, borderRadius: 999, background: "var(--ink-2)", animationDelay: "0.2s" }}/>
              <span className="pulse-dot" style={{ width: 6, height: 6, borderRadius: 999, background: "var(--ink-2)", animationDelay: "0.4s" }}/>
            </div>
          </div>
        )}
      </div>

      {messages.length <= 1 && (
        <div style={{ padding: "0 18px 8px", display: "flex", gap: 6, flexWrap: "wrap" }}>
          {suggestions.map(s => (
            <button key={s} className="pill" onClick={() => send(s)} style={{ padding: "8px 12px", fontSize: 12, fontFamily: "var(--f-sans)", letterSpacing: 0, textTransform: "none" }}>
              {s}
            </button>
          ))}
        </div>
      )}

      <div style={{ padding: "8px 14px 18px", display: "flex", gap: 8, alignItems: "center", borderTop: "1px solid var(--line-soft)" }}>
        <div style={{
          flex: 1, display: "flex", alignItems: "center", gap: 8,
          background: "var(--bg-1)", border: "1px solid var(--line)",
          borderRadius: 999, padding: "10px 16px",
        }}>
          <input value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && send(draft)}
            placeholder={`Message ${coach.name}...`}
            style={{ flex: 1, border: 0, background: "transparent", outline: "none", fontSize: 14 }}/>
        </div>
        <button onClick={() => send(draft)} className="icon-btn" style={{ background: "var(--accent)", color: "var(--accent-ink)", border: "none" }}>
          <Icon name="send" size={16}/>
        </button>
      </div>
    </div>
  );
}

window.CalendarScreen = CalendarScreen;
window.LibraryScreen = LibraryScreen;
window.StatsScreen = StatsScreen;
window.ProfileScreen = ProfileScreen;
window.ChatScreen = ChatScreen;
