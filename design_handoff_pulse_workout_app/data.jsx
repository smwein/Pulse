// Pulse — mock data

const COACHES = {
  ace: {
    id: "ace",
    name: "Ace",
    role: "The Friend",
    blurb: "Warm, encouraging, low-pressure. Celebrates every win.",
    accent: 45,
    style: "warm and encouraging like a close friend who happens to be a great trainer. Use casual contractions, light humor, and short sentences. Celebrate small wins.",
    avatar: "A",
  },
  rex: {
    id: "rex",
    name: "Rex",
    role: "The Athlete",
    blurb: "Direct, intense, no-nonsense. Pushes you past your limits.",
    accent: 25,
    style: "a former pro athlete. Direct, intense, no fluff. Short imperative sentences. Push hard, no excuses, but never mean.",
    avatar: "R",
  },
  vera: {
    id: "vera",
    name: "Vera",
    role: "The Analyst",
    blurb: "Data-driven. Cites your numbers and trends.",
    accent: 220,
    style: "a sports scientist. Cite numbers, percentages, and physiological reasoning. Calm, precise, structured. Reference HRV, RPE, and load.",
    avatar: "V",
  },
  mira: {
    id: "mira",
    name: "Mira",
    role: "The Mindful",
    blurb: "Calm, breath-aware. Connects effort to feeling.",
    accent: 160,
    style: "a calm, mindful coach. Speak softly, focus on breath, body awareness, and how movement feels. Use sensory language. Never rushed.",
    avatar: "M",
  },
};

const TODAY_WORKOUT = {
  id: "w-001",
  title: "Engine Builder",
  subtitle: "Lower body strength + Zone 2 finisher",
  duration: 42,
  intensity: 7, // 1-10
  type: "Strength",
  kcal: 380,
  blocks: [
    { kind: "warmup", name: "Mobility flow", duration: 6, exercises: 4 },
    { kind: "main", name: "Main strength", duration: 24, exercises: 5 },
    { kind: "finisher", name: "Zone 2 ride", duration: 10, exercises: 1 },
    { kind: "cooldown", name: "Cooldown", duration: 2, exercises: 2 },
  ],
  why: "You logged a heavy upper-body session yesterday. Today shifts load to legs while keeping HR moderate to support recovery without losing fitness.",
  exercises: [
    { id: "e1", name: "World's Greatest Stretch", sets: "2 rounds", reps: "5 / side", rest: 0, kind: "warmup", focus: "Hips, T-spine" },
    { id: "e2", name: "Goblet Squat", sets: "4 sets", reps: "8 reps", rest: 90, kind: "main", focus: "Quads, glutes", load: "20 kg", videoLabel: "Form: knees track toes" },
    { id: "e3", name: "Romanian Deadlift", sets: "4 sets", reps: "8 reps", rest: 90, kind: "main", focus: "Hamstrings", load: "30 kg" },
    { id: "e4", name: "Reverse Lunge", sets: "3 sets", reps: "10 / side", rest: 60, kind: "main", focus: "Single leg" },
    { id: "e5", name: "Copenhagen Plank", sets: "3 sets", reps: "0:20 / side", rest: 45, kind: "main", focus: "Adductors, core" },
    { id: "e6", name: "Heel Elevated Calf Raise", sets: "3 sets", reps: "12 reps", rest: 45, kind: "main", focus: "Calves" },
    { id: "e7", name: "Zone 2 Bike", sets: "1 set", reps: "10:00", rest: 0, kind: "finisher", focus: "Aerobic base" },
    { id: "e8", name: "Box breathing", sets: "1 set", reps: "2:00", rest: 0, kind: "cooldown", focus: "Down-regulate" },
    { id: "e9", name: "Couch stretch", sets: "1 set", reps: "0:30 / side", rest: 0, kind: "cooldown", focus: "Hip flexors" },
  ],
};

const WEEK = [
  { day: "Mon", date: 21, workout: "Push & Pull", type: "Strength", duration: 50, done: true },
  { day: "Tue", date: 22, workout: "Engine Builder", type: "Strength", duration: 42, done: false, isToday: true },
  { day: "Wed", date: 23, workout: "Mobility Reset", type: "Mobility", duration: 25, done: false },
  { day: "Thu", date: 24, workout: "Threshold Intervals", type: "HIIT", duration: 32, done: false },
  { day: "Fri", date: 25, workout: "Posterior Chain", type: "Strength", duration: 45, done: false },
  { day: "Sat", date: 26, workout: "Long Aerobic", type: "Cardio", duration: 60, done: false },
  { day: "Sun", date: 27, workout: "Recovery", type: "Recovery", duration: 20, done: false },
];

const STATS = {
  weeklyMinutes: 168,
  weeklyTarget: 240,
  streak: 14,
  workoutsThisMonth: 18,
  totalLifted: 24840, // kg
  recentSessions: [42, 50, 28, 60, 45, 38, 55, 30, 48, 52, 40, 36],
  zones: { z1: 12, z2: 38, z3: 28, z4: 14, z5: 8 },
  prs: [
    { lift: "Back Squat", weight: "115 kg", date: "Apr 21" },
    { lift: "Deadlift", weight: "150 kg", date: "Apr 18" },
    { lift: "Bench", weight: "82.5 kg", date: "Apr 14" },
  ],
};

const LIBRARY = [
  { name: "Goblet Squat", focus: "Quads, glutes", level: "Beginner", kind: "Strength" },
  { name: "Romanian Deadlift", focus: "Hamstrings", level: "Intermediate", kind: "Strength" },
  { name: "Pull-Up", focus: "Back, biceps", level: "Intermediate", kind: "Strength" },
  { name: "Push-Up", focus: "Chest, triceps", level: "Beginner", kind: "Strength" },
  { name: "Kettlebell Swing", focus: "Posterior chain", level: "Intermediate", kind: "HIIT" },
  { name: "Burpee", focus: "Full body", level: "Intermediate", kind: "HIIT" },
  { name: "Box Jump", focus: "Power", level: "Advanced", kind: "HIIT" },
  { name: "World's Greatest Stretch", focus: "Hips, T-spine", level: "Beginner", kind: "Mobility" },
  { name: "Couch Stretch", focus: "Hip flexors", level: "Beginner", kind: "Mobility" },
  { name: "90/90 Hip Switch", focus: "Hip rotation", level: "Beginner", kind: "Mobility" },
  { name: "Box Breathing", focus: "Nervous system", level: "Beginner", kind: "Recovery" },
  { name: "Foam Roll Quads", focus: "Quad release", level: "Beginner", kind: "Recovery" },
];

const ONBOARDING = {
  goals: [
    { id: "strength", label: "Build strength", icon: "dumbbell" },
    { id: "lose", label: "Lose body fat", icon: "flame" },
    { id: "endurance", label: "Improve endurance", icon: "heart" },
    { id: "mobility", label: "Move better", icon: "stretch" },
    { id: "stress", label: "Manage stress", icon: "leaf" },
    { id: "longevity", label: "Longevity", icon: "spark" },
  ],
  levels: [
    { id: "new", label: "New to training", desc: "Less than 6 months consistent" },
    { id: "regular", label: "Regular", desc: "6 months — 2 years" },
    { id: "experienced", label: "Experienced", desc: "2+ years, comfortable with load" },
    { id: "athlete", label: "Athlete", desc: "Compete or train daily" },
  ],
  equipment: [
    { id: "bw", label: "Bodyweight only" },
    { id: "db", label: "Dumbbells" },
    { id: "kb", label: "Kettlebells" },
    { id: "barbell", label: "Barbell + rack" },
    { id: "bench", label: "Bench" },
    { id: "bands", label: "Resistance bands" },
    { id: "bike", label: "Bike / cardio" },
    { id: "gym", label: "Full gym access" },
  ],
};

window.PulseData = { COACHES, TODAY_WORKOUT, WEEK, STATS, LIBRARY, ONBOARDING };
