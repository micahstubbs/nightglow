#!/usr/bin/env node
// End-to-end check of the nightglow.io page in real Chrome (Playwright).
// Verifies the San Francisco fallback when location is denied, the visitor's
// position when granted, the day-strip scrubber, console errors, and saves
// screenshots of every section at desktop and phone widths.
//
// Usage: node scripts/verify-site.mjs [baseUrl] [outDir]
//   baseUrl defaults to http://localhost:8765/, outDir to build/site-shots
import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';

const base = process.argv[2] ?? 'http://localhost:8765/';
const out = process.argv[3] ?? 'build/site-shots';
mkdirSync(out, { recursive: true });

const results = [];
const check = (name, ok, detail = '') => {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${detail ? ` (${detail})` : ''}`);
};

const browser = await chromium.launch({ channel: 'chrome', headless: true });
const url = (q = '') => base + (base.includes('?') ? '&' : '?') + q;

async function page(ctxOptions, q, { width = 1440, height = 900 } = {}) {
  const ctx = await browser.newContext({ viewport: { width, height }, ...ctxOptions });
  const p = await ctx.newPage();
  const errors = [];
  p.on('pageerror', (e) => errors.push(e.message));
  p.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  await p.goto(url(q), { waitUntil: 'networkidle' });
  await p.evaluate(() => document.fonts.ready);
  return { ctx, p, errors };
}

// 1. Location denied -> San Francisco.
{
  const { ctx, p, errors } = await page({ permissions: [] }, '');
  await p.waitForFunction(() => document.getElementById('alm-place-note').dataset.state !== 'asking', null, {
    timeout: 20000,
  });
  const place = await p.evaluate(() => ({ ...window.nightglow.place, text: document.getElementById('alm-place').textContent }));
  check('denied location falls back to San Francisco', place.source === 'default' && place.text === 'San Francisco',
    `${place.text} ${place.coordinate.latitude},${place.coordinate.longitude}`);
  check('no page errors (denied)', errors.length === 0, errors.join(' | '));
  await ctx.close();
}

// 2. Location granted -> visitor position (London).
{
  const { ctx, p, errors } = await page(
    { permissions: ['geolocation'], geolocation: { latitude: 51.5074, longitude: -0.1278 } },
    '',
  );
  await p.waitForFunction(() => window.nightglow.place.source === 'geolocation', null, { timeout: 20000 });
  const text = await p.textContent('#alm-place-note');
  check('granted location is used', text.includes('51.5° N'), text);
  check('no page errors (granted)', errors.length === 0, errors.join(' | '));
  await ctx.close();
}

// 3. Theme follows the sun: fixed times over San Francisco.
const phases = {
  night: '2026-09-30T06:00:00Z',
  twilight: '2026-09-30T02:08:00Z',
  golden: '2026-09-30T01:30:00Z',
  day: '2026-09-29T20:00:00Z',
};
for (const [phase, at] of Object.entries(phases)) {
  const { ctx, p } = await page({}, `loc=off&at=${at}`);
  await p.waitForTimeout(2200); // colour transitions
  const got = await p.evaluate(() => ({
    phase: document.documentElement.dataset.phase,
    setting: window.nightglow.setting,
    tint: getComputedStyle(document.getElementById('tint')).backgroundColor,
  }));
  check(`${phase}: phase and tint`, got.phase === phase, `${got.phase}, ${got.setting.kelvin} K ${got.setting.brightness}, tint ${got.tint}`);
  await p.screenshot({ path: `${out}/hero-${phase}.png` });
  if (phase === 'day' || phase === 'night') {
    for (const id of ['the-day', 'features', 'shots', 'install']) {
      await p.locator(`#${id}`).scrollIntoViewIfNeeded();
      await p.waitForTimeout(300);
      await p.screenshot({ path: `${out}/${phase}-${id}.png` });
    }
  }
  await ctx.close();
}

// 4. Scrubbing the day strip previews another time, "Back to now" returns.
{
  const { ctx, p } = await page({}, 'loc=off&at=2026-09-30T06:00:00Z');
  check('"Back to now" hidden when live', !(await p.isVisible('#back-to-now')));
  const strip = p.locator('#strip');
  await strip.scrollIntoViewIfNeeded();
  const box = await strip.boundingBox();
  await p.mouse.click(box.x + box.width * 0.54, box.y + box.height / 2); // ~1 PM
  await p.waitForTimeout(400);
  const scrubbed = await p.evaluate(() => ({
    phase: document.documentElement.dataset.phase,
  }));
  scrubbed.back = await p.isVisible('#back-to-now');
  check('scrub to midday switches to day', scrubbed.phase === 'day' && scrubbed.back, JSON.stringify(scrubbed));
  await p.click('#back-to-now');
  await p.waitForTimeout(300);
  const back = await p.evaluate(() => document.documentElement.dataset.phase);
  check('back to now restores night', back === 'night' && !(await p.isVisible('#back-to-now')), back);
  await ctx.close();
}

// 5. Phone width: no horizontal scroll.
{
  const { ctx, p } = await page({}, 'loc=off', { width: 390, height: 844 });
  await p.waitForTimeout(1500);
  const overflow = await p.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  check('no horizontal scroll at 390 px', overflow <= 0, `overflow ${overflow}px`);
  await p.screenshot({ path: `${out}/mobile-hero.png` });
  await p.screenshot({ path: `${out}/mobile-full.png`, fullPage: true });
  await ctx.close();
}

await browser.close();
const failed = results.filter((r) => !r.ok).length;
console.log(`${results.length - failed}/${results.length} checks passed; screenshots in ${out}`);
process.exit(failed ? 1 : 0);
