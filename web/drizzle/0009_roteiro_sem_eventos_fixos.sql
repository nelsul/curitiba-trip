-- The Roteiro started from the old fixed itinerary (0006). Remove those events: arrivals, departures and the
-- old plan for each day. Keep only the wedding itself. Stops or texts someone changed since are kept.
DELETE FROM "itinerary_stops" WHERE ("day", "note") IN (
	('2026-11-11', 'Uber até o hotel (cerca de 35 min). Esther & Nelson dividem o mesmo carro.'),
	('2026-11-11', 'Emmus: passeio pela Rua XV, o calçadão do centro.'),
	('2026-11-11', 'Jantar do grupo. Peça a carne de onça, clássico de Curitiba. Aberto até meia-noite.'),
	('2026-11-12', 'Café, produtos locais e almoço na praça de alimentação do 2º andar.'),
	('2026-11-12', 'O parque mais antigo da cidade, cheio de aves. Também dá para ir a pé (20 min).'),
	('2026-11-12', 'O Museu do Olho, cerca de 10 min de ônibus. Icaro & Lilian vão de Uber direto do aeroporto.'),
	('2026-11-12', 'Bosque do Papa, ao lado do museu. Depois, jantar no Batel (Uber, uns R$ 20 por carro).'),
	('2026-11-13', 'A famosa estufa. Almoço no bufê dentro do parque.'),
	('2026-11-13', 'Teatro de aço e vidro sobre o lago de uma pedreira.'),
	('2026-11-13', 'Fiquem para o pôr do sol no mirante (por volta das 18h50).'),
	('2026-11-13', '2 carros, cerca de 20 min; a Linha Turismo já parou nesse horário. Rodízio italiano em Santa Felicidade. Voltem cedo: o casamento é amanhã. Volta de Uber.'),
	('2026-11-14', 'Voo às 4h25. Sair da festa por volta das 2h30 com a mala já pronta.'),
	('2026-11-15', 'Só aos domingos, das 9h às 14h. Brunch nas barracas (pastel!).'),
	('2026-11-15', 'Cerca de 25 min de ônibus. Tarde tranquila no lago, com as capivaras.'),
	('2026-11-16', 'Uber até a rodoviária (uns R$ 20 por carro) e ônibus Graciosa para Morretes.'),
	('2026-11-16', 'Barreado, o prato típico, com vista para o rio. Aberto às segundas (fecha às quartas). Depois, passeio pelo centro histórico e ônibus de volta por volta das 16h.'),
	('2026-11-17', 'Trilha na mata, torre-mirante e a confeitaria alemã Erika.'),
	('2026-11-17', 'Cerca de 5 min de Uber. Igreja ucraniana dentro do Parque Tingui. Depois, almoço pelo Batel.'),
	('2026-11-17', 'Jantar de despedida. Reservem antes. Bruna, Icaro & Lilian: Uber para o aeroporto por volta de 1h20 (dividam o carro, é o mesmo voo).'),
	('2026-11-18', 'Uma volta rápida, se não deu tempo na quinta.'),
	('2026-11-18', 'Último almoço e lembrancinhas (erva-mate, pinhão).'),
	('2026-11-18', 'O Emmus pode dividir o carro e esperar no aeroporto, ou ir sozinho mais tarde.')
);
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Chegada e centro histórico' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Emmus de manhã; Esther & Nelson e Carlos à noite.' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'Do aeroporto, sempre de Uber: com mala não compensa o ônibus.' THEN '' ELSE "lead" END WHERE "date" = '2026-11-11';
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Mercado, parques e museu' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Esther & Nelson, Carlos e Emmus; Icaro & Lilian a partir da tarde.' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'Icaro & Lilian encontram o grupo à tarde no museu.' THEN '' ELSE "lead" END WHERE "date" = '2026-11-12';
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Linha Turismo com todo mundo' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Todos juntos (Bruna a partir das 10h30).' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'Comprem o cartão da Linha Turismo (R$ 50, vale 24 horas). Os ônibus passam a cada 30 min, até o fim da tarde.' THEN '' ELSE "lead" END WHERE "date" = '2026-11-13';
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Descanso e feira de domingo' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Todos, menos Carlos.' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'O voo do Carlos é às 4h25: Uber direto da festa. Durmam até mais tarde. Ônibus a R$ 3 (domingo e feriado).' THEN '' ELSE "lead" END WHERE "date" = '2026-11-15';
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Bate-volta a Morretes' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Todos, menos Carlos.' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'De ônibus da Viação Graciosa: cerca de 1h20 e R$ 47 por trecho, 7 saídas por dia. Comprem ida e volta antes.' THEN '' ELSE "lead" END WHERE "date" = '2026-11-16';
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Bosques, memoriais e despedida' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Todos, menos Carlos (último dia de Bruna, Icaro & Lilian).' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'Esses lugares são espalhados e o ônibus não liga bem: vão de Uber entre eles (R$ 15–30 por carro a cada trecho).' THEN '' ELSE "lead" END WHERE "date" = '2026-11-17';
--> statement-breakpoint
UPDATE "itinerary_days" SET "title" = CASE WHEN "title" = 'Última manhã' THEN '' ELSE "title" END, "who" = CASE WHEN "who" = 'Esther & Nelson até 15h40; Emmus até 18h30.' THEN '' ELSE "who" END, "lead" = CASE WHEN "lead" = 'Manhã leve antes de ir para o aeroporto.' THEN '' ELSE "lead" END WHERE "date" = '2026-11-18';
--> statement-breakpoint
-- the airport and the bus station were only there for arrivals and departures
DELETE FROM "places" WHERE "id" IN ('aero', 'rodo')
	AND NOT EXISTS (SELECT 1 FROM "itinerary_stops" s WHERE s."place_id" = "places"."id")
	AND NOT EXISTS (SELECT 1 FROM "place_photos" p WHERE p."place_id" = "places"."id");
