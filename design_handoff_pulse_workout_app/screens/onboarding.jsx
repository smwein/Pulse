// Pulse — Onboarding flow

const { TopBar, Headline } = window.PulseUI;
const { useState: useStateOB } = React;

function OnboardingScreen({ onDone }) {
  const [step, setStep] = useState(0);
  const [goals, setGoals] = useState(["strength", "longevity"]);
  const [level, setLevel] = useState("regular");
  const [equip, setEquip] = useState(["db", "kb", "bench"]);
  const [days, setDays] = useState(4);
  const [coach, setCoach] = useState("ace");

  const O = window.PulseData.ONBOARDING;
  const COACHES = window.PulseData.COACHES;

  const next = () => step < 4 ? setStep(step + 1) : onDone({ goals, level, equip, days, coach });
  const back = () => step > 0 ? setStep(step - 1) : onDone({ goals, level, equip, days, coach });

  const toggle = (arr, set, id) => {
    set(arr.includes(id) ? arr.filter(x => x !== id) : [...arr, id]);
  };

  const Step = ({ title, sub, children }) => (
    <div className="fade-in" style={{ padding: "10px 24px", flex: 1, display: "flex", flexDirection: "column" }}>
      <div className="t-eyebrow" style={{ marginBottom: 8 }}>Step {step + 1} of 5</div>
      <Headline size={30}>{title}</Headline>
      {sub && <div className="t-body" style={{ marginTop: 10, fontSize: 15, color: "var(--ink-2)" }}>{sub}</div>}
      <div style={{ marginTop: 26, flex: 1 }}>{children}</div>
    </div>
  );

  return (
    <div className="screen">
      <TopBar
        left={
          <button className="icon-btn" onClick={back}>
            <Icon name={step === 0 ? "close" : "back"} size={16}/>
          </button>
        }
        right={
          <button className="t-small" style={{ color: "var(--ink-2)" }} onClick={onDone}>Skip</button>
        }
      />

      {/* Progress bar */}
      <div style={{ padding: "0 24px 4px" }}>
        <div style={{ height: 3, background: "var(--bg-2)", borderRadius: 999, overflow: "hidden" }}>
          <div style={{ height: "100%", width: `${(step + 1) * 20}%`, background: "var(--accent)", transition: "width .35s var(--e-out)" }}/>
        </div>
      </div>

      <div className="scroll">
        {step === 0 && (
          <Step title="What brings you here?" sub="Pick anything that resonates. We'll shape your plan around it.">
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              {O.goals.map(g => {
                const on = goals.includes(g.id);
                return (
                  <button key={g.id} onClick={() => toggle(goals, setGoals, g.id)}
                    style={{
                      padding: 18, textAlign: "left",
                      borderRadius: "var(--r-md)",
                      background: on ? "var(--accent-soft)" : "var(--bg-1)",
                      border: `1px solid ${on ? "var(--accent)" : "var(--line)"}`,
                      color: on ? "var(--accent)" : "var(--ink-0)",
                      transition: "all .25s var(--e-out)",
                    }}>
                    <Icon name={g.icon} size={22}/>
                    <div style={{ fontWeight: 500, fontSize: 14, marginTop: 12 }}>{g.label}</div>
                  </button>
                );
              })}
            </div>
          </Step>
        )}

        {step === 1 && (
          <Step title="Where are you starting?" sub="No wrong answer — this just sets the load.">
            <div style={{ display: "grid", gap: 10 }}>
              {O.levels.map(l => {
                const on = level === l.id;
                return (
                  <button key={l.id} onClick={() => setLevel(l.id)}
                    style={{
                      padding: "16px 18px", textAlign: "left",
                      borderRadius: "var(--r-md)",
                      background: on ? "var(--accent-soft)" : "var(--bg-1)",
                      border: `1px solid ${on ? "var(--accent)" : "var(--line)"}`,
                      transition: "all .25s var(--e-out)",
                      display: "flex", alignItems: "center", gap: 14,
                    }}>
                    <div style={{
                      width: 22, height: 22, borderRadius: 999,
                      border: `2px solid ${on ? "var(--accent)" : "var(--line)"}`,
                      display: "grid", placeItems: "center",
                    }}>
                      {on && <div style={{ width: 10, height: 10, background: "var(--accent)", borderRadius: 999 }}/>}
                    </div>
                    <div>
                      <div style={{ fontWeight: 500, fontSize: 15, color: on ? "var(--accent)" : "var(--ink-0)" }}>{l.label}</div>
                      <div className="t-small" style={{ marginTop: 2 }}>{l.desc}</div>
                    </div>
                  </button>
                );
              })}
            </div>
          </Step>
        )}

        {step === 2 && (
          <Step title="What gear do you have?" sub="We'll only program what you can actually do.">
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {O.equipment.map(e => {
                const on = equip.includes(e.id);
                return (
                  <button key={e.id} onClick={() => toggle(equip, setEquip, e.id)}
                    style={{
                      padding: "12px 18px",
                      borderRadius: 999,
                      background: on ? "var(--accent)" : "var(--bg-1)",
                      color: on ? "var(--accent-ink)" : "var(--ink-0)",
                      border: `1px solid ${on ? "transparent" : "var(--line)"}`,
                      fontSize: 14, fontWeight: 500,
                      transition: "all .25s var(--e-out)",
                    }}>
                    {on && <Icon name="check" size={14} style={{ marginRight: 6, verticalAlign: -2 }}/>}
                    {e.label}
                  </button>
                );
              })}
            </div>
          </Step>
        )}

        {step === 3 && (
          <Step title="How often can you train?" sub="Honest is better than ambitious. We can always add later.">
            <div style={{ marginTop: 40, textAlign: "center" }}>
              <div style={{ fontFamily: "var(--f-display)", fontStyle: "italic", fontSize: 84, color: "var(--accent)", lineHeight: 1 }}>
                {days}
              </div>
              <div className="t-eyebrow" style={{ marginTop: 6 }}>days per week</div>
              <div style={{ display: "flex", justifyContent: "center", gap: 10, marginTop: 30 }}>
                {[2,3,4,5,6].map(n => (
                  <button key={n} onClick={() => setDays(n)}
                    style={{
                      width: 50, height: 50, borderRadius: "50%",
                      background: days === n ? "var(--accent)" : "var(--bg-1)",
                      color: days === n ? "var(--accent-ink)" : "var(--ink-1)",
                      border: `1px solid ${days === n ? "transparent" : "var(--line)"}`,
                      fontWeight: 500, fontSize: 16,
                      transition: "all .25s var(--e-out)",
                    }}>{n}</button>
                ))}
              </div>
            </div>
          </Step>
        )}

        {step === 4 && (
          <Step title="Choose your coach." sub="The voice behind your plan. You can switch anytime.">
            <div style={{ display: "grid", gap: 10 }}>
              {Object.values(COACHES).map(c => {
                const on = coach === c.id;
                return (
                  <button key={c.id} onClick={() => setCoach(c.id)}
                    style={{
                      padding: 16, textAlign: "left",
                      borderRadius: "var(--r-md)",
                      background: on ? "var(--bg-2)" : "var(--bg-1)",
                      border: `1px solid ${on ? `oklch(72% 0.18 ${c.accent})` : "var(--line)"}`,
                      display: "flex", gap: 14, alignItems: "center",
                      transition: "all .25s var(--e-out)",
                    }}>
                    <CoachAvatar coach={c} size={48}/>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 500, fontSize: 16 }}>
                        {c.name} <span style={{ color: "var(--ink-3)", fontWeight: 400, fontFamily: "var(--f-display)", fontStyle: "italic" }}>· {c.role}</span>
                      </div>
                      <div className="t-small" style={{ marginTop: 4, fontSize: 12 }}>{c.blurb}</div>
                    </div>
                    {on && <Icon name="check" size={18} style={{ color: `oklch(72% 0.18 ${c.accent})` }}/>}
                  </button>
                );
              })}
            </div>
          </Step>
        )}
      </div>

      <div style={{ padding: "12px 22px 22px" }}>
        <button className="btn btn-primary btn-block btn-lg" onClick={next}>
          {step < 4 ? "Continue" : "Build my plan"} <Icon name="arrow-right" size={16}/>
        </button>
      </div>
    </div>
  );
}

window.OnboardingScreen = OnboardingScreen;
