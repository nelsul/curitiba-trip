// Weather forecast for the trip days (GET /api/weather), shared by the server and the browser.

export type WeatherKind = 'sun' | 'partly' | 'cloud' | 'fog' | 'rain' | 'storm';
export type WeatherHour = { time: string; temp: number; rain: number; kind: WeatherKind };
export type WeatherDay = { date: string; min: number; max: number; rain: number; kind: WeatherKind; hours: WeatherHour[] };

/** WMO weather codes (Open-Meteo) → the icon we draw. */
export function weatherKind(code: number): WeatherKind {
	if (code <= 1) return 'sun';
	if (code === 2) return 'partly';
	if (code === 3) return 'cloud';
	if (code === 45 || code === 48) return 'fog';
	if (code >= 95) return 'storm';
	return 'rain';
}

export const WEATHER_LABEL: Record<WeatherKind, string> = {
	sun: 'Sol',
	partly: 'Sol entre nuvens',
	cloud: 'Nublado',
	fog: 'Neblina',
	rain: 'Chuva',
	storm: 'Tempestade'
};
