ALTER TABLE "users" ADD COLUMN "pix_key" text DEFAULT '' NOT NULL;--> statement-breakpoint
-- keep the key people already used in their latest cotinha
UPDATE "users" u SET "pix_key" = s."pix_key" FROM (
	SELECT DISTINCT ON ("payer_id") "payer_id", "pix_key" FROM "splits" WHERE "pix_key" <> '' ORDER BY "payer_id", "created_at" DESC
) s WHERE s."payer_id" = u."id";
