-- Case-SELECT — PostgreSQL schema
-- Generated from schema.prisma (single source of truth), mirroring the SQL that
-- `prisma migrate` would emit: quoted identifiers, Prisma-style constraint names
-- and Prisma's default referential actions:
--   required relation          -> ON DELETE RESTRICT  ON UPDATE CASCADE
--   optional relation          -> ON DELETE SET NULL  ON UPDATE CASCADE
--   onDelete: Cascade in model -> ON DELETE CASCADE   ON UPDATE CASCADE
-- Run with:  psql -v ON_ERROR_STOP=1 -f schema.sql  <database>

BEGIN;

-- ───────────── Enum ─────────────

CREATE TYPE "ProgressStatus" AS ENUM ('IN_PROGRESS', 'COMPLETED');

-- ───────────── Tables ─────────────

-- Users & their progress
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "username" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password" TEXT,  -- Argon2id hash; NULL = no usable credential

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "user_progress" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "caseId" TEXT NOT NULL,
    "status" "ProgressStatus" NOT NULL DEFAULT 'IN_PROGRESS',
    "locationId" TEXT,
    "sequenceId" INTEGER,

    CONSTRAINT "user_progress_pkey" PRIMARY KEY ("id")
);

-- Cases, NPCs, dialogue, locations
CREATE TABLE "cases" (
    "id" TEXT NOT NULL,
    "caseName" TEXT NOT NULL,
    "description" TEXT,
    "difficulty" TEXT,  -- Easy | Medium | Hard
    "startLocationId" TEXT,

    CONSTRAINT "cases_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "npcs" (
    "id" TEXT NOT NULL,
    "npcName" TEXT NOT NULL,
    "role" TEXT,

    CONSTRAINT "npcs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "locations" (
    "id" TEXT NOT NULL,
    "locationName" TEXT NOT NULL,
    "description" TEXT,

    CONSTRAINT "locations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "dialogues" (
    "id" TEXT NOT NULL,
    "caseId" TEXT NOT NULL,
    "npcId" TEXT NOT NULL,
    "locationId" TEXT,
    "dialoguesList" TEXT[],

    CONSTRAINT "dialogues_pkey" PRIMARY KEY ("id")
);

-- Case flow (sequence of steps)
CREATE TABLE "case_progress" (
    "id" TEXT NOT NULL,
    "caseId" TEXT NOT NULL,
    "sequenceId" INTEGER NOT NULL,
    "dialogueId" TEXT,
    "evidenceId" TEXT,
    "locationId" TEXT,
    "queryId" TEXT,

    CONSTRAINT "case_progress_pkey" PRIMARY KEY ("id")
);

-- Evidence, queries, investigation tables
CREATE TABLE "evidences" (
    "id" TEXT NOT NULL,
    "caseId" TEXT NOT NULL,
    "evidenceName" TEXT NOT NULL,
    "description" TEXT,

    CONSTRAINT "evidences_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "queries" (
    "id" TEXT NOT NULL,
    "caseId" TEXT NOT NULL,
    "queryOutput" TEXT NOT NULL,
    "title" TEXT,
    "question" TEXT,
    "difficulty" TEXT,
    "hint" TEXT,
    "unlockMessage" TEXT,
    "answerValues" TEXT[],
    "maxRows" INTEGER,

    CONSTRAINT "queries_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "investigation_tables" (
    "id" TEXT NOT NULL,
    "tableName" TEXT NOT NULL,
    "displayName" TEXT,
    "description" TEXT,

    CONSTRAINT "investigation_tables_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "query_tables" (
    "caseId" TEXT NOT NULL,
    "tableId" TEXT NOT NULL,

    CONSTRAINT "query_tables_pkey" PRIMARY KEY ("caseId", "tableId")
);

-- Investigation data
CREATE TABLE "guests" (
    "guest_id" TEXT NOT NULL,
    "guest_name" TEXT NOT NULL,
    "role" TEXT NOT NULL,
    "is_suspect" BOOLEAN NOT NULL,

    CONSTRAINT "guests_pkey" PRIMARY KEY ("guest_id")
);

CREATE TABLE "waiters" (
    "id" TEXT NOT NULL,
    "waiter_name" TEXT,

    CONSTRAINT "waiters_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "restaurant_orders" (
    "order_id" TEXT NOT NULL,
    "guest_id" TEXT NOT NULL,
    "dish" TEXT NOT NULL,
    "order_time" TEXT NOT NULL,
    "waiter_id" TEXT NOT NULL,

    CONSTRAINT "restaurant_orders_pkey" PRIMARY KEY ("order_id")
);

CREATE TABLE "employees" (
    "employee_id" TEXT NOT NULL,
    "employee_name" TEXT NOT NULL,
    "job_title" TEXT NOT NULL,

    CONSTRAINT "employees_pkey" PRIMARY KEY ("employee_id")
);

CREATE TABLE "kitchen_logs" (
    "log_id" TEXT NOT NULL,
    "employee_id" TEXT NOT NULL,
    "action" TEXT NOT NULL,
    "timestamp" TEXT NOT NULL,
    "kitchen_area" TEXT NOT NULL,

    CONSTRAINT "kitchen_logs_pkey" PRIMARY KEY ("log_id")
);

CREATE TABLE "access_cards" (
    "access_id" TEXT NOT NULL,
    "employee_id" TEXT NOT NULL,
    "access_area" TEXT NOT NULL,
    "access_time" TEXT NOT NULL,
    "action" TEXT NOT NULL,

    CONSTRAINT "access_cards_pkey" PRIMARY KEY ("access_id")
);

CREATE TABLE "bank_accounts" (
    "account_id" TEXT NOT NULL,
    "account_number" TEXT NOT NULL,
    "owner_type" TEXT NOT NULL,
    "owner_id" TEXT NOT NULL,

    CONSTRAINT "bank_accounts_pkey" PRIMARY KEY ("account_id")
);

CREATE TABLE "payments" (
    "payment_id" TEXT NOT NULL,
    "sender_account" TEXT NOT NULL,
    "receiver_account" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "payment_time" TEXT NOT NULL,
    "description" TEXT,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("payment_id")
);

CREATE TABLE "phone_records" (
    "phone_record_id" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "owner_id" TEXT NOT NULL,
    "associated_account" TEXT NOT NULL,
    "call_time" TEXT NOT NULL,
    "duration" INTEGER NOT NULL,

    CONSTRAINT "phone_records_pkey" PRIMARY KEY ("phone_record_id")
);

-- Implicit many-to-many join table for Evidence <-> Query
-- (Prisma-managed; "A" = evidences.id, "B" = queries.id)
CREATE TABLE "_EvidenceToQuery" (
    "A" TEXT NOT NULL,
    "B" TEXT NOT NULL,

    CONSTRAINT "_EvidenceToQuery_AB_pkey" PRIMARY KEY ("A", "B")
);

-- ───────────── Indexes & unique constraints ─────────────

CREATE UNIQUE INDEX "users_username_key" ON "users"("username");
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

CREATE UNIQUE INDEX "user_progress_userId_caseId_key" ON "user_progress"("userId", "caseId");

CREATE INDEX "dialogues_caseId_idx" ON "dialogues"("caseId");
CREATE INDEX "dialogues_npcId_idx" ON "dialogues"("npcId");

CREATE UNIQUE INDEX "case_progress_caseId_sequenceId_key" ON "case_progress"("caseId", "sequenceId");

CREATE INDEX "evidences_caseId_idx" ON "evidences"("caseId");

CREATE INDEX "queries_caseId_idx" ON "queries"("caseId");

CREATE INDEX "restaurant_orders_guest_id_idx" ON "restaurant_orders"("guest_id");
CREATE INDEX "restaurant_orders_waiter_id_idx" ON "restaurant_orders"("waiter_id");

CREATE INDEX "kitchen_logs_employee_id_idx" ON "kitchen_logs"("employee_id");

CREATE INDEX "access_cards_employee_id_idx" ON "access_cards"("employee_id");

CREATE INDEX "payments_sender_account_idx" ON "payments"("sender_account");
CREATE INDEX "payments_receiver_account_idx" ON "payments"("receiver_account");

CREATE INDEX "phone_records_owner_id_idx" ON "phone_records"("owner_id");
CREATE INDEX "phone_records_associated_account_idx" ON "phone_records"("associated_account");

CREATE INDEX "_EvidenceToQuery_B_index" ON "_EvidenceToQuery"("B");

-- ───────────── Foreign keys ─────────────

-- user_progress
ALTER TABLE "user_progress" ADD CONSTRAINT "user_progress_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "user_progress" ADD CONSTRAINT "user_progress_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "user_progress" ADD CONSTRAINT "user_progress_locationId_fkey"
    FOREIGN KEY ("locationId") REFERENCES "locations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
-- Composite FK; "sequenceId" is nullable, so (MATCH SIMPLE) a NULL skips the check.
ALTER TABLE "user_progress" ADD CONSTRAINT "user_progress_caseId_sequenceId_fkey"
    FOREIGN KEY ("caseId", "sequenceId") REFERENCES "case_progress"("caseId", "sequenceId") ON DELETE RESTRICT ON UPDATE CASCADE;

-- cases
ALTER TABLE "cases" ADD CONSTRAINT "cases_startLocationId_fkey"
    FOREIGN KEY ("startLocationId") REFERENCES "locations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- dialogues
ALTER TABLE "dialogues" ADD CONSTRAINT "dialogues_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "dialogues" ADD CONSTRAINT "dialogues_npcId_fkey"
    FOREIGN KEY ("npcId") REFERENCES "npcs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "dialogues" ADD CONSTRAINT "dialogues_locationId_fkey"
    FOREIGN KEY ("locationId") REFERENCES "locations"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- case_progress
ALTER TABLE "case_progress" ADD CONSTRAINT "case_progress_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "case_progress" ADD CONSTRAINT "case_progress_dialogueId_fkey"
    FOREIGN KEY ("dialogueId") REFERENCES "dialogues"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "case_progress" ADD CONSTRAINT "case_progress_evidenceId_fkey"
    FOREIGN KEY ("evidenceId") REFERENCES "evidences"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "case_progress" ADD CONSTRAINT "case_progress_locationId_fkey"
    FOREIGN KEY ("locationId") REFERENCES "locations"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "case_progress" ADD CONSTRAINT "case_progress_queryId_fkey"
    FOREIGN KEY ("queryId") REFERENCES "queries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- evidences / queries
ALTER TABLE "evidences" ADD CONSTRAINT "evidences_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "queries" ADD CONSTRAINT "queries_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- query_tables
ALTER TABLE "query_tables" ADD CONSTRAINT "query_tables_caseId_fkey"
    FOREIGN KEY ("caseId") REFERENCES "cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "query_tables" ADD CONSTRAINT "query_tables_tableId_fkey"
    FOREIGN KEY ("tableId") REFERENCES "investigation_tables"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- restaurant_orders
ALTER TABLE "restaurant_orders" ADD CONSTRAINT "restaurant_orders_guest_id_fkey"
    FOREIGN KEY ("guest_id") REFERENCES "guests"("guest_id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "restaurant_orders" ADD CONSTRAINT "restaurant_orders_waiter_id_fkey"
    FOREIGN KEY ("waiter_id") REFERENCES "waiters"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- kitchen_logs / access_cards
ALTER TABLE "kitchen_logs" ADD CONSTRAINT "kitchen_logs_employee_id_fkey"
    FOREIGN KEY ("employee_id") REFERENCES "employees"("employee_id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "access_cards" ADD CONSTRAINT "access_cards_employee_id_fkey"
    FOREIGN KEY ("employee_id") REFERENCES "employees"("employee_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- payments / phone_records
ALTER TABLE "payments" ADD CONSTRAINT "payments_sender_account_fkey"
    FOREIGN KEY ("sender_account") REFERENCES "bank_accounts"("account_id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "payments" ADD CONSTRAINT "payments_receiver_account_fkey"
    FOREIGN KEY ("receiver_account") REFERENCES "bank_accounts"("account_id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "phone_records" ADD CONSTRAINT "phone_records_associated_account_fkey"
    FOREIGN KEY ("associated_account") REFERENCES "bank_accounts"("account_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- _EvidenceToQuery (implicit M:N)
ALTER TABLE "_EvidenceToQuery" ADD CONSTRAINT "_EvidenceToQuery_A_fkey"
    FOREIGN KEY ("A") REFERENCES "evidences"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "_EvidenceToQuery" ADD CONSTRAINT "_EvidenceToQuery_B_fkey"
    FOREIGN KEY ("B") REFERENCES "queries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

COMMIT;
