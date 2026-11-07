ALTER TABLE "sessions" ADD COLUMN "kind" text DEFAULT 'cookie' NOT NULL;--> statement-breakpoint
ALTER TABLE "sessions" ADD COLUMN "device_name" text;--> statement-breakpoint
ALTER TABLE "sessions" ADD COLUMN "last_used_at" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "sessions_user_idx" ON "sessions" USING btree ("user_id");