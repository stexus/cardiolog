const $ = (selector) => document.querySelector(selector);
const library = await fetch("fixtures/sessions.json").then((r) => {
  if (!r.ok) throw new Error("Fixtures failed to load");
  return r.json();
});
const clone = (value) => structuredClone(value);
// randomUUID is unavailable on plain HTTP LAN origins. getRandomValues is supported there.
const newID = () =>
  Array.from(crypto.getRandomValues(new Uint8Array(16)), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
const esc = (value) =>
  String(value).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const time = (seconds) =>
  `${Math.floor(Math.max(0, Math.ceil(seconds)) / 60)}:${String(Math.max(0, Math.ceil(seconds)) % 60).padStart(2, "0")}`;
const storeKey = "cardiolog-preview-v1";
let history;
try {
  history =
    JSON.parse(localStorage.getItem(storeKey)) || clone(library.workouts);
} catch {
  history = clone(library.workouts);
}
const templateStoreKey = "cardiolog-templates-v1";
let templates = clone(library.templates);
let lastTemplateID;
try {
  const saved = JSON.parse(localStorage.getItem(templateStoreKey));
  if (
    Array.isArray(saved) &&
    saved.length &&
    saved.every(
      (t) =>
        typeof t.id === "string" &&
        typeof t.name === "string" &&
        t.workSettings &&
        t.recoverySettings &&
        Number.isInteger(t.repetitions) &&
        t.repetitions >= 1 &&
        t.repetitions <= 99 &&
        t.workSeconds > 0 &&
        [
          t.workSeconds,
          t.recoverySeconds,
          t.warmupSeconds,
          t.cooldownSeconds,
        ].every((n) => Number.isFinite(n) && n >= 0) &&
        library.equipment.some((e) => e.id === t.equipmentID),
    )
  )
    templates = saved;
  lastTemplateID = localStorage.getItem("cardiolog-last-template");
} catch {}
const initialTemplate =
  templates.find((t) => t.id === lastTemplateID) || templates[0];
let state = {
  tab: "train",
  template: clone(initialTemplate),
  equipment: clone(
    library.equipment.find((e) => e.id === initialTemplate.equipmentID),
  ),
  showTemplates: false,
  sensor: "connected",
  session: null,
  detail: null,
  selected: 1,
  empty: false,
};
let copyOptions = { equipment: true, hr: true, recovery: false, notes: true };
try {
  copyOptions = {
    ...copyOptions,
    ...JSON.parse(localStorage.getItem("cardiolog-copy-v1")),
  };
} catch {}
function expand(t) {
  const rows = [];
  const add = (role, seconds, repetition = null) => {
    if (seconds > 0)
      rows.push({
        id: newID(),
        role,
        repetition,
        plannedSeconds: seconds,
        actualSeconds: 0,
        settings: clone(role === "work" ? t.workSettings : t.recoverySettings),
      });
  };
  add("warmup", t.warmupSeconds);
  for (let r = 1; r <= t.repetitions; r++) {
    add("work", t.workSeconds, r);
    if (r < t.repetitions || t.finalRecovery)
      add("recovery", t.recoverySeconds, r);
  }
  add("cooldown", t.cooldownSeconds);
  return rows;
}
const label = (role) =>
  ({
    warmup: "Warm-up",
    work: "Work",
    recovery: "Recovery",
    cooldown: "Cooldown",
  })[role];
const total = (rows) => rows.reduce((a, r) => a + r.plannedSeconds, 0);
const settingsText = (s) =>
  s.speed != null
    ? `${s.speed} mph · ${s.incline ?? "—"}% incline`
    : `Level ${s.resistance ?? "—"} · ${s.cadence ?? "—"} rpm`;
function sequence(rows) {
  return `<div class="sequence" aria-label="Workout phase sequence">${rows.map((r) => `<span class="${r.role}" style="flex:${r.plannedSeconds}" title="${label(r.role)} ${time(r.plannedSeconds)}"></span>`).join("")}</div><div class="legend"><span><i class="dot warmup"></i>Warm-up / cool</span><span><i class="dot"></i>Work</span><span><i class="dot recovery"></i>Recovery</span></div>`;
}
function heading(title, extra = "") {
  return `<div class="page-heading"><h1>${title}</h1>${extra}</div>`;
}
function sensorText() {
  return state.sensor === "none"
    ? "No HR sensor · timer available"
    : state.sensor === "disconnected"
      ? "Disconnected · last reading is stale"
      : "Polar H10 · simulated connection";
}
function rememberTemplate() {
  const index = templates.findIndex((t) => t.id === state.template.id);
  if (index < 0) templates.push(clone(state.template));
  else templates[index] = clone(state.template);
  try {
    localStorage.setItem(templateStoreKey, JSON.stringify(templates));
    localStorage.setItem("cardiolog-last-template", state.template.id);
  } catch {
    toast("Browser storage unavailable; template kept for this page only");
  }
}
function selectTemplate(template) {
  state.template = clone(template);
  state.equipment = clone(
    library.equipment.find((e) => e.id === template.equipmentID),
  );
  state.showTemplates = false;
  rememberTemplate();
}
function templateList() {
  return (
    heading(
      "Timers",
      `<button class="text-button" data-action="new-template" aria-label="New template">＋ New</button>`,
    ) +
    `<p class="secondary">Your saved workout templates.</p><div class="template-library">${templates
      .map(
        (t) => `
      <button class="template-choice library-row" data-action="select-template" data-id="${esc(t.id)}">
        <span class="template-symbol" aria-hidden="true">${t.activity === "bike" ? "◎" : "↗"}</span>
        <span class="stack"><strong>${esc(t.name)}</strong><small>${t.activity === "bike" ? "Indoor bike" : "Treadmill"} · ${time(total(expand(t)))}</small>${t.id === state.template.id ? '<span class="last-used">Last used</span>' : ""}</span>
        <span class="chevron" aria-hidden="true">›</span>
      </button>`,
      )
      .join(
        "",
      )}</div><p class="secondary library-note">Choose a timer to see its workout.<br>Your last-used template opens automatically next time.</p>`
  );
}
function train() {
  const t = state.template,
    rows = expand(t);
  return (
    `<div class="row template-navigation"><button class="text-button" data-action="templates" aria-label="Back to Timers">‹ Timers</button><button class="text-button" data-action="template-options" aria-label="Template options">•••</button></div>` +
    heading(esc(t.name)) +
    `<div class="setup-layout"><div><div class="card hero-card"><div class="row"><span class="pill">${t.activity === "bike" ? "INDOOR BIKE" : "TREADMILL"}</span><button class="text-button" data-action="edit-template">Edit</button></div>
    <div class="planned-time">${time(total(rows))} <small>planned active time</small></div><div class="secondary">${t.repetitions} ${t.repetitions === 1 ? "effort" : "efforts"} · ${time(t.workSeconds)} work${t.recoverySeconds ? ` / ${time(t.recoverySeconds)} recovery` : ""}</div>${sequence(rows)}</div>
    <div class="section-label">Before you begin</div><button class="card row template-choice" data-action="equipment"><span class="symbol">⌁</span><span class="stack" style="flex:1"><strong>${esc(state.equipment.gym)}</strong><small>${esc(state.equipment.name)} · ${t.activity === "bike" ? "resistance / rpm" : "mph / incline %"}</small></span><span>›</span></button><div class="card"><div class="row"><span class="stack"><strong>Heart rate</strong><span class="state-line ${state.sensor !== "connected" ? "warn" : ""}">${sensorText()}</span></span><button class="text-button" data-action="sensor">Manage</button></div><div class="settings-row row"><span class="stack"><strong>Apple Health</strong><small>Off · samples stay in preview</small></span><button class="text-button" data-action="health">›</button></div></div></div>
    <div><div class="section-label">Timer preview</div><div class="card timer-sequence">${rows.map((r) => `<div class="preview-phase"><i class="dot ${r.role}" aria-hidden="true"></i><div class="stack"><strong>${label(r.role)}${r.repetition ? ` · ${r.repetition} of ${t.repetitions}` : ""}</strong><small>${esc(settingsText(r.settings))}</small></div><span class="phase-duration">${time(r.plannedSeconds)}</span></div>`).join("")}</div></div></div>`
  );
}
function elapsed() {
  const s = state.session;
  return Math.min(
    total(s.rows),
    s.base + (s.paused ? 0 : (performance.now() - s.anchor) / 1000),
  );
}
function current() {
  let sum = 0;
  const e = elapsed();
  for (let i = 0; i < state.session.rows.length; i++) {
    sum += state.session.rows[i].plannedSeconds;
    if (e < sum) return { index: i, remaining: sum - e };
  }
  return { index: state.session.rows.length - 1, remaining: 0 };
}
function live() {
  const s = state.session,
    c = current(),
    r = s.rows[c.index],
    next = s.rows[c.index + 1],
    e = elapsed();
  return `<div class="row"><button class="text-button" data-action="minimize">‹ Timer</button><span class="secondary">${esc(s.template.name)}</span><span class="pill">SAMPLE</span></div><div class="live-layout"><div><div class="live-title"><span class="pill">${s.paused ? "PAUSED" : label(r.role).toUpperCase()}${r.repetition ? ` · ${r.repetition} OF ${s.rows.filter((r) => r.role === "work").length}` : ""}</span></div><div class="countdown" id="countdown">${time(c.remaining)}</div><div class="countdown-label">${s.paused ? "Timer paused" : "remaining in this interval"}</div><div class="card hr-card"><div class="heart">♥ <span class="secondary">HEART RATE</span></div><div class="hr-value">${state.sensor === "connected" && !s.paused ? "162" : "—"} <small>bpm</small></div><div class="state-line ${state.sensor !== "connected" ? "warn" : ""}">${s.paused ? "Paused · HR excluded" : state.sensor === "connected" ? "Simulated reading · no sensor data" : sensorText()}</div></div></div><div><div class="settings-grid">${r.settings.speed != null ? `<div class="card"><small>ENTERED SPEED</small><div class="big-value">${r.settings.speed} <small>mph</small></div></div><div class="card"><small>ENTERED INCLINE</small><div class="big-value">${r.settings.incline} <small>%</small></div></div>` : `<div class="card"><small>ENTERED RESISTANCE</small><div class="big-value">${r.settings.resistance} <small>level</small></div></div><div class="card"><small>ENTERED CADENCE</small><div class="big-value">${r.settings.cadence} <small>rpm</small></div></div>`}</div><div class="card next-card row"><div class="stack"><small>UP NEXT</small><strong>${next ? `${label(next.role)} · ${time(next.plannedSeconds)}` : "Workout complete"}</strong></div><button class="text-button" data-action="edit-next">Edit Next</button></div><div class="row secondary"><span id="elapsed">${time(e)} active</span><span>${time(total(s.rows))} planned</span></div><div class="progress"><span id="progress" style="width:${(e / total(s.rows)) * 100}%"></span></div><div class="live-actions"><button class="primary" data-action="pause">${s.paused ? "▶ Resume" : "Ⅱ Pause"}</button><div class="row"><button data-action="add">＋ Add Interval</button><button class="danger" data-action="finish">Finish</button></div></div></div></div>`;
}
function historyView() {
  return (
    heading("History", `<span class="pill">SAMPLES</span>`) +
    `<p class="secondary">Your intervals, with the whole picture.</p>` +
    (state.empty || !history.length
      ? `<div class="empty"><span class="symbol">◷</span><h2>No workouts yet</h2><p class="secondary">Start a sample workout to explore<br>your timeline and interval details.</p><button data-action="go-train">Go to Timers</button></div>`
      : history
          .map(
            (w) =>
              `<button class="card history-card" data-action="detail" data-id="${esc(w.id)}"><div class="history-date">${esc(w.startedAt.slice(0, 10))} · ${esc(w.equipment.gym)}</div><div class="row"><h3>${esc(w.name)}</h3><span>›</span></div><div class="row"><span class="secondary">${time(w.activeSeconds)} · ${w.intervals.filter((r) => r.role === "work" && r.actualSeconds >= r.plannedSeconds).length} work intervals</span><span class="pill">${w.status === "partial" ? "PARTIAL" : "COMPLETED"}</span></div>${sequence(w.intervals)}</button>`,
          )
          .join(""))
  );
}
function metrics(w, index) {
  let start = w.intervals
      .slice(0, index)
      .reduce((n, r) => n + r.actualSeconds, 0),
    duration = w.intervals[index].actualSeconds,
    end = start + duration;
  let samples = w.samples.filter((p) => p.elapsed >= start && p.elapsed < end);
  let weight = 0,
    sum = 0;
  samples.forEach((p, i) => {
    let span = Math.max(
      0,
      Math.min(
        15,
        (samples[i + 1]?.elapsed ?? end) - p.elapsed,
        end - p.elapsed,
      ),
    );
    sum += p.bpm * span;
    weight += span;
  });
  let last = samples.at(-1);
  return {
    avg: weight ? Math.round(sum / weight) : "—",
    max: samples.length ? Math.max(...samples.map((p) => p.bpm)) : "—",
    end: last && end - last.elapsed <= 15 ? last.bpm : "—",
    coverage: duration ? Math.round((weight / duration) * 100) : 0,
  };
}
function graph(w) {
  const width = 310,
    height = 135,
    x = (e) => 30 + (e / Math.max(1, w.activeSeconds)) * 275,
    y = (hr) => 112 - ((hr - 90) / 100) * 95;
  let offset = 0;
  return `<svg viewBox="0 0 320 150" class="chart" role="img" aria-label="Heart rate aligned to intervals; choose an interval below for statistics">${[100, 140, 180].map((v) => `<line x1="30" x2="305" y1="${y(v)}" y2="${y(v)}" stroke="var(--line)"/><text x="0" y="${y(v) + 3}">${v}</text>`).join("")}${w.intervals
    .map((r, i) => {
      let start = offset;
      offset += r.actualSeconds;
      return `<rect data-action="interval" data-index="${i}" class="phase ${i === state.selected ? "chosen" : ""}" x="${x(start)}" y="10" width="${(r.actualSeconds / Math.max(1, w.activeSeconds)) * 275}" height="105" opacity="${r.role === "work" ? 1 : 0.3}"/>`;
    })
    .join(
      "",
    )}${w.gaps.map((g) => `<rect class="gap" x="${x(g.start)}" y="10" width="${((g.end - g.start) / Math.max(1, w.activeSeconds)) * 275}" height="105"/>`).join("")}${[
    ...new Set(w.samples.map((p) => p.segment)),
  ]
    .map(
      (seg) =>
        `<polyline class="hr-line" points="${w.samples
          .filter((p) => p.segment === seg)
          .map((p) => `${x(p.elapsed)},${y(p.bpm)}`)
          .join(" ")}"/>`,
    )
    .join(
      "",
    )}<text x="30" y="139">0:00</text><text x="270" y="139">${time(w.activeSeconds)}</text></svg>`;
}
function detailView() {
  const w = state.detail;
  state.selected = Math.min(state.selected, w.intervals.length - 1);
  const r = w.intervals[state.selected],
    m = metrics(w, state.selected);
  return (
    `<button class="text-button back" data-action="back-history">‹ History</button>` +
    heading(esc(w.name)) +
    `<div class="row"><span class="pill">${w.status.toUpperCase()} · SAMPLE</span><small>${esc(w.startedAt.slice(0, 10))}</small></div><div class="stat-grid"><div><small>ACTIVE TIME</small><strong>${time(w.activeSeconds)}</strong></div><div><small>WORK DONE</small><strong>${w.intervals.filter((r) => r.role === "work" && r.actualSeconds >= r.plannedSeconds).length}<small> / ${w.intervals.filter((r) => r.role === "work").length}</small></strong></div><div><small>HEALTH</small><strong style="font-size:17px">Local only</strong></div></div><div class="card"><div class="row"><h3>Heart rate</h3><small>bpm · active time</small></div>${graph(w)}<div class="secondary">${w.samples.length ? (w.gaps.length ? "Dashed area: missing HR. Tap an interval below." : "Illustrative sample readings. Tap an interval below.") : "No HR recorded for this sample session."}</div></div><div class="card"><div class="row"><strong>${label(r.role)}${r.repetition ? ` ${r.repetition}` : ""}</strong><small>${time(r.actualSeconds)} actual</small></div><p class="secondary">${esc(settingsText(r.settings))} · entered</p><div class="stat-grid"><div><small>AVERAGE</small><strong>${m.avg}</strong></div><div><small>MAXIMUM</small><strong>${m.max}</strong></div><div><small>END HR</small><strong>${m.end}</strong></div></div><small>${m.coverage}% sample coverage · preview metrics</small></div><div class="section-label">Intervals</div><div class="interval-list">${w.intervals.map((row, i) => `<button class="interval-row ${i === state.selected ? "chosen" : ""}" data-action="interval" data-index="${i}"><span>${label(row.role)} ${row.repetition ?? ""}</span><span>${time(row.actualSeconds)}</span><span>${esc(settingsText(row.settings))}</span></button>`).join("")}</div><div class="row" style="margin-top:20px"><button class="primary" data-action="copy">Copy Workout</button><button data-action="export">Export</button></div><p class="secondary">${esc(w.equipment.gym)} · ${esc(w.equipment.name)}<br>Sample data · never eligible for Health publishing.</p>`
  );
}
function settingsView() {
  return (
    heading("Settings") +
    `<div class="section-label">Workout preferences</div><div class="card"><div class="settings-row row"><span>Gym & equipment</span><button class="text-button" data-action="equipment">Edit ›</button></div><div class="settings-row row"><span>Apple Health</span><button class="text-button" data-action="health">Off ›</button></div><div class="settings-row row"><span>Copy profile</span><button class="text-button" data-action="copy-profile">AI summary ›</button></div><div class="settings-row"><span>HR zones</span><p class="secondary">Unset. Editable zone configuration follows in a later milestone.</p></div></div><div class="section-label">About this build</div><div class="card"><h3>CardioLog</h3><p class="secondary">Version 0.1.0 · Browser companion<br>Fixture schema 1 · Milestone 1</p><p class="secondary">This preview explores the native app’s layout and flow. Sensor capture, Health publishing, background cues, and iOS sharing are not connected.</p><button class="text-button" data-action="reset-history">Restore sample history</button></div>`
  );
}
function render() {
  const active = state.tab === "live";
  $("#screen").innerHTML = active
    ? live()
    : state.detail
      ? detailView()
      : state.tab === "train"
        ? state.showTemplates
          ? templateList()
          : train()
        : state.tab === "history"
          ? historyView()
          : settingsView();
  $("#tabs").innerHTML = active
    ? ""
    : ["train", "history", "settings"]
        .map(
          (tab, i) =>
            `<button data-action="tab" data-tab="${tab}" class="${state.tab === tab ? "active" : ""}" ${state.tab === tab ? 'aria-current="page"' : ""}><span aria-hidden="true">${["◴", "▤", "⚙"][i]}</span>${tab === "train" ? "Timers" : tab[0].toUpperCase() + tab.slice(1)}</button>`,
        )
        .join("");
  const setup = state.tab === "train" && !state.showTemplates && !state.detail;
  $("#start-dock").hidden = !setup;
  $("#start-dock").innerHTML = setup
    ? `<button class="primary" data-action="start"><span aria-hidden="true">▶</span> ${state.session ? "Return to workout" : "Start sample workout"}</button><small>Sample workout · Apple Health off</small>`
    : "";
  if (state.session && !active && !setup)
    $("#screen").insertAdjacentHTML(
      "afterbegin",
      '<button class="secondary-button" data-action="return-live">Return to active sample workout →</button>',
    );
}
function toast(text) {
  $("#toast").textContent = text;
  $("#toast").style.display = "block";
  setTimeout(() => ($("#toast").style.display = "none"), 3000);
}
function modal(title, body) {
  $("#sheet").innerHTML =
    `<div class="row"><h2>${title}</h2><button class="text-button" data-action="close" aria-label="Close">✕</button></div>${body}`;
  $("#sheet").showModal();
}
function close() {
  $("#sheet").close();
}
function start(elapsed = 0, paused = false, remember = true) {
  if (state.session) {
    state.tab = "live";
    render();
    return;
  }
  if (remember) rememberTemplate();
  state.session = {
    template: clone(state.template),
    equipment: clone(state.equipment),
    rows: expand(state.template),
    base: elapsed,
    anchor: performance.now(),
    paused,
    startedAt: new Date().toISOString(),
  };
  state.tab = "live";
  state.detail = null;
  render();
}
function save() {
  const s = state.session,
    e = elapsed();
  let remaining = e;
  const rows = s.rows.map((r) => {
    const actualSeconds = Math.min(r.plannedSeconds, Math.max(0, remaining));
    remaining -= actualSeconds;
    return { ...r, actualSeconds };
  });
  const w = {
    id: newID(),
    name: s.template.name,
    templateID: s.template.id,
    startedAt: s.startedAt,
    status: e >= total(s.rows) ? "completed" : "partial",
    isSimulation: true,
    equipment: s.equipment,
    activeSeconds: e,
    intervals: rows,
    samples: [],
    gaps: [],
    notes: "Simulated session. No sensor data was recorded.",
  };
  history.unshift(w);
  try {
    localStorage.setItem(storeKey, JSON.stringify(history));
    toast("Sample saved to preview history");
  } catch {
    toast("Browser storage unavailable; sample kept for this page only");
  }
  state.session = null;
  state.tab = "history";
  state.detail = w;
  state.empty = false;
  state.selected = 0;
  close();
  render();
}
function templateEditor(t = clone(state.template)) {
  modal(
    "Edit template",
    `<form id="template-form"><label>Name<input name="name" value="${esc(t.name)}" required maxlength="80"></label><div class="field-pair">${[
      ["warmupSeconds", "Warm-up (seconds)"],
      ["cooldownSeconds", "Cooldown (seconds)"],
      ["workSeconds", "Work (seconds)"],
      ["recoverySeconds", "Recovery (seconds)"],
    ]
      .map(
        ([key, title]) =>
          `<label>${title}<input name="${key}" type="number" min="${key === "workSeconds" ? 1 : 0}" max="36000" step="1" value="${t[key]}" required></label>`,
      )
      .join(
        "",
      )}</div><label>Repetitions<input name="repetitions" type="number" min="1" max="99" value="${t.repetitions}" required></label><label class="check"><input name="finalRecovery" type="checkbox" ${t.finalRecovery ? "checked" : ""}>Recovery after final repetition</label><div class="section-label">Entered work settings</div><div class="field-pair">${(t.activity ===
    "bike"
      ? [
          ["resistance", "Resistance level", 1],
          ["cadence", "Cadence (rpm)", 1],
        ]
      : [
          ["speed", "Speed (mph)", 0.1],
          ["incline", "Incline (%)", 0.5],
        ]
    )
      .map(
        ([key, title, step]) =>
          `<label>${title}<input name="work-${key}" type="number" min="0" max="250" step="${step}" value="${t.workSettings[key] ?? ""}"></label>`,
      )
      .join(
        "",
      )}</div><div class="section-label">Entered recovery settings</div><div class="field-pair">${(t.activity ===
    "bike"
      ? [
          ["resistance", "Recovery resistance", 1],
          ["cadence", "Recovery cadence (rpm)", 1],
        ]
      : [
          ["speed", "Recovery speed (mph)", 0.1],
          ["incline", "Recovery incline (%)", 0.5],
        ]
    )
      .map(
        ([key, title, step]) =>
          `<label>${title}<input name="recovery-${key}" type="number" min="0" max="250" step="${step}" value="${t.recoverySettings[key] ?? ""}"></label>`,
      )
      .join(
        "",
      )}</div><p class="secondary" id="template-total"></p><button class="primary">Save template</button></form>`,
  );
  const form = $("#template-form");
  const draft = () => {
    const data = new FormData(form),
      next = clone(t);
    for (const key of [
      "warmupSeconds",
      "cooldownSeconds",
      "workSeconds",
      "recoverySeconds",
      "repetitions",
    ])
      next[key] = Number(data.get(key));
    next.name = data.get("name").trim();
    next.finalRecovery = data.has("finalRecovery");
    for (const scope of ["work", "recovery"])
      for (const key of t.activity === "bike"
        ? ["resistance", "cadence"]
        : ["speed", "incline"]) {
        const value = data.get(`${scope}-${key}`);
        next[scope + "Settings"][key] = value === "" ? null : Number(value);
      }
    return next;
  };
  const preview = () =>
    ($("#template-total").textContent =
      `Planned active time: ${time(total(expand(draft())))}`);
  form.oninput = preview;
  preview();
  form.onsubmit = (e) => {
    e.preventDefault();
    const edited = draft();
    if (!edited.name) return;
    selectTemplate(edited);
    close();
    render();
  };
}
function equipmentChooser() {
  modal(
    "Gym & equipment",
    `<p class="secondary">Choose equipment for your ${state.template.activity === "bike" ? "bike" : "treadmill"} workout.</p>${library.equipment
      .filter((e) => e.activity === state.template.activity)
      .map(
        (e) =>
          `<button class="template-choice" data-action="choose-equipment" data-id="${e.id}"><span>${esc(e.name)}<br><small>${esc(e.gym)}</small></span><span>${e.id === state.equipment.id ? "✓" : "›"}</span></button>`,
      )
      .join("")}`,
  );
}
function editNext() {
  const s = state.session,
    indices = s.rows
      .map((r, i) => (r.role === "work" && i > current().index ? i : null))
      .filter((i) => i !== null);
  if (!indices.length) {
    modal(
      "No upcoming work",
      `<p>There are no future work intervals to edit.</p><button class="primary" data-action="add">Add Interval</button>`,
    );
    return;
  }
  const next = s.rows[indices[0]],
    bike = next.settings.speed == null;
  const fields = bike
    ? [
        ["resistance", "Resistance level", 0, 100, 1],
        ["cadence", "Cadence (rpm)", 0, 250, 1],
      ]
    : [
        ["speed", "Speed (mph)", 0, 30, 0.1],
        ["incline", "Incline (%)", 0, 40, 0.5],
      ];
  modal(
    "Edit next work",
    `<form id="next-form">${fields.map(([key, title, min, max, step]) => `<label>${title}<input type="number" name="${key}" min="${min}" max="${max}" step="${step}" value="${next.settings[key]}" required></label>`).join("")}<label>Apply to<select name="scope"><option value="remaining">Remaining work intervals</option><option value="next">Next work interval only</option></select></label><p id="affected" class="secondary"></p><p class="secondary">Current and completed settings stay frozen. Recovery settings stay unchanged.</p><button class="primary">Apply settings</button></form>`,
  );
  const form = $("#next-form");
  const update = () =>
    ($("#affected").textContent =
      `Changes work intervals: ${(form.elements.scope.value === "next" ? indices.slice(0, 1) : indices).map((i) => s.rows[i].repetition).join(", ")}`);
  form.onchange = update;
  update();
  form.onsubmit = (e) => {
    e.preventDefault();
    const indicesNow = indices.filter((i) => i > current().index);
    const affected =
      form.elements.scope.value === "next"
        ? indicesNow.slice(0, 1)
        : indicesNow;
    for (const i of affected)
      for (const [key] of fields)
        s.rows[i].settings[key] = Number(form.elements[key].value);
    close();
    render();
  };
}
function copyText(w) {
  let lines = [
    "CardioLog · SAMPLE DATA",
    w.name,
    `${w.startedAt} · ${w.status}`,
    `Active ${time(w.activeSeconds)} · ${w.intervals.filter((r) => r.role === "work" && r.actualSeconds >= r.plannedSeconds).length}/${w.intervals.filter((r) => r.role === "work").length} work intervals completed`,
  ];
  if (copyOptions.equipment)
    lines.push(`${w.equipment.gym} · ${w.equipment.name}`);
  w.intervals.forEach((r, i) => {
    if (!r.actualSeconds || (r.role !== "work" && !copyOptions.recovery))
      return;
    let row = `${label(r.role)} ${r.repetition ?? ""} · ${time(r.actualSeconds)}`;
    if (copyOptions.equipment)
      row += ` · ${settingsText(r.settings)} (entered)`;
    if (copyOptions.hr) {
      const m = metrics(w, i);
      row += ` · avg ${m.avg}, max ${m.max}, end ${m.end} bpm · ${m.coverage}% coverage`;
    }
    lines.push(row);
  });
  if (w.gaps.length)
    lines.push(`HR gaps: ${w.gaps.length}. Missing readings are not zero.`);
  if (copyOptions.notes && w.notes) lines.push(w.notes);
  return lines.join("\n");
}
function copySheet(profile = false) {
  const w = state.detail || library.workouts[0];
  modal(
    profile ? "Copy profile" : "Copy Workout",
    `<p class="secondary">AI summary · readable text</p><form id="copy-form">${[
      ["equipment", "Gym & entered equipment settings"],
      ["hr", "Average, maximum, end HR & coverage"],
      ["recovery", "Warm-up, recovery & cooldown rows"],
      ["notes", "Notes"],
    ]
      .map(
        ([key, title]) =>
          `<label class="check"><input name="${key}" type="checkbox" ${copyOptions[key] ? "checked" : ""}>${title}</label>`,
      )
      .join(
        "",
      )}<pre id="copy-preview"></pre><button class="primary">${profile ? "Save profile" : "Copy sample text"}</button></form>`,
  );
  const form = $("#copy-form");
  const update = () => {
    for (const key of Object.keys(copyOptions))
      copyOptions[key] = form.elements[key].checked;
    $("#copy-preview").textContent = copyText(w);
  };
  form.onchange = update;
  update();
  form.onsubmit = async (e) => {
    e.preventDefault();
    try {
      localStorage.setItem("cardiolog-copy-v1", JSON.stringify(copyOptions));
      if (!profile) await navigator.clipboard.writeText(copyText(w));
      close();
      toast(profile ? "Copy profile saved" : "Sample text copied");
    } catch {
      toast(
        "Select and copy the preview text; clipboard access is unavailable",
      );
    }
  };
}
function addInterval() {
  const s = state.session;
  if (!s) return;
  if (s.rows[current().index].role === "cooldown") {
    toast("Cooldown has begun; start another workout instead.");
    return;
  }
  const count = s.rows.filter((r) => r.role === "work").length,
    t = s.template;
  const work = {
    id: newID(),
    role: "work",
    repetition: count + 1,
    plannedSeconds: t.workSeconds,
    actualSeconds: 0,
    settings: clone(t.workSettings),
  };
  const recovery = {
    id: newID(),
    role: "recovery",
    repetition: t.finalRecovery ? count + 1 : count,
    plannedSeconds: t.recoverySeconds,
    actualSeconds: 0,
    settings: clone(t.recoverySettings),
  };
  const extra = t.recoverySeconds
    ? t.finalRecovery
      ? [work, recovery]
      : [recovery, work]
    : [work];
  let i = s.rows.findIndex((r) => r.role === "cooldown");
  if (i < 0) i = s.rows.length;
  s.rows.splice(i, 0, ...extra);
  close();
  render();
  toast(`Work ${count + 1} added · ${time(total(s.rows))} planned`);
}
function selectState(id) {
  const choice = library.states.find((s) => s.id === id);
  state.session = null;
  state.detail = null;
  state.empty = false;
  state.showTemplates = false;
  state.template = clone(library.templates[0]);
  state.equipment = clone(library.equipment[0]);
  state.sensor = choice.sensor;
  state.tab = "train";
  if (["work", "recovery", "paused", "no-hr", "disconnected"].includes(id))
    start(choice.elapsed, id === "paused", false);
  else if (id === "empty") {
    state.tab = "history";
    state.empty = true;
  } else if (["completed", "partial"].includes(id)) {
    state.tab = "history";
    state.detail = clone(library.workouts[id === "partial" ? 2 : 0]);
    state.selected = 1;
  }
  render();
}
document.addEventListener("click", (e) => {
  const button = e.target.closest("[data-action]");
  if (!button) return;
  const a = button.dataset.action;
  switch (a) {
    case "tab":
      state.tab = button.dataset.tab;
      if (state.tab === "train") state.showTemplates = true;
      state.detail = null;
      render();
      break;
    case "templates":
      state.showTemplates = true;
      state.detail = null;
      render();
      $("#screen").scrollTop = 0;
      break;
    case "select-template":
      selectTemplate(templates.find((t) => t.id === button.dataset.id));
      render();
      $("#screen").scrollTop = 0;
      break;
    case "template-options":
      modal(
        "Template options",
        `<button class="template-choice" data-action="edit-template">Edit template</button><button class="template-choice" data-action="duplicate">Duplicate template</button>`,
      );
      break;
    case "edit-template":
      close();
      templateEditor();
      break;
    case "duplicate":
      close();
      templateEditor({
        ...clone(state.template),
        id: newID(),
        name: state.template.name + " copy",
      });
      break;
    case "new-template":
      templateEditor({
        ...clone(library.templates[0]),
        id: newID(),
        name: "My workout",
        repetitions: 1,
      });
      break;
    case "equipment":
      equipmentChooser();
      break;
    case "choose-equipment":
      state.equipment = clone(
        library.equipment.find((x) => x.id === button.dataset.id),
      );
      state.template.equipmentID = state.equipment.id;
      rememberTemplate();
      close();
      render();
      break;
    case "sensor":
      modal(
        "Heart rate preview",
        `<p class="secondary">Simulated connection states. No Bluetooth access.</p>${[
          ["connected", "Polar H10 · connected"],
          ["none", "Continue without HR"],
          ["disconnected", "Disconnected / stale"],
        ]
          .map(
            ([id, text]) =>
              `<button class="template-choice" data-action="select-sensor" data-id="${id}">${text}</button>`,
          )
          .join("")}`,
      );
      break;
    case "select-sensor":
      state.sensor = button.dataset.id;
      close();
      render();
      break;
    case "health":
      modal(
        "Apple Health",
        `<p>Publishing is off for sample workouts.</p><p class="secondary">In the finished app, choose whether CardioLog or your Watch saves a real workout to Health. Starting without Health will always be available.</p><label class="check"><input type="checkbox" disabled>Publish this sample to Apple Health</label><p class="secondary">Sample data is never eligible.</p>`,
      );
      break;
    case "start":
      start();
      break;
    case "pause": {
      const s = state.session;
      s.base = elapsed();
      s.anchor = performance.now();
      s.paused = !s.paused;
      render();
      break;
    }
    case "minimize":
      state.showTemplates = false;
      state.tab = "train";
      render();
      break;
    case "return-live":
      state.tab = "live";
      render();
      break;
    case "edit-next":
      editNext();
      break;
    case "add":
      addInterval();
      break;
    case "finish":
      modal(
        "Finish this workout?",
        `<p>Your partial sample session will be saved with its actual active duration.</p><button class="primary" data-action="confirm-finish">Finish & save sample</button><button class="secondary-button" data-action="close">Keep going</button>`,
      );
      break;
    case "confirm-finish":
      save();
      break;
    case "detail":
      state.detail = history.find((w) => w.id === button.dataset.id);
      state.selected = 1;
      render();
      break;
    case "interval":
      state.selected = Number(button.dataset.index);
      render();
      break;
    case "back-history":
      state.detail = null;
      state.tab = "history";
      render();
      break;
    case "copy":
      copySheet();
      break;
    case "copy-profile":
      copySheet(true);
      break;
    case "export": {
      const blob = new Blob(
        [
          JSON.stringify(
            {
              schemaVersion: 1,
              kind: "cardiolog-preview",
              workout: state.detail,
            },
            null,
            2,
          ),
        ],
        { type: "application/json" },
      );
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "CardioLog-sample.json";
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      toast("Sample JSON exported · production export follows later");
      break;
    }
    case "go-train":
      state.showTemplates = true;
      state.tab = "train";
      state.detail = null;
      render();
      break;
    case "reset-history":
      history = clone(library.workouts);
      localStorage.setItem(storeKey, JSON.stringify(history));
      state.empty = false;
      toast("Sample history restored");
      break;
    case "close":
      close();
      break;
  }
});
$("#preview-state").innerHTML = library.states
  .map((s) => `<option value="${s.id}">${s.label}</option>`)
  .join("");
$("#preview-state").onchange = (e) => selectState(e.target.value);
$("#appearance").onchange = (e) =>
  $("#phone").classList.toggle("dark", e.target.value === "dark");
$("#orientation").onchange = (e) =>
  $("#phone").classList.toggle("landscape", e.target.value === "landscape");
let lastIndex = -1;
setInterval(() => {
  if (!state.session) return;
  if (elapsed() >= total(state.session.rows)) {
    save();
    return;
  }
  if (state.tab !== "live") return;
  const c = current();
  if (c.index !== lastIndex) {
    lastIndex = c.index;
    render();
  } else {
    $("#countdown").textContent = time(c.remaining);
    $("#elapsed").textContent = `${time(elapsed())} active`;
    $("#progress").style.width =
      `${(elapsed() / total(state.session.rows)) * 100}%`;
  }
}, 250);
const initial = new URLSearchParams(location.search).get("state");
if (library.states.some((s) => s.id === initial)) {
  $("#preview-state").value = initial;
  selectState(initial);
} else render();
