// Page theme from solar elevation: a continuous sky gradient, a discrete
// phase palette for readable text, and the app's own colour-temperature and
// brightness schedule applied to the page as a multiply overlay.
export const DAY = { kelvin: 6500, brightness: 1 };
export const NIGHT = { kelvin: 3400, brightness: 0.86 };
const DAY_ELEVATION = 3;
const NIGHT_ELEVATION = -6;
function helland(kelvin) {
    const t = kelvin / 100;
    const clamp = (v) => Math.min(255, Math.max(0, v));
    const r = t <= 66 ? 255 : 329.698727446 * (t - 60) ** -0.1332047592;
    const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * (t - 60) ** -0.0755148492;
    const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
    return { r: clamp(r), g: clamp(g), b: clamp(b) };
}
const NEUTRAL = helland(6500);
/** Same curve as ColorTemperature.rgb in the Swift core: 6500 K = (1, 1, 1). */
export function kelvinToRGB(kelvin) {
    const k = Math.min(10000, Math.max(1200, kelvin));
    const raw = helland(k);
    const c = { r: raw.r / NEUTRAL.r, g: raw.g / NEUTRAL.g, b: raw.b / NEUTRAL.b };
    const peak = Math.max(c.r, c.g, c.b);
    return { r: c.r / peak, g: c.g / peak, b: c.b / peak };
}
export function dayFraction(elevation) {
    if (elevation >= DAY_ELEVATION)
        return 1;
    if (elevation <= NIGHT_ELEVATION)
        return 0;
    return (elevation - NIGHT_ELEVATION) / (DAY_ELEVATION - NIGHT_ELEVATION);
}
export function pageSetting(elevation) {
    const f = dayFraction(elevation);
    return {
        kelvin: Math.round(NIGHT.kelvin + (DAY.kelvin - NIGHT.kelvin) * f),
        brightness: Math.round((NIGHT.brightness + (DAY.brightness - NIGHT.brightness) * f) * 1000) / 1000,
    };
}
/** Per-channel multipliers, exactly what the app writes into the gamma table. */
export function overlayColor(elevation) {
    const s = pageSetting(elevation);
    const c = kelvinToRGB(s.kelvin);
    return { r: c.r * s.brightness, g: c.g * s.brightness, b: c.b * s.brightness };
}
export function phaseFor(elevation) {
    if (elevation >= 10)
        return 'day';
    if (elevation >= 0)
        return 'golden';
    if (elevation >= -6)
        return 'twilight';
    return 'night';
}
// Sky gradient keyframes by elevation (top of sky, horizon glow).
const SKY = [
    [-18, '#04050d', '#0b1029'],
    [-12, '#070b24', '#18214a'],
    [-8, '#10163d', '#3a2f63'],
    [-4, '#1d2356', '#8a4a6a'],
    [-1, '#2e3c7c', '#e0704f'],
    [2, '#4a64a8', '#f2a257'],
    [7, '#6a97d2', '#f6cf98'],
    [15, '#5d9be2', '#d8ebf6'],
    [40, '#3f88dc', '#c4e2f8'],
];
const PALETTES = {
    day: { paper: '#f8f1e4', ink: '#22170f', muted: '#6b5a49', accent: '#c4531a', heroInk: '#1b2233' },
    golden: { paper: '#fbeedd', ink: '#2a180c', muted: '#735641', accent: '#b8460f', heroInk: '#2a180c' },
    twilight: { paper: '#1c1426', ink: '#f6e7d8', muted: '#c8b3c2', accent: '#ff9a5a', heroInk: '#fff4ea' },
    night: { paper: '#0b0d1c', ink: '#eee4d2', muted: '#a9a3b8', accent: '#ffb35c', heroInk: '#f3ead9' },
};
const hex = (s) => ({
    r: parseInt(s.slice(1, 3), 16),
    g: parseInt(s.slice(3, 5), 16),
    b: parseInt(s.slice(5, 7), 16),
});
const toHex = (c) => '#' + [c.r, c.g, c.b].map((v) => Math.round(v).toString(16).padStart(2, '0')).join('');
const mix = (a, b, f) => {
    const x = hex(a);
    const y = hex(b);
    return toHex({ r: x.r + (y.r - x.r) * f, g: x.g + (y.g - x.g) * f, b: x.b + (y.b - x.b) * f });
};
function sky(elevation) {
    if (elevation <= SKY[0][0])
        return [SKY[0][1], SKY[0][2]];
    for (let i = 1; i < SKY.length; i++) {
        const [e1, t1, b1] = SKY[i];
        const [e0, t0, b0] = SKY[i - 1];
        if (elevation <= e1) {
            const f = (elevation - e0) / (e1 - e0);
            return [mix(t0, t1, f), mix(b0, b1, f)];
        }
    }
    const last = SKY[SKY.length - 1];
    return [last[1], last[2]];
}
export function palette(elevation) {
    const phase = phaseFor(elevation);
    const [skyTop, skyBottom] = sky(elevation);
    const darkness = Math.min(1, Math.max(0, (-elevation - 4) / 10));
    return { phase, skyTop, skyBottom, darkness, ...PALETTES[phase] };
}
function luminance(color) {
    const c = hex(color);
    const lin = (v) => {
        const s = v / 255;
        return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
    };
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}
export function contrastRatio(a, b) {
    const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
    return (x + 0.05) / (y + 0.05);
}
