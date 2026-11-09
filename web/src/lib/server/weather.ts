import { CURITIBA, TRIP_DAYS } from '$lib/trip';
import { TZ } from '$lib/format';
import { weatherKind, type WeatherDay } from '$lib/weather';

const TTL = 30 * 60_000;
let cache: { at: number; days: WeatherDay[] } | null = null;

type OpenMeteo = {
	hourly: { time: string[]; temperature_2m: number[]; precipitation_probability: (number | null)[]; weather_code: number[] };
	daily: { time: string[]; temperature_2m_min: number[]; temperature_2m_max: number[]; precipitation_probability_max: (number | null)[]; weather_code: number[] };
};

/**
 * Hour-by-hour forecast for Curitiba on the trip days that the forecast reaches (Open-Meteo, free, no key;
 * about 16 days ahead). Cached for 30 minutes; an empty list when the service is down.
 */
export async function tripWeather(): Promise<{ days: WeatherDay[]; updatedAt: string | null }> {
	if (cache && Date.now() - cache.at < TTL) return { days: cache.days, updatedAt: new Date(cache.at).toISOString() };
	const params = new URLSearchParams({
		latitude: String(CURITIBA.lat),
		longitude: String(CURITIBA.lng),
		hourly: 'temperature_2m,precipitation_probability,weather_code',
		daily: 'temperature_2m_min,temperature_2m_max,precipitation_probability_max,weather_code',
		timezone: TZ,
		forecast_days: '16',
		past_days: '7'
	});
	try {
		const res = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`, { signal: AbortSignal.timeout(8000) });
		if (!res.ok) throw new Error(String(res.status));
		const d = (await res.json()) as OpenMeteo;
		const days: WeatherDay[] = d.daily.time
			.map((date, i) => ({
				date,
				min: Math.round(d.daily.temperature_2m_min[i]),
				max: Math.round(d.daily.temperature_2m_max[i]),
				rain: d.daily.precipitation_probability_max[i] ?? 0,
				kind: weatherKind(d.daily.weather_code[i]),
				hours: d.hourly.time
					.map((t, j) => ({ t, j }))
					.filter(({ t }) => t.startsWith(date))
					.map(({ t, j }) => ({
						time: t.slice(11, 16),
						temp: Math.round(d.hourly.temperature_2m[j]),
						rain: d.hourly.precipitation_probability[j] ?? 0,
						kind: weatherKind(d.hourly.weather_code[j])
					}))
			}))
			.filter((day) => TRIP_DAYS.includes(day.date) && Number.isFinite(day.min));
		cache = { at: Date.now(), days };
		return { days, updatedAt: new Date(cache.at).toISOString() };
	} catch (e) {
		console.error('[weather]', (e as Error).message);
		return { days: cache?.days ?? [], updatedAt: cache ? new Date(cache.at).toISOString() : null };
	}
}
