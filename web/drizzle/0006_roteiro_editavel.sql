CREATE TABLE "itinerary_days" (
	"date" text PRIMARY KEY NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"who" text DEFAULT '' NOT NULL,
	"lead" text DEFAULT '' NOT NULL,
	"wedding" boolean DEFAULT false NOT NULL,
	"updated_by" uuid,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "itinerary_stops" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"day" text NOT NULL,
	"position" integer NOT NULL,
	"time" text DEFAULT '' NOT NULL,
	"place_id" text,
	"label" text DEFAULT '' NOT NULL,
	"transport" text DEFAULT 'pe' NOT NULL,
	"note" text DEFAULT '' NOT NULL
);
--> statement-breakpoint
CREATE TABLE "place_photos" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"place_id" text NOT NULL,
	"key" text NOT NULL,
	"user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "places" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"category" text DEFAULT 'passeio' NOT NULL,
	"lat" double precision NOT NULL,
	"lng" double precision NOT NULL,
	"address" text DEFAULT '' NOT NULL,
	"hours" text DEFAULT '' NOT NULL,
	"price" text DEFAULT '' NOT NULL,
	"price_level" integer,
	"description" text DEFAULT '' NOT NULL,
	"link" text DEFAULT '' NOT NULL,
	"google_place_id" text,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "itinerary_days" ADD CONSTRAINT "itinerary_days_updated_by_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "itinerary_stops" ADD CONSTRAINT "itinerary_stops_day_itinerary_days_date_fk" FOREIGN KEY ("day") REFERENCES "public"."itinerary_days"("date") ON DELETE cascade ON UPDATE cascade;--> statement-breakpoint
ALTER TABLE "itinerary_stops" ADD CONSTRAINT "itinerary_stops_place_id_places_id_fk" FOREIGN KEY ("place_id") REFERENCES "public"."places"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "place_photos" ADD CONSTRAINT "place_photos_place_id_places_id_fk" FOREIGN KEY ("place_id") REFERENCES "public"."places"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "place_photos" ADD CONSTRAINT "place_photos_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "places" ADD CONSTRAINT "places_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "itinerary_stops_day_idx" ON "itinerary_stops" USING btree ("day","position");--> statement-breakpoint
CREATE INDEX "place_photos_place_idx" ON "place_photos" USING btree ("place_id");
--> statement-breakpoint
-- The itinerary that used to live in src/lib/itinerary.ts
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('aero','Aeroporto Afonso Pena','outro',-25.5314995,-49.1740261,'','ChIJcdlncM3w3JQR4ukUUzTbuiI');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('boca','Rua XV de Novembro (Boca Maldita)','passeio',-25.4322355,-49.2741782,'24 h','ChIJOU7yqHLk3JQRwaNi8DNGXSc');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('alemao','Bar do Alemão','comer',-25.4278958,-49.2726731,'11h–0h (sex/sáb até 1h)','ChIJc3cRQRLk3JQRwZm09a0UJpg');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('mercado','Mercado Municipal','comer',-25.4345052,-49.2569728,'fecha seg; ter–sáb 8h–18h; dom 8h–13h','ChIJnYfZ7ETk3JQRKsDrOXtHVTU');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('passeio','Passeio Público','passeio',-25.4253475,-49.2674245,'fecha seg; 6h–20h','ChIJVbyydhTk3JQR3rEscng0WJ4');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('mon','Museu Oscar Niemeyer','passeio',-25.4098994,-49.2670599,'fecha seg; 10h–17h30','ChIJFWlvqB_k3JQR7jsyAF9M8vU');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('papa','Bosque do Papa (Memorial Polonês)','passeio',-25.4089001,-49.2701858,'9h–17h','ChIJW9u3WKfm3JQRJByOR4G7a-s');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('jb','Jardim Botânico','passeio',-25.4421565,-49.2413194,'6h–19h30','ChIJNWbp1QDl3JQRVFbc_cVeLRo');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('opera','Ópera de Arame','passeio',-25.3845574,-49.2761701,'fecha seg; 10h–17h50','ChIJ9VsTK2jn3JQRkEQgTpixey4');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('tangua','Parque Tanguá','passeio',-25.3790661,-49.2824233,'6h–20h','ChIJQSAIRdTm3JQR3EBLwWaWlGk');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('madalosso','Família Madalosso','comer',-25.4053748,-49.3283393,'fecha ter; jantar 18h30–21h30','ChIJs7Vq1qbh3JQRZbRtpxTPEqo');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('feira','Feira do Largo da Ordem','passeio',-25.4276922,-49.2737548,'só dom 9h–14h','ChIJx6v1b9rl3JQR_wcfFySkTEE');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('barigui','Parque Barigui','passeio',-25.4262654,-49.30723,'24 h','ChIJp1_LiN_j3JQRUx7PRRpC7WQ');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('rodo','Rodoferroviária de Curitiba','outro',-25.4368387,-49.2574368,'24 h','ChIJyXejqlzk3JQRPYQPbvYowKQ');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('pontevelha','Restaurante Ponte Velha (Morretes)','comer',-25.4753473,-48.8332441,'fecha qua; 11h–15h30','ChIJncyZXAyH3JQRYUSekHLhzj4');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('bosque','Bosque Alemão','passeio',-25.4044672,-49.288116,'8h–20h','ChIJxYnV2Qf73JQR0ASXvKNB7mA');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('ucraniano','Memorial Ucraniano (Parque Tingui)','passeio',-25.4023741,-49.3049066,'10h–12h e 13h–18h','ChIJbxAI75nh3JQRKOUFy2ddHf0');
--> statement-breakpoint
INSERT INTO "places" ("id","name","category","lat","lng","hours","google_place_id") VALUES ('anarco','Anarco Batel','comer',-25.4397929,-49.2964735,'fecha seg; jantar 18h–22h (dom só almoço)','ChIJh2wM3iTj3JQRmW0tV09xFNA');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-11','Chegada e centro histórico','Emmus de manhã; Esther & Nelson e Carlos à noite.','Do aeroporto, sempre de Uber: com mala não compensa o ônibus.',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-11',0,'9h35','aero','','uber','Uber até o hotel (cerca de 35 min). Esther & Nelson dividem o mesmo carro.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-11',1,'14h','boca','','pe','Emmus: passeio pela Rua XV, o calçadão do centro.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-11',2,'20h30','alemao','','pe','Jantar do grupo. Peça a carne de onça, clássico de Curitiba. Aberto até meia-noite.');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-12','Mercado, parques e museu','Esther & Nelson, Carlos e Emmus; Icaro & Lilian a partir da tarde.','Icaro & Lilian encontram o grupo à tarde no museu.',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-12',0,'10h','mercado','','pe','Café, produtos locais e almoço na praça de alimentação do 2º andar.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-12',1,'13h30','passeio','','onibus','O parque mais antigo da cidade, cheio de aves. Também dá para ir a pé (20 min).');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-12',2,'14h30','mon','','onibus','O Museu do Olho, cerca de 10 min de ônibus. Icaro & Lilian vão de Uber direto do aeroporto.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-12',3,'17h','papa','','pe','Bosque do Papa, ao lado do museu. Depois, jantar no Batel (Uber, uns R$ 20 por carro).');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-13','Linha Turismo com todo mundo','Todos juntos (Bruna a partir das 10h30).','Comprem o cartão da Linha Turismo (R$ 50, vale 24 horas). Os ônibus passam a cada 30 min, até o fim da tarde.',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-13',0,'11h','jb','','turismo','A famosa estufa. Almoço no bufê dentro do parque.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-13',1,'14h30','opera','','turismo','Teatro de aço e vidro sobre o lago de uma pedreira.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-13',2,'16h30','tangua','','turismo','Fiquem para o pôr do sol no mirante (por volta das 18h50).');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-13',3,'19h30','madalosso','','uber','2 carros, cerca de 20 min; a Linha Turismo já parou nesse horário. Rodízio italiano em Santa Felicidade. Voltem cedo: o casamento é amanhã. Volta de Uber.');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-14','Dia do casamento','Todos.','Dia inteiro dedicado ao casamento: salão, preparativos e festa. Nada de passeios.',true);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-14',0,'Ida e volta',NULL,'Salão do casamento','uber','Dividam os carros, 4 por carro (cerca de R$ 20 por pessoa no total). Combinem a volta antes de a festa acabar.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-14',1,'Madrugada do dia 15',NULL,'Carlos vai para o aeroporto','uber','Voo às 4h25. Sair da festa por volta das 2h30 com a mala já pronta.');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-15','Descanso e feira de domingo','Todos, menos Carlos.','O voo do Carlos é às 4h25: Uber direto da festa. Durmam até mais tarde. Ônibus a R$ 3 (domingo e feriado).',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-15',0,'11h','feira','','pe','Só aos domingos, das 9h às 14h. Brunch nas barracas (pastel!).');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-15',1,'14h30','barigui','','onibus','Cerca de 25 min de ônibus. Tarde tranquila no lago, com as capivaras.');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-16','Bate-volta a Morretes','Todos, menos Carlos.','De ônibus da Viação Graciosa: cerca de 1h20 e R$ 47 por trecho, 7 saídas por dia. Comprem ida e volta antes.',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-16',0,'8h30','rodo','','uber','Uber até a rodoviária (uns R$ 20 por carro) e ônibus Graciosa para Morretes.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-16',1,'11h30','pontevelha','','rodo','Barreado, o prato típico, com vista para o rio. Aberto às segundas (fecha às quartas). Depois, passeio pelo centro histórico e ônibus de volta por volta das 16h.');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-17','Bosques, memoriais e despedida','Todos, menos Carlos (último dia de Bruna, Icaro & Lilian).','Esses lugares são espalhados e o ônibus não liga bem: vão de Uber entre eles (R$ 15–30 por carro a cada trecho).',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-17',0,'10h','bosque','','uber','Trilha na mata, torre-mirante e a confeitaria alemã Erika.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-17',1,'12h','ucraniano','','uber','Cerca de 5 min de Uber. Igreja ucraniana dentro do Parque Tingui. Depois, almoço pelo Batel.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-17',2,'19h30','anarco','','uber','Jantar de despedida. Reservem antes. Bruna, Icaro & Lilian: Uber para o aeroporto por volta de 1h20 (dividam o carro, é o mesmo voo).');
--> statement-breakpoint
INSERT INTO "itinerary_days" ("date","title","who","lead","wedding") VALUES ('2026-11-18','Última manhã','Esther & Nelson até 15h40; Emmus até 18h30.','Manhã leve antes de ir para o aeroporto.',false);
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-18',0,'10h','passeio','','pe','Uma volta rápida, se não deu tempo na quinta.');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-18',1,'11h30','mercado','','pe','Último almoço e lembrancinhas (erva-mate, pinhão).');
--> statement-breakpoint
INSERT INTO "itinerary_stops" ("day","position","time","place_id","label","transport","note") VALUES ('2026-11-18',2,'15h40','aero','','uber','O Emmus pode dividir o carro e esperar no aeroporto, ou ir sozinho mais tarde.');
