// Pulse — shared UI components

const { useState, useEffect, useRef, useMemo } = React;

// Top bar
function TopBar({ left, right, title, sub }) {
  return (
    <div className="topbar">
      <div className="left">{left}</div>
      {title ? (
        <div style={{ textAlign: "center" }}>
          <div className="t-h3" style={{ fontSize: 15 }}>{title}</div>
          {sub && <div className="t-mono t-small" style={{ fontSize: 10, color: "var(--ink-3)", letterSpacing: "0.12em", textTransform: "uppercase" }}>{sub}</div>}
        </div>
      ) : null}
      <div className="right">{right}</div>
    </div>
  );
}

// Tab bar
function TabBar({ active, onChange }) {
  const tabs = [
    { id: "home", icon: "home" },
    { id: "calendar", icon: "calendar" },
    { id: "library", icon: "library" },
    { id: "stats", icon: "stats" },
    { id: "profile", icon: "user" },
  ];
  return (
    <div className="tabbar">
      {tabs.map(t => (
        <button
          key={t.id}
          className={"tab" + (active === t.id ? " is-active" : "")}
          onClick={() => onChange(t.id)}
        >
          <Icon name={t.icon} size={20} />
        </button>
      ))}
    </div>
  );
}

// Coach avatar
function CoachAvatar({ coach, size = 36, ring = false }) {
  const accent = `oklch(72% 0.18 ${coach.accent})`;
  return (
    <div style={{
      width: size, height: size,
      borderRadius: "50%",
      display: "grid", placeItems: "center",
      background: `linear-gradient(135deg, ${accent}, oklch(40% 0.10 ${coach.accent}))`,
      color: "oklch(15% 0.04 60)",
      fontFamily: "var(--f-display)",
      fontStyle: "italic",
      fontSize: size * 0.5,
      position: "relative",
      boxShadow: ring ? `0 0 0 2px var(--bg-0), 0 0 0 3px ${accent}` : "none",
      flexShrink: 0,
    }}>
      {coach.avatar}
    </div>
  );
}

// Ring (progress)
function Ring({ value = 0, size = 72, stroke = 6, label, sublabel }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const off = c * (1 - Math.min(1, Math.max(0, value)));
  return (
    <div style={{ position: "relative", width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle cx={size/2} cy={size/2} r={r} strokeWidth={stroke} fill="none" className="ring-track" />
        <circle cx={size/2} cy={size/2} r={r} strokeWidth={stroke} fill="none"
          className="ring-fill"
          strokeDasharray={c} strokeDashoffset={off} strokeLinecap="round"
        />
      </svg>
      {label && (
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", textAlign: "center" }}>
          <div>
            <div className="t-mono tick" style={{ fontSize: size * 0.22, fontWeight: 600 }}>{label}</div>
            {sublabel && <div className="t-eyebrow" style={{ fontSize: 9, marginTop: 1 }}>{sublabel}</div>}
          </div>
        </div>
      )}
    </div>
  );
}

// Workout type chip (icon)
function WorkoutTypeChip({ type, size = 28 }) {
  const map = {
    Strength: { icon: "dumbbell", h: 45 },
    HIIT: { icon: "bolt", h: 25 },
    Cardio: { icon: "heart", h: 25 },
    Mobility: { icon: "stretch", h: 160 },
    Recovery: { icon: "leaf", h: 160 },
  };
  const m = map[type] || { icon: "spark", h: 45 };
  return (
    <div style={{
      width: size, height: size, borderRadius: 8,
      background: `oklch(72% 0.18 ${m.h} / 0.14)`,
      color: `oklch(82% 0.16 ${m.h})`,
      display: "grid", placeItems: "center", flexShrink: 0,
    }}>
      <Icon name={m.icon} size={size * 0.55} />
    </div>
  );
}

// Mini sparkline
function Sparkline({ data, width = 100, height = 28, color = "var(--accent)" }) {
  if (!data || data.length === 0) return null;
  const max = Math.max(...data);
  const min = Math.min(...data);
  const range = max - min || 1;
  const points = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width;
    const y = height - ((v - min) / range) * height;
    return `${x},${y}`;
  }).join(" ");
  return (
    <svg width={width} height={height} style={{ display: "block" }}>
      <polyline points={points} fill="none" stroke={color} strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// Bar chart
function BarChart({ data, width = 280, height = 120, accent = "var(--accent)" }) {
  const max = Math.max(...data);
  const bw = width / data.length - 4;
  return (
    <svg width={width} height={height} style={{ display: "block" }}>
      {data.map((v, i) => {
        const h = (v / max) * height;
        return (
          <rect key={i}
            x={i * (width / data.length) + 2}
            y={height - h}
            width={bw}
            height={h}
            rx={3}
            fill={i === data.length - 1 ? accent : "var(--bg-3)"}
            opacity={i === data.length - 1 ? 1 : 0.85}
          />
        );
      })}
    </svg>
  );
}

// Animated dotted body
function PoseFrame({ kind = "squat" }) {
  // Simple, abstract pose using circles + lines (placeholder)
  const colors = {
    head: "oklch(85% 0.005 80)",
    body: "oklch(70% 0.005 80 / 0.8)",
    accent: "var(--accent)",
  };
  return (
    <svg viewBox="0 0 200 240" style={{ width: "100%", height: "100%" }}>
      <defs>
        <linearGradient id="bodyG" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="oklch(85% 0.005 80)"/>
          <stop offset="1" stopColor="oklch(60% 0.01 80)"/>
        </linearGradient>
      </defs>
      {kind === "squat" && (
        <g stroke="url(#bodyG)" strokeWidth="6" fill="none" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="100" cy="40" r="14" fill="url(#bodyG)" stroke="none"/>
          <line x1="100" y1="56" x2="100" y2="120"/>
          {/* arms forward */}
          <path d="M100 70 L70 95 L60 130"/>
          <path d="M100 70 L130 95 L140 130"/>
          {/* bent legs */}
          <path d="M100 120 L75 155 L85 200"/>
          <path d="M100 120 L125 155 L115 200"/>
        </g>
      )}
    </svg>
  );
}

// Generic SVG silhouette / placeholder
function ExercisePlaceholder({ label = "Form video", h = 45 }) {
  return (
    <div className="hero-img" style={{ position: "absolute", inset: 0, "--accent-h": h }}>
      <div className="grain"/>
      <div className="pose">
        <PoseFrame/>
      </div>
      <div style={{
        position: "absolute", left: 14, bottom: 12, display: "flex", alignItems: "center", gap: 8,
        fontFamily: "var(--f-mono)", fontSize: 10, letterSpacing: "0.16em", textTransform: "uppercase",
        color: "oklch(100% 0 0 / 0.6)",
      }}>
        <span style={{
          display: "inline-block", width: 6, height: 6, borderRadius: 999,
          background: "var(--accent)",
        }} className="pulse-dot"/>
        {label}
      </div>
    </div>
  );
}

// Pretty headline (mixes serif italic + sans)
function Headline({ children, size = 36 }) {
  return (
    <h1 style={{ margin: 0, fontFamily: "var(--f-sans)", fontWeight: 600, fontSize: size, letterSpacing: "-0.025em", lineHeight: 1.05 }}>
      {children}
    </h1>
  );
}

window.PulseUI = { TopBar, TabBar, CoachAvatar, Ring, WorkoutTypeChip, Sparkline, BarChart, ExercisePlaceholder, PoseFrame, Headline };
