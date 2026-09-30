import { elevation, events, nextTransition, startOfDay } from './solar.js';
import { overlayColor, pageSetting, palette } from './theme.js';
import { SAN_FRANCISCO, initialLocation, locate, type ResolvedLocation } from './location.js';

const params = new URLSearchParams(location.search);
const fixedTime = params.get('at') ? new Date(params.get('at')!) : null;
let place: ResolvedLocation = initialLocation(params);
/** Set while the visitor scrubs or plays the day strip. */
let override: Date | null = null;
let playing = 0;
let tintOn = true;

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const root = document.documentElement;

const now = () => override ?? fixedTime ?? new Date();
const tz = () => place.timeZone ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
const clock = (d: Date | null) =>
  d ? new Intl.DateTimeFormat(undefined, { hour: 'numeric', minute: '2-digit', timeZone: tz() }).format(d) : '—';
const rgb = (c: { r: number; g: number; b: number }) =>
  `rgb(${Math.round(c.r * 255)} ${Math.round(c.g * 255)} ${Math.round(c.b * 255)})`;
const fmtCoord = (v: number, pos: string, neg: string) => `${Math.abs(v).toFixed(1)}° ${v >= 0 ? pos : neg}`;

function dayStart(at: Date) {
  return startOfDay(at, tz());
}

// ---- theme ----------------------------------------------------------------

function applyTheme(at: Date) {
  const { latitude, longitude } = place.coordinate;
  const el = elevation(at, latitude, longitude);
  const p = palette(el);
  const s = pageSetting(el);

  root.dataset.phase = p.phase;
  const vars: Record<string, string> = {
    '--sky-top': p.skyTop,
    '--sky-bottom': p.skyBottom,
    '--paper': p.paper,
    '--ink': p.ink,
    '--muted': p.muted,
    '--accent': p.accent,
    '--hero-ink': p.heroInk,
    '--darkness': p.darkness.toFixed(3),
    '--tint': tintOn ? rgb(overlayColor(el)) : 'rgb(255 255 255)',
  };
  for (const [k, v] of Object.entries(vars)) root.style.setProperty(k, v);
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', p.skyTop);

  // Almanac readouts
  const today = events(at, latitude, longitude, tz());
  const next = nextTransition(at, latitude, longitude);
  $('alm-place').textContent =
    place.source === 'default' ? 'San Francisco' : place.source === 'url' ? 'Pinned location' : 'Your location';
  $('alm-place-note').textContent =
    `${fmtCoord(latitude, 'N', 'S')} ${fmtCoord(longitude, 'E', 'W')}` +
    (place.source === 'default' ? ' · default' : '');
  $('alm-sun').textContent = `${el >= 0 ? '+' : '−'}${Math.abs(el).toFixed(1)}°`;
  $('alm-sun-note').textContent = { day: 'Daylight', golden: 'Golden hour', twilight: 'Twilight', night: 'Night' }[p.phase];
  $('alm-sunrise').textContent = clock(today.sunrise);
  $('alm-sunset').textContent = clock(today.sunset);
  $('alm-next').textContent = next ? `${next.kind === 'sunset' ? 'Sunset' : 'Sunrise'} ${clock(next.date)}` : 'Sun holds';
  $('alm-page').textContent = `${s.kelvin.toLocaleString()} K`;
  $('alm-page-note').textContent = `${Math.round(s.brightness * 100)}% brightness${tintOn ? '' : ' · tint off'}`;
  $('alm-time').textContent = override ? `Previewing ${clock(at)}` : clock(at);

  placeSun(at);
  markStrip(at);
}

// ---- hero sky -------------------------------------------------------------

/** Fraction of the hero's height where the horizon sits; set by layoutHorizon. */
let HORIZON = 0.6;

/** Put the horizon just above the hero text so the line never crosses it. */
function layoutHorizon() {
  const hero = $('hero').getBoundingClientRect();
  const eyebrow = document.querySelector('.hero .eyebrow')!.getBoundingClientRect();
  HORIZON = Math.min(0.8, Math.max(0.2, (eyebrow.top - hero.top - 36) / hero.height));
  root.style.setProperty('--horizon', HORIZON.toFixed(4));
}

function yFor(el: number) {
  // sin() lifts moderate elevations so the arc reads even in a shallow sky.
  return HORIZON - Math.sin((el * Math.PI) / 180) * (HORIZON - 0.09);
}

function drawArc(at: Date) {
  const { latitude, longitude } = place.coordinate;
  const start = dayStart(at).getTime();
  let d = '';
  for (let i = 0; i <= 96; i++) {
    const el = elevation(new Date(start + i * 900_000), latitude, longitude);
    d += `${i ? 'L' : 'M'}${(i / 96) * 1000},${yFor(el) * 1000} `;
  }
  $('sun-path').setAttribute('d', d.trim());
}

function placeSun(at: Date) {
  const { latitude, longitude } = place.coordinate;
  const el = elevation(at, latitude, longitude);
  const f = (at.getTime() - dayStart(at).getTime()) / 86_400_000;
  const sun = $('sun');
  sun.style.left = `${f * 100}%`;
  root.style.setProperty('--sun-x', `${f * 100}%`);
  sun.style.top = `${yFor(el) * 100}%`;
  sun.dataset.below = String(el < -0.833);
}

function drawStars() {
  const canvas = $<HTMLCanvasElement>('stars');
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  canvas.width = w * dpr;
  canvas.height = h * dpr;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.scale(dpr, dpr);
  let seed = 7;
  const rand = () => ((seed = (seed * 16807) % 2147483647) - 1) / 2147483646;
  const count = Math.round((w * h) / 2600);
  for (let i = 0; i < count; i++) {
    const x = rand() * w;
    const y = rand() * h * HORIZON;
    const r = rand() ** 3 * 1.6 + 0.3;
    ctx.globalAlpha = 0.35 + rand() * 0.65;
    ctx.fillStyle = rand() > 0.85 ? '#ffd9a8' : '#f4f1ff';
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fill();
  }
}

// ---- the day strip ----------------------------------------------------------

const SEGMENTS = 96;

function drawStrip(at: Date) {
  const { latitude, longitude } = place.coordinate;
  const start = dayStart(at).getTime();
  const sky = $('strip-sky');
  const warm = $('strip-warm');
  const skyStops: string[] = [];
  const warmStops: string[] = [];
  for (let i = 0; i <= SEGMENTS; i++) {
    const el = elevation(new Date(start + i * 900_000), latitude, longitude);
    const pct = ((i / SEGMENTS) * 100).toFixed(2);
    skyStops.push(`${palette(el).skyBottom} ${pct}%`);
    warmStops.push(`${rgb(overlayColor(el))} ${pct}%`);
  }
  sky.style.background = `linear-gradient(90deg, ${skyStops.join(', ')})`;
  warm.style.background = `linear-gradient(90deg, ${warmStops.join(', ')})`;

  const today = events(at, latitude, longitude, tz());
  const marks = $('strip-marks');
  marks.replaceChildren();
  const addMark = (d: Date | null, label: string, cls: string) => {
    if (!d) return;
    const m = document.createElement('span');
    m.className = `strip__mark ${cls}`;
    m.dataset.testid = `strip-mark-${cls}`;
    m.style.left = `${((d.getTime() - start) / 86_400_000) * 100}%`;
    m.textContent = `${label} ${clock(d)}`;
    marks.append(m);
  };
  addMark(today.sunrise, 'Sunrise', 'sunrise');
  addMark(today.sunset, 'Sunset', 'sunset');
}

function markStrip(at: Date) {
  const f = (at.getTime() - dayStart(at).getTime()) / 86_400_000;
  const handle = $('strip-now');
  handle.style.left = `${f * 100}%`;
  const strip = $('strip');
  strip.setAttribute('aria-valuenow', String(Math.round(f * 1440)));
  strip.setAttribute('aria-valuetext', clock(at));
  $('back-to-now').hidden = !override;
}

function scrubTo(fraction: number) {
  const base = fixedTime ?? new Date();
  override = new Date(dayStart(base).getTime() + Math.min(0.9999, Math.max(0, fraction)) * 86_400_000);
  applyTheme(override);
}

function backToNow() {
  cancelAnimationFrame(playing);
  playing = 0;
  override = null;
  $('play-day').textContent = 'Play the day';
  render();
}

function playDay() {
  if (playing) return backToNow();
  const base = fixedTime ?? new Date();
  const from = base.getTime();
  const began = performance.now();
  $('play-day').textContent = 'Stop';
  const step = (t: number) => {
    const f = (t - began) / 12000;
    if (f >= 1) return backToNow();
    override = new Date(from + f * 86_400_000);
    if (override.getTime() - dayStart(override).getTime() < 900_000 && f > 0.01) drawStrip(override);
    applyTheme(override);
    playing = requestAnimationFrame(step);
  };
  playing = requestAnimationFrame(step);
}

function wireStrip() {
  const strip = $('strip');
  const fractionAt = (e: PointerEvent) => {
    const r = strip.getBoundingClientRect();
    return (e.clientX - r.left) / r.width;
  };
  strip.addEventListener('pointerdown', (e) => {
    cancelAnimationFrame(playing);
    playing = 0;
    $('play-day').textContent = 'Play the day';
    strip.setPointerCapture(e.pointerId);
    scrubTo(fractionAt(e));
  });
  strip.addEventListener('pointermove', (e) => {
    if (strip.hasPointerCapture(e.pointerId)) scrubTo(fractionAt(e));
  });
  strip.addEventListener('keydown', (e) => {
    const at = now();
    const f = (at.getTime() - dayStart(at).getTime()) / 86_400_000;
    const delta = { ArrowRight: 1 / 96, ArrowLeft: -1 / 96, PageUp: 1 / 24, PageDown: -1 / 24 }[e.key];
    if (delta !== undefined) {
      e.preventDefault();
      scrubTo(f + delta);
    } else if (e.key === 'Escape') backToNow();
  });
  $('play-day').addEventListener('click', playDay);
  $('back-to-now').addEventListener('click', backToNow);
  $('tint-toggle').addEventListener('click', () => {
    tintOn = !tintOn;
    $('tint-toggle').setAttribute('aria-pressed', String(tintOn));
    $('tint-toggle').textContent = tintOn ? 'Page tint on' : 'Page tint off';
    applyTheme(now());
  });
}

// ---- lifecycle --------------------------------------------------------------

function render() {
  layoutHorizon();
  const at = now();
  drawArc(at);
  drawStrip(at);
  applyTheme(at);
}

function init() {
  $('year').textContent = String(new Date().getFullYear());
  wireStrip();
  render();
  drawStars();
  document.fonts?.ready.then(() => {
    render();
    drawStars();
  });
  root.classList.add('is-ready');

  setInterval(() => {
    if (!override) render();
  }, 60_000);
  let resize = 0;
  window.addEventListener('resize', () => {
    clearTimeout(resize);
    resize = window.setTimeout(() => {
      render();
      drawStars();
    }, 150);
  });

  if (place.source !== 'url' && params.get('loc') !== 'off') {
    $('alm-place-note').dataset.state = 'asking';
    locate(navigator.geolocation).then((found) => {
      $('alm-place-note').dataset.state = found ? 'granted' : 'default';
      if (!found) return;
      place = found;
      render();
    });
  }
}

// Exposed for debugging in the console and for automated checks.
(window as unknown as { nightglow: object }).nightglow = {
  get place() {
    return place;
  },
  get setting() {
    return pageSetting(elevation(now(), place.coordinate.latitude, place.coordinate.longitude));
  },
  SAN_FRANCISCO,
};

init();
