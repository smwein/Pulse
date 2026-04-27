// Icons — inline SVG, currentColor stroke
const Icon = ({ name, size = 20, stroke = 1.6, ...rest }) => {
  const props = {
    width: size, height: size, viewBox: "0 0 24 24",
    fill: "none", stroke: "currentColor",
    strokeWidth: stroke, strokeLinecap: "round", strokeLinejoin: "round",
    ...rest,
  };
  switch (name) {
    case "home": return (<svg {...props}><path d="M3 11.5 12 4l9 7.5"/><path d="M5 10v9a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-9"/></svg>);
    case "calendar": return (<svg {...props}><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>);
    case "library": return (<svg {...props}><path d="M4 5v14M9 5v14M14 5l5 14"/></svg>);
    case "stats": return (<svg {...props}><path d="M4 19V9M10 19V5M16 19v-7M22 19H2"/></svg>);
    case "user": return (<svg {...props}><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/></svg>);
    case "play": return (<svg {...props}><path d="M7 5v14l12-7L7 5z" fill="currentColor"/></svg>);
    case "pause": return (<svg {...props}><rect x="6" y="5" width="4" height="14" rx="1" fill="currentColor"/><rect x="14" y="5" width="4" height="14" rx="1" fill="currentColor"/></svg>);
    case "chevron-right": return (<svg {...props}><path d="M9 6l6 6-6 6"/></svg>);
    case "chevron-left": return (<svg {...props}><path d="M15 6l-6 6 6 6"/></svg>);
    case "arrow-right": return (<svg {...props}><path d="M5 12h14M13 6l6 6-6 6"/></svg>);
    case "arrow-up": return (<svg {...props}><path d="M12 19V5M6 11l6-6 6 6"/></svg>);
    case "close": return (<svg {...props}><path d="M6 6l12 12M6 18L18 6"/></svg>);
    case "plus": return (<svg {...props}><path d="M12 5v14M5 12h14"/></svg>);
    case "spark": return (<svg {...props}><path d="M12 3v6M12 15v6M3 12h6M15 12h6M5.6 5.6l4.2 4.2M14.2 14.2l4.2 4.2M5.6 18.4l4.2-4.2M14.2 9.8l4.2-4.2"/></svg>);
    case "bolt": return (<svg {...props}><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8z" fill="currentColor"/></svg>);
    case "flame": return (<svg {...props}><path d="M12 3s4 4 4 9a4 4 0 0 1-8 0c0-2 1-3 1-3s-1-1-1-3 4-3 4-3z"/><path d="M9.5 14.5C9.5 16 10.5 17 12 17s2.5-1 2.5-2.5"/></svg>);
    case "heart": return (<svg {...props}><path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.5A4 4 0 0 1 19 10c0 5.5-7 10-7 10z"/></svg>);
    case "timer": return (<svg {...props}><circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M9 2h6"/></svg>);
    case "muscle": return (<svg {...props}><path d="M5 14c2-3 4-3 6-2s4 0 6-2"/><path d="M3 18c4-1 8-1 12 1M5 8c2 1 4 1 6 0"/></svg>);
    case "settings": return (<svg {...props}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3 1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8 1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>);
    case "search": return (<svg {...props}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4-4"/></svg>);
    case "check": return (<svg {...props}><path d="M5 12l5 5 9-11"/></svg>);
    case "send": return (<svg {...props}><path d="M22 2 11 13M22 2l-7 20-4-9-9-4 20-7z"/></svg>);
    case "more": return (<svg {...props}><circle cx="5" cy="12" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/><circle cx="19" cy="12" r="1.5" fill="currentColor"/></svg>);
    case "skip": return (<svg {...props}><path d="M5 4l10 8-10 8V4z" fill="currentColor"/><path d="M19 5v14"/></svg>);
    case "back": return (<svg {...props}><path d="M19 12H5M12 19l-7-7 7-7"/></svg>);
    case "wave": return (<svg {...props}><path d="M2 12c2 0 2-4 4-4s2 8 4 8 2-12 4-12 2 8 4 8 2-4 4-4"/></svg>);
    case "leaf": return (<svg {...props}><path d="M5 21c1-9 6-15 16-15-1 9-6 15-16 15z"/><path d="M5 21c4-4 8-7 12-9"/></svg>);
    case "moon": return (<svg {...props}><path d="M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z"/></svg>);
    case "dumbbell": return (<svg {...props}><path d="M3 9v6M21 9v6M6 7v10M18 7v10M6 12h12"/></svg>);
    case "stretch": return (<svg {...props}><path d="M5 19c4-2 6-6 6-10M19 5c-2 4-6 6-10 6"/><circle cx="12" cy="12" r="2"/></svg>);
    case "lightning-fill": return (<svg viewBox="0 0 24 24" width={size} height={size} fill="currentColor" {...rest}><path d="M13 2 4 14h7l-1 8 9-12h-7l1-8z"/></svg>);
    case "lock": return (<svg {...props}><rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>);
    case "bell": return (<svg {...props}><path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8z"/><path d="M10 21a2 2 0 0 0 4 0"/></svg>);
    case "rest": return (<svg {...props}><path d="M3 12c4 0 4-6 9-6s5 12 9 12"/></svg>);
    case "star": return (<svg {...props}><path d="M12 3l2.6 5.8 6.4.6-4.8 4.4 1.4 6.2L12 17l-5.6 3 1.4-6.2L3 9.4l6.4-.6L12 3z" fill="currentColor" stroke="none"/></svg>);
    case "thumbUp": return (<svg {...props}><path d="M7 10v10H4V10h3zm0 0l4-7c1.5 0 2.5 1 2.5 2.5V9h5a2 2 0 0 1 2 2.4l-1.5 7A2 2 0 0 1 17 20H7"/></svg>);
    case "thumbDown": return (<svg {...props}><path d="M17 14V4h3v10h-3zm0 0l-4 7c-1.5 0-2.5-1-2.5-2.5V15h-5a2 2 0 0 1-2-2.4l1.5-7A2 2 0 0 1 7 4h10"/></svg>);
    case "alert": return (<svg {...props}><circle cx="12" cy="12" r="9"/><path d="M12 7v6M12 17v.5"/></svg>);
    case "minus": return (<svg {...props}><path d="M5 12h14"/></svg>);
    case "down": return (<svg {...props}><path d="M12 5v14M6 13l6 6 6-6"/></svg>);
    case "up": return (<svg {...props}><path d="M12 19V5M6 11l6-6 6 6"/></svg>);
    case "forward": return (<svg {...props}><path d="M5 12h14M13 6l6 6-6 6"/></svg>);
    case "shuffle": return (<svg {...props}><path d="M16 3h5v5M21 3l-7 7M4 4l16 16M16 21h5v-5M21 21l-7-7"/></svg>);
    default: return null;
  }
};

window.Icon = Icon;
