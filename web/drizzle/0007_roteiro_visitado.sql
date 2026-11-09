ALTER TABLE "itinerary_stops" ADD COLUMN "visited_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "itinerary_stops" ADD COLUMN "visited_by" uuid;--> statement-breakpoint
ALTER TABLE "itinerary_stops" ADD CONSTRAINT "itinerary_stops_visited_by_users_id_fk" FOREIGN KEY ("visited_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;