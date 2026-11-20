CREATE TABLE "guest_codes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"code_hash" text NOT NULL,
	"created_by" uuid NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "guest_codes" ADD CONSTRAINT "guest_codes_created_by_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "guest_codes_hash_uq" ON "guest_codes" USING btree ("code_hash");--> statement-breakpoint
CREATE INDEX "guest_codes_by_idx" ON "guest_codes" USING btree ("created_by","expires_at");