// Sun position from the NOAA solar calculator equations
// (https://gml.noaa.gov/grad/solcalc/calcdetails.html). Port of
// Sources/NightglowCore/Solar.swift so the page and the app agree.
export const SUNRISE_ALTITUDE = -0.833;
const rad = (d) => (d * Math.PI) / 180;
const deg = (r) => (r * 180) / Math.PI;
/** Geometric elevation of the sun above the horizon, in degrees. */
export function elevation(date, latitude, longitude) {
    const unix = date.getTime() / 1000;
    const t = (unix / 86400 + 2440587.5 - 2451545) / 36525;
    const meanLongitude = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360;
    const m = rad(357.52911 + t * (35999.05029 - 0.0001537 * t));
    const e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    const center = Math.sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        Math.sin(2 * m) * (0.019993 - 0.000101 * t) +
        Math.sin(3 * m) * 0.000289;
    const omega = rad(125.04 - 1934.136 * t);
    const apparent = meanLongitude + center - 0.00569 - 0.00478 * Math.sin(omega);
    const meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
    const obliquity = rad(meanObliquity + 0.00256 * Math.cos(omega));
    const declination = Math.asin(Math.sin(obliquity) * Math.sin(rad(apparent)));
    const y = Math.tan(obliquity / 2) ** 2;
    const l0 = rad(meanLongitude);
    const equationOfTime = 4 *
        deg(y * Math.sin(2 * l0) -
            2 * e * Math.sin(m) +
            4 * e * y * Math.sin(m) * Math.cos(2 * l0) -
            0.5 * y * y * Math.sin(4 * l0) -
            1.25 * e * e * Math.sin(2 * m));
    const utcMinutes = (unix / 60) % 1440;
    let trueSolar = (utcMinutes + equationOfTime + 4 * longitude) % 1440;
    if (trueSolar < 0)
        trueSolar += 1440;
    const hourAngle = rad(trueSolar / 4 - 180);
    const lat = rad(latitude);
    const cosZenith = Math.sin(lat) * Math.sin(declination) + Math.cos(lat) * Math.cos(declination) * Math.cos(hourAngle);
    return 90 - deg(Math.acos(Math.min(1, Math.max(-1, cosZenith))));
}
/** Crossings of the sunrise altitude in [start, end): 10-minute scan, then bisection. */
export function transitions(start, end, latitude, longitude) {
    const h = (ms) => elevation(new Date(ms), latitude, longitude) - SUNRISE_ALTITUDE;
    const out = [];
    let a = start.getTime();
    let ha = h(a);
    const stop = end.getTime();
    while (a < stop) {
        const b = Math.min(a + 600_000, stop);
        const hb = h(b);
        if (ha < 0 !== hb < 0) {
            let lo = a;
            let hi = b;
            while (hi - lo > 500) {
                const mid = (lo + hi) / 2;
                if (h(mid) < 0 === ha < 0)
                    lo = mid;
                else
                    hi = mid;
            }
            out.push({ kind: ha < 0 ? 'sunrise' : 'sunset', date: new Date(hi) });
        }
        a = b;
        ha = hb;
    }
    return out;
}
/** Start of the calendar day containing `date` in an IANA time zone. */
export function startOfDay(date, timeZone) {
    const parts = new Intl.DateTimeFormat('en-US', {
        timeZone,
        hourCycle: 'h23',
        hour: 'numeric',
        minute: 'numeric',
        second: 'numeric',
    }).formatToParts(date);
    const get = (t) => Number(parts.find((p) => p.type === t)?.value ?? 0);
    const sinceMidnight = (get('hour') * 3600 + get('minute') * 60 + get('second')) * 1000;
    return new Date(Math.floor(date.getTime() / 1000) * 1000 - sinceMidnight);
}
/** Sunrise and sunset on the local day containing `day`; null in polar day or night. */
export function events(day, latitude, longitude, timeZone) {
    const start = startOfDay(day, timeZone);
    // 24 h is close enough for DST days: a transition is never within an hour of midnight
    // except near the poles, where the next-day scan below still finds it.
    const list = transitions(start, new Date(start.getTime() + 86_400_000), latitude, longitude);
    return {
        sunrise: list.find((t) => t.kind === 'sunrise')?.date ?? null,
        sunset: list.find((t) => t.kind === 'sunset')?.date ?? null,
    };
}
export function nextTransition(after, latitude, longitude) {
    return transitions(after, new Date(after.getTime() + 2 * 86_400_000), latitude, longitude)[0] ?? null;
}
