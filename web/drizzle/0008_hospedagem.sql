CREATE TABLE "stay_guests" (
	"stay_id" uuid NOT NULL,
	"user_id" uuid NOT NULL
);
--> statement-breakpoint
CREATE TABLE "stays" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"kind" text DEFAULT 'hotel' NOT NULL,
	"lat" double precision NOT NULL,
	"lng" double precision NOT NULL,
	"address" text DEFAULT '' NOT NULL,
	"link" text DEFAULT '' NOT NULL,
	"check_in" text,
	"check_out" text,
	"note" text DEFAULT '' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "stay_guests" ADD CONSTRAINT "stay_guests_stay_id_stays_id_fk" FOREIGN KEY ("stay_id") REFERENCES "public"."stays"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "stay_guests" ADD CONSTRAINT "stay_guests_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "stay_guests_pk" ON "stay_guests" USING btree ("stay_id","user_id");--> statement-breakpoint
CREATE INDEX "stay_guests_user_idx" ON "stay_guests" USING btree ("user_id");