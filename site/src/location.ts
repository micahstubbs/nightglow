// Where the visitor is. San Francisco until (and unless) the browser grants
// a position; URL parameters override both for testing and sharing.

export interface Coordinate {
  latitude: number;
  longitude: number;
}

export type LocationSource = 'default' | 'geolocation' | 'url';

export interface ResolvedLocation {
  coordinate: Coordinate;
  source: LocationSource;
  label: string;
  timeZone?: string;
}

export const SAN_FRANCISCO: ResolvedLocation = {
  coordinate: { latitude: 37.7749, longitude: -122.4194 },
  source: 'default',
  label: 'San Francisco',
  timeZone: 'America/Los_Angeles',
};

/** ?lat=..&lon=.. pins a position; otherwise start from San Francisco. */
export function initialLocation(params: URLSearchParams): ResolvedLocation {
  const lat = Number(params.get('lat'));
  const lon = Number(params.get('lon'));
  if (params.has('lat') && params.has('lon') && Math.abs(lat) <= 90 && Math.abs(lon) <= 180) {
    return { coordinate: { latitude: lat, longitude: lon }, source: 'url', label: 'Pinned location' };
  }
  return SAN_FRANCISCO;
}

type Geo = Pick<Geolocation, 'getCurrentPosition'>;

/**
 * Ask the browser for a coarse position. Resolves null when geolocation is
 * missing, denied, or times out, so the caller keeps San Francisco.
 */
export function locate(geo: Geo | undefined, timeoutMs = 15000): Promise<ResolvedLocation | null> {
  if (!geo) return Promise.resolve(null);
  return new Promise((resolve) => {
    // The browser timeout only starts after the permission prompt is
    // answered; this one also covers a prompt that is ignored.
    const timer = setTimeout(() => resolve(null), timeoutMs);
    try {
      geo.getCurrentPosition(
        (pos) => {
          clearTimeout(timer);
          resolve({
            coordinate: { latitude: pos.coords.latitude, longitude: pos.coords.longitude },
            source: 'geolocation',
            label: 'Your location',
          });
        },
        () => {
          clearTimeout(timer);
          resolve(null);
        },
        { enableHighAccuracy: false, maximumAge: 3_600_000, timeout: timeoutMs },
      );
    } catch {
      clearTimeout(timer);
      resolve(null);
    }
  });
}
