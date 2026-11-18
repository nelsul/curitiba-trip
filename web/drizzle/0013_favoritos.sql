CREATE TABLE "favorites" (
	"user_id" uuid NOT NULL,
	"media_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "favorites" ADD CONSTRAINT "favorites_media_id_media_id_fk" FOREIGN KEY ("media_id") REFERENCES "public"."media"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "favorites_pk" ON "favorites" USING btree ("user_id","media_id");--> statement-breakpoint
CREATE INDEX "favorites_media_idx" ON "favorites" USING btree ("media_id");--> statement-breakpoint
-- the admin's old Retrospectiva picks become the admin's favorites, so nothing already chosen is lost
INSERT INTO "favorites" ("user_id", "media_id")
	SELECT u."id", r."media_id" FROM "retro_items" r
	CROSS JOIN (SELECT "id" FROM "users" WHERE "is_admin" ORDER BY "created_at" LIMIT 1) u
	ON CONFLICT DO NOTHING;
