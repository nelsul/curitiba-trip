// Itinerary from ESPECIFICACAO-viagem-curitiba.md (sections 6.2 and 6.3). Read-only for now.

export type Transport = 'onibus' | 'turismo' | 'uber' | 'pe' | 'rodo';

export const TRANSPORT: Record<Transport, { label: string; color: string }> = {
	onibus: { label: '🚌 Ônibus', color: 'var(--bus)' },
	turismo: { label: '🚍 Linha Turismo', color: 'var(--leaf)' },
	uber: { label: '🚗 Uber', color: 'var(--plum)' },
	pe: { label: '🚶 A pé', color: 'var(--coral)' },
	rodo: { label: '🚌 Ônibus Graciosa', color: 'var(--bus)' }
};

export type Place = { name: string; placeId: string; lat: number; lng: number; hours: string };

export const PLACES: Record<string, Place> = {
	aero: { name: 'Aeroporto Afonso Pena', placeId: 'ChIJcdlncM3w3JQR4ukUUzTbuiI', lat: -25.5314995, lng: -49.1740261, hours: '' },
	boca: { name: 'Rua XV de Novembro (Boca Maldita)', placeId: 'ChIJOU7yqHLk3JQRwaNi8DNGXSc', lat: -25.4322355, lng: -49.2741782, hours: '24 h' },
	alemao: { name: 'Bar do Alemão', placeId: 'ChIJc3cRQRLk3JQRwZm09a0UJpg', lat: -25.4278958, lng: -49.2726731, hours: '11h–0h (sex/sáb até 1h)' },
	mercado: { name: 'Mercado Municipal', placeId: 'ChIJnYfZ7ETk3JQRKsDrOXtHVTU', lat: -25.4345052, lng: -49.2569728, hours: 'fecha seg; ter–sáb 8h–18h; dom 8h–13h' },
	passeio: { name: 'Passeio Público', placeId: 'ChIJVbyydhTk3JQR3rEscng0WJ4', lat: -25.4253475, lng: -49.2674245, hours: 'fecha seg; 6h–20h' },
	mon: { name: 'Museu Oscar Niemeyer', placeId: 'ChIJFWlvqB_k3JQR7jsyAF9M8vU', lat: -25.4098994, lng: -49.2670599, hours: 'fecha seg; 10h–17h30' },
	papa: { name: 'Bosque do Papa (Memorial Polonês)', placeId: 'ChIJW9u3WKfm3JQRJByOR4G7a-s', lat: -25.4089001, lng: -49.2701858, hours: '9h–17h' },
	jb: { name: 'Jardim Botânico', placeId: 'ChIJNWbp1QDl3JQRVFbc_cVeLRo', lat: -25.4421565, lng: -49.2413194, hours: '6h–19h30' },
	opera: { name: 'Ópera de Arame', placeId: 'ChIJ9VsTK2jn3JQRkEQgTpixey4', lat: -25.3845574, lng: -49.2761701, hours: 'fecha seg; 10h–17h50' },
	tangua: { name: 'Parque Tanguá', placeId: 'ChIJQSAIRdTm3JQR3EBLwWaWlGk', lat: -25.3790661, lng: -49.2824233, hours: '6h–20h' },
	madalosso: { name: 'Família Madalosso', placeId: 'ChIJs7Vq1qbh3JQRZbRtpxTPEqo', lat: -25.4053748, lng: -49.3283393, hours: 'fecha ter; jantar 18h30–21h30' },
	feira: { name: 'Feira do Largo da Ordem', placeId: 'ChIJx6v1b9rl3JQR_wcfFySkTEE', lat: -25.4276922, lng: -49.2737548, hours: 'só dom 9h–14h' },
	barigui: { name: 'Parque Barigui', placeId: 'ChIJp1_LiN_j3JQRUx7PRRpC7WQ', lat: -25.4262654, lng: -49.30723, hours: '24 h' },
	rodo: { name: 'Rodoferroviária de Curitiba', placeId: 'ChIJyXejqlzk3JQRPYQPbvYowKQ', lat: -25.4368387, lng: -49.2574368, hours: '24 h' },
	pontevelha: { name: 'Restaurante Ponte Velha (Morretes)', placeId: 'ChIJncyZXAyH3JQRYUSekHLhzj4', lat: -25.4753473, lng: -48.8332441, hours: 'fecha qua; 11h–15h30' },
	bosque: { name: 'Bosque Alemão', placeId: 'ChIJxYnV2Qf73JQR0ASXvKNB7mA', lat: -25.4044672, lng: -49.288116, hours: '8h–20h' },
	ucraniano: { name: 'Memorial Ucraniano (Parque Tingui)', placeId: 'ChIJbxAI75nh3JQRKOUFy2ddHf0', lat: -25.4023741, lng: -49.3049066, hours: '10h–12h e 13h–18h' },
	anarco: { name: 'Anarco Batel', placeId: 'ChIJh2wM3iTj3JQRmW0tV09xFNA', lat: -25.4397929, lng: -49.2964735, hours: 'fecha seg; jantar 18h–22h (dom só almoço)' }
};

export type Stop = { time: string; place?: keyof typeof PLACES; label?: string; transport: Transport; note: string };
export type Day = { date: string; title: string; who: string; lead: string; wedding?: boolean; stops: Stop[] };

export const DAYS: Day[] = [
	{
		date: '2026-11-11', title: 'Chegada e centro histórico',
		who: 'Emmus de manhã; Esther & Nelson e Carlos à noite.',
		lead: 'Do aeroporto, sempre de Uber: com mala não compensa o ônibus.',
		stops: [
			{ time: '9h35', place: 'aero', transport: 'uber', note: 'Uber até o hotel (cerca de 35 min). Esther & Nelson dividem o mesmo carro.' },
			{ time: '14h', place: 'boca', transport: 'pe', note: 'Emmus: passeio pela Rua XV, o calçadão do centro.' },
			{ time: '20h30', place: 'alemao', transport: 'pe', note: 'Jantar do grupo. Peça a carne de onça, clássico de Curitiba. Aberto até meia-noite.' }
		]
	},
	{
		date: '2026-11-12', title: 'Mercado, parques e museu',
		who: 'Esther & Nelson, Carlos e Emmus; Icaro & Lilian a partir da tarde.',
		lead: 'Icaro & Lilian encontram o grupo à tarde no museu.',
		stops: [
			{ time: '10h', place: 'mercado', transport: 'pe', note: 'Café, produtos locais e almoço na praça de alimentação do 2º andar.' },
			{ time: '13h30', place: 'passeio', transport: 'onibus', note: 'O parque mais antigo da cidade, cheio de aves. Também dá para ir a pé (20 min).' },
			{ time: '14h30', place: 'mon', transport: 'onibus', note: 'O Museu do Olho, cerca de 10 min de ônibus. Icaro & Lilian vão de Uber direto do aeroporto.' },
			{ time: '17h', place: 'papa', transport: 'pe', note: 'Bosque do Papa, ao lado do museu. Depois, jantar no Batel (Uber, uns R$ 20 por carro).' }
		]
	},
	{
		date: '2026-11-13', title: 'Linha Turismo com todo mundo',
		who: 'Todos juntos (Bruna a partir das 10h30).',
		lead: 'Comprem o cartão da Linha Turismo (R$ 50, vale 24 horas). Os ônibus passam a cada 30 min, até o fim da tarde.',
		stops: [
			{ time: '11h', place: 'jb', transport: 'turismo', note: 'A famosa estufa. Almoço no bufê dentro do parque.' },
			{ time: '14h30', place: 'opera', transport: 'turismo', note: 'Teatro de aço e vidro sobre o lago de uma pedreira.' },
			{ time: '16h30', place: 'tangua', transport: 'turismo', note: 'Fiquem para o pôr do sol no mirante (por volta das 18h50).' },
			{ time: '19h30', place: 'madalosso', transport: 'uber', note: '2 carros, cerca de 20 min; a Linha Turismo já parou nesse horário. Rodízio italiano em Santa Felicidade. Voltem cedo: o casamento é amanhã. Volta de Uber.' }
		]
	},
	{
		date: '2026-11-14', title: 'Dia do casamento', wedding: true,
		who: 'Todos.',
		lead: 'Dia inteiro dedicado ao casamento: salão, preparativos e festa. Nada de passeios.',
		stops: [
			{ time: 'Ida e volta', label: 'Salão do casamento', transport: 'uber', note: 'Dividam os carros, 4 por carro (cerca de R$ 20 por pessoa no total). Combinem a volta antes de a festa acabar.' },
			{ time: 'Madrugada do dia 15', label: 'Carlos vai para o aeroporto', transport: 'uber', note: 'Voo às 4h25. Sair da festa por volta das 2h30 com a mala já pronta.' }
		]
	},
	{
		date: '2026-11-15', title: 'Descanso e feira de domingo',
		who: 'Todos, menos Carlos.',
		lead: 'O voo do Carlos é às 4h25: Uber direto da festa. Durmam até mais tarde. Ônibus a R$ 3 (domingo e feriado).',
		stops: [
			{ time: '11h', place: 'feira', transport: 'pe', note: 'Só aos domingos, das 9h às 14h. Brunch nas barracas (pastel!).' },
			{ time: '14h30', place: 'barigui', transport: 'onibus', note: 'Cerca de 25 min de ônibus. Tarde tranquila no lago, com as capivaras.' }
		]
	},
	{
		date: '2026-11-16', title: 'Bate-volta a Morretes',
		who: 'Todos, menos Carlos.',
		lead: 'De ônibus da Viação Graciosa: cerca de 1h20 e R$ 47 por trecho, 7 saídas por dia. Comprem ida e volta antes.',
		stops: [
			{ time: '8h30', place: 'rodo', transport: 'uber', note: 'Uber até a rodoviária (uns R$ 20 por carro) e ônibus Graciosa para Morretes.' },
			{ time: '11h30', place: 'pontevelha', transport: 'rodo', note: 'Barreado, o prato típico, com vista para o rio. Aberto às segundas (fecha às quartas). Depois, passeio pelo centro histórico e ônibus de volta por volta das 16h.' }
		]
	},
	{
		date: '2026-11-17', title: 'Bosques, memoriais e despedida',
		who: 'Todos, menos Carlos (último dia de Bruna, Icaro & Lilian).',
		lead: 'Esses lugares são espalhados e o ônibus não liga bem: vão de Uber entre eles (R$ 15–30 por carro a cada trecho).',
		stops: [
			{ time: '10h', place: 'bosque', transport: 'uber', note: 'Trilha na mata, torre-mirante e a confeitaria alemã Erika.' },
			{ time: '12h', place: 'ucraniano', transport: 'uber', note: 'Cerca de 5 min de Uber. Igreja ucraniana dentro do Parque Tingui. Depois, almoço pelo Batel.' },
			{ time: '19h30', place: 'anarco', transport: 'uber', note: 'Jantar de despedida. Reservem antes. Bruna, Icaro & Lilian: Uber para o aeroporto por volta de 1h20 (dividam o carro, é o mesmo voo).' }
		]
	},
	{
		date: '2026-11-18', title: 'Última manhã',
		who: 'Esther & Nelson até 15h40; Emmus até 18h30.',
		lead: 'Manhã leve antes de ir para o aeroporto.',
		stops: [
			{ time: '10h', place: 'passeio', transport: 'pe', note: 'Uma volta rápida, se não deu tempo na quinta.' },
			{ time: '11h30', place: 'mercado', transport: 'pe', note: 'Último almoço e lembrancinhas (erva-mate, pinhão).' },
			{ time: '15h40', place: 'aero', transport: 'uber', note: 'O Emmus pode dividir o carro e esperar no aeroporto, ou ir sozinho mais tarde.' }
		]
	}
];

export const placeUrl = (p: Place) =>
	`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(p.name)}&query_place_id=${p.placeId}`;

export function routeUrl(day: Day): string | null {
	const pts = day.stops.map((s) => (s.place ? PLACES[s.place] : null)).filter((p): p is Place => !!p);
	if (pts.length < 2) return null;
	const ll = (p: Place) => `${p.lat},${p.lng}`;
	const params = new URLSearchParams({ api: '1', origin: ll(pts[0]), destination: ll(pts.at(-1)!), travelmode: 'driving' });
	if (pts.length > 2) params.set('waypoints', pts.slice(1, -1).map(ll).join('|'));
	return `https://www.google.com/maps/dir/?${params}`;
}

/** Opens the Uber app (or m.uber.com) with pickup = current location and this place as the destination. */
export function uberUrl(p: Place) {
	// encodeURIComponent (not URLSearchParams) so spaces become %20, not "+", in the place name
	const q = Object.entries({
		action: 'setPickup',
		pickup: 'my_location',
		'dropoff[latitude]': String(p.lat),
		'dropoff[longitude]': String(p.lng),
		'dropoff[nickname]': p.name
	})
		.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
		.join('&');
	return `https://m.uber.com/ul/?${q}`;
}
