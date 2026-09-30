// Tests for the nightglow.io page logic (compiled TypeScript in dist/js).
// Run: yarn site-test
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { elevation, events } from '../dist/js/solar.js';
import { kelvinToRGB, pageSetting, phaseFor, palette, contrastRatio } from '../dist/js/theme.js';
import { SAN_FRANCISCO, initialLocation, locate } from '../dist/js/location.js';

const minutes = (a, b) => Math.abs(a.getTime() - b.getTime()) / 60000;

test('SF summer solstice sunrise and sunset match the Swift core', () => {
  const e = events(new Date('2024-06-21T12:00:00-07:00'), 37.7749, -122.4194, 'America/Los_Angeles');
  assert.ok(minutes(e.sunrise, new Date('2024-06-21T05:48:00-07:00')) < 3, `sunrise ${e.sunrise}`);
  assert.ok(minutes(e.sunset, new Date('2024-06-21T20:34:30-07:00')) < 3, `sunset ${e.sunset}`);
});

test('London winter solstice', () => {
  const e = events(new Date('2024-12-21T12:00:00Z'), 51.5074, -0.1278, 'Europe/London');
  assert.ok(minutes(e.sunrise, new Date('2024-12-21T08:04:00Z')) < 3);
  assert.ok(minutes(e.sunset, new Date('2024-12-21T15:53:00Z')) < 3);
});

test('polar night has neither sunrise nor sunset', () => {
  const e = events(new Date('2024-12-21T12:00:00+01:00'), 69.6492, 18.9553, 'Europe/Oslo');
  assert.equal(e.sunrise, null);
  assert.equal(e.sunset, null);
});

test('equinox noon elevation at the equator is about 90 degrees', () => {
  let max = -90;
  for (let m = 0; m < 1440; m++) {
    max = Math.max(max, elevation(new Date(Date.UTC(2026, 2, 20, 0, m)), 0, 0));
  }
  assert.ok(Math.abs(max - 90) < 1, `max ${max}`);
});

test('6500 K is neutral and warmer temperatures lose blue', () => {
  const w = kelvinToRGB(6500);
  for (const c of [w.r, w.g, w.b]) assert.ok(Math.abs(c - 1) < 0.001);
  const warm = kelvinToRGB(3400);
  assert.ok(warm.b < warm.g && warm.g < 1);
});

test('page setting follows the app schedule: day neutral, night warm and dimmed', () => {
  assert.deepEqual(pageSetting(30), { kelvin: 6500, brightness: 1 });
  const night = pageSetting(-20);
  assert.equal(night.kelvin, 3400);
  assert.ok(night.brightness < 1);
  const mid = pageSetting(-1.5);
  assert.ok(mid.kelvin > 3400 && mid.kelvin < 6500);
});

test('phases by solar elevation', () => {
  assert.equal(phaseFor(30), 'day');
  assert.equal(phaseFor(5), 'golden');
  assert.equal(phaseFor(-3), 'twilight');
  assert.equal(phaseFor(-10), 'night');
});

test('every phase palette keeps body text at WCAG AA contrast', () => {
  for (const el of [45, 20, 6, 1, -2, -5, -9, -20]) {
    const p = palette(el);
    assert.ok(contrastRatio(p.ink, p.paper) >= 4.5, `el ${el}: ${p.ink} on ${p.paper}`);
    assert.ok(contrastRatio(p.heroInk, p.skyBottom) >= 3, `hero el ${el}: ${p.heroInk} on ${p.skyBottom}`);
  }
});

test('no location permission means San Francisco', async () => {
  assert.deepEqual(SAN_FRANCISCO.coordinate, { latitude: 37.7749, longitude: -122.4194 });
  const start = initialLocation(new URLSearchParams(''));
  assert.equal(start.source, 'default');
  assert.deepEqual(start.coordinate, SAN_FRANCISCO.coordinate);

  const denied = { getCurrentPosition: (_ok, err) => err({ code: 1, message: 'User denied Geolocation' }) };
  assert.equal(await locate(denied), null);
  assert.equal(await locate(undefined), null);
});

test('granted permission uses the visitor position; URL overrides win', async () => {
  const granted = { getCurrentPosition: (ok) => ok({ coords: { latitude: 51.5, longitude: -0.12 } }) };
  const found = await locate(granted);
  assert.equal(found.source, 'geolocation');
  assert.deepEqual(found.coordinate, { latitude: 51.5, longitude: -0.12 });

  const forced = initialLocation(new URLSearchParams('lat=35.68&lon=139.69'));
  assert.equal(forced.source, 'url');
  assert.deepEqual(forced.coordinate, { latitude: 35.68, longitude: 139.69 });
});
