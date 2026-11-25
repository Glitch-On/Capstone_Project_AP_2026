-- =============================================================================
-- CASE-SELECT — Database Query Repository (`dbms/04_queries.sql`)
-- Course: Database Management Systems (DBMS) & Advanced Programming (AP)
-- System: CASE-SELECT — SQL Detective Game (learn SQL by solving murder cases)
-- Database Engine: PostgreSQL 15+
-- Checkpoint: CP-3 (Operational Queries & Relational Join Catalog)
--
-- All application and gameplay queries across the game schema (03_schema.sql)
-- and 7 functional modules. Every query is explicitly categorized and labeled:
--   -- READ  : Data retrieval, multi-table joins, reporting, analytics.
--   -- WRITE : Inserts, updates, upserts, deletes, DDL (views) and the
--             transaction control (BEGIN / COMMIT / ROLLBACK) that frames them.
-- The label sits on the line directly above its statement.
--
-- Joins: wherever a query needs more than one table it uses JOINs (INNER,
-- LEFT, CROSS LATERAL) instead of IN / EXISTS / scalar subqueries. The only
-- nested SELECTs left are CTEs (5.8) and derived tables used as a JOIN source
-- (3.6, 6.3). INTERSECT / EXCEPT in 6.4 and 6.5 are the set-operation demo.
--
-- Parameters: the Prisma calls in src/ pass values as bind parameters. So that
-- this file runs top to bottom in psql, each query below uses a sample literal
-- and names the parameter it stands for in a "Params:" comment.
--
-- Times in the investigation tables are stored as TEXT ('19:44'), matching the
-- schema, so queries that compare them cast to TIME.
--
-- Run with:
--   psql -v ON_ERROR_STOP=1 -f 03_schema.sql  <database>
--   psql -v ON_ERROR_STOP=1 -f 04_queries.sql <database>
-- Module 0 empties the tables first, so this file can be run more than once.
-- =============================================================================


-- =============================================================================
-- MODULE 0: SAMPLE DATA LOAD (SEED)
-- Canonical Tables: all 21 tables (story content, investigation records, users)
-- Mirrors prisma/seed.js and prisma/data/caseC001.js for case C001.
-- =============================================================================

-- WRITE
BEGIN;

-- WRITE
TRUNCATE "users", "user_progress", "cases", "npcs", "locations", "dialogues",
         "case_progress", "evidences", "queries", "investigation_tables",
         "query_tables", "_EvidenceToQuery", "guests", "waiters",
         "restaurant_orders", "employees", "kitchen_logs", "access_cards",
         "bank_accounts", "payments", "phone_records"
RESTART IDENTITY CASCADE;

-- 0.1 Case content

-- WRITE
INSERT INTO "locations" ("id", "locationName", "description") VALUES
    ('L001', 'The Red Lantern Diner', 'An upscale private diner where Vikram Malhotra hosted the dinner.'),
    ('L002', 'Main Dining Hall',      'The private dining area where the guests had dinner.'),
    ('L003', 'Main Kitchen',          'Restricted area where meals were prepared and plated.'),
    ('L004', 'Staff Office',          'Small office containing employee records and financial documents.'),
    ('L005', 'Parking Area',          'Private parking area outside the diner.'),
    ('L006', 'Vikram''s Office',      'Vikram Malhotra''s office, where additional information about his business dealings can be found.');

-- WRITE
INSERT INTO "npcs" ("id", "npcName", "role") VALUES
    ('N001', 'Rahul Sen',   'Diner Manager'),
    ('N002', 'Rohan Mehra', 'Waiter'),
    ('N003', 'Priya Menon', 'Diner Guest'),
    ('N004', 'Neha Kapoor', 'Political Rival'),
    ('N005', 'Sana Mirza',  'Personal Assistant');

-- WRITE
INSERT INTO "cases" ("id", "caseName", "description", "difficulty", "startLocationId") VALUES
    ('C001', 'The Murderer Is Not a Suspect',
     'A politician is murdered during a private dinner at The Red Lantern Diner. Six guests appear suspicious, but the evidence suggests the real mastermind was never considered a suspect.',
     'Medium', 'L005');

-- WRITE
INSERT INTO "dialogues" ("id", "caseId", "npcId", "locationId", "dialoguesList") VALUES
    ('D001', 'C001', 'N001', 'L001', ARRAY['Detective, I''m glad you''re here. This was supposed to be a private dinner.']),
    ('D002', 'C001', 'N001', 'L001', ARRAY['Vikram Malhotra was sitting at the center of the table when he suddenly collapsed.']),
    ('D003', 'C001', 'N001', 'L001', ARRAY['There were six people at the dinner who had reasons to dislike him.']),
    ('D004', 'C001', 'N002', 'L001', ARRAY['I was nowhere near the kitchen that evening.']),
    ('D005', 'C001', 'N002', 'L001', ARRAY['I only delivered the dishes. I didn''t see anything unusual.']),
    ('D006', 'C001', 'N003', 'L002', ARRAY['Vikram seemed nervous during dinner. He kept checking his phone.']),
    ('D007', 'C001', 'N004', 'L002', ARRAY['Everyone keeps looking at us, but none of us killed him.']),
    ('D008', 'C001', 'N002', 'L001', ARRAY['I told you, I never entered the kitchen.']),
    ('D009', 'C001', 'N005', 'L006', ARRAY['Arvind? He and Vikram had been business partners for years.']),
    ('D010', 'C001', 'N005', 'L006', ARRAY['They had been arguing about money recently.']),
    ('D011', 'C001', 'N002', 'L001', ARRAY['Fine... I entered the kitchen. But I didn''t kill Vikram.']),
    ('D012', 'C001', 'N002', 'L001', ARRAY['Someone offered me money to do something. I didn''t know they planned to kill him.']);

-- WRITE
INSERT INTO "evidences" ("id", "caseId", "evidenceName", "description") VALUES
    ('EV001', 'C001', 'Mushroom Risotto Order',   'Vikram Malhotra ordered Mushroom Risotto shortly before his death.'),
    ('EV002', 'C001', 'Rohan Served the Dish',    'Rohan Mehra was responsible for delivering Vikram''s Mushroom Risotto.'),
    ('EV003', 'C001', 'Kitchen Entry',            'Kitchen logs prove Rohan entered the kitchen.'),
    ('EV004', 'C001', 'Access Card Confirmation', 'Rohan''s access card confirms his kitchen entry.'),
    ('EV005', 'C001', '₹50,000 Payment',          'Rohan received ₹50,000 shortly before the murder.'),
    ('EV006', 'C001', 'Account B009',             'The payment originated from bank account B009.'),
    ('EV007', 'C001', 'Arvind''s Account',        'Bank account B009 belongs to Arvind Khanna.'),
    ('EV008', 'C001', 'The Mastermind',           'The evidence establishes Arvind Khanna as the person who planned the murder.');

-- WRITE
INSERT INTO "queries" ("id", "caseId", "difficulty", "title", "question", "hint",
                       "queryOutput", "unlockMessage", "answerValues", "maxRows") VALUES
    ('Q001', 'C001', 'Easy',   'The Victim''s Last Meal', 'What dish did Vikram Malhotra order?',
     'Search the restaurant orders for the victim.', 'Mushroom Risotto',
     'You discover what the victim ordered.', ARRAY['Mushroom Risotto'], 1),
    ('Q002', 'C001', 'Easy',   'Who Served the Dish?', 'Which waiter delivered Vikram''s Mushroom Risotto?',
     'Find the order containing Mushroom Risotto.', 'Rohan Mehra',
     'You now know which waiter handled the dish.', ARRAY['Rohan Mehra'], 1),
    ('Q003', 'C001', 'Easy',   'The Kitchen Lie', 'Did Rohan Mehra enter the kitchen that evening?',
     'Search the kitchen logs using Rohan''s employee ID.', 'Yes',
     'Rohan''s statement doesn''t match the kitchen logs.', ARRAY['Entered Kitchen', '19:44'], 3),
    ('Q004', 'C001', 'Medium', 'The Second Record', 'Can the access-card records confirm Rohan''s kitchen entry?',
     'Compare Rohan''s kitchen access with the kitchen logs.', 'Yes',
     'The access-card system confirms the contradiction.', ARRAY['Kitchen', 'Entry', '19:44'], 4),
    ('Q005', 'C001', 'Medium', 'Follow the Money', 'Was Rohan Mehra paid before the murder?',
     'Look for payments sent to Rohan''s bank account.', '₹50,000',
     'Someone paid Rohan ₹50,000.', ARRAY['50000'], 1),
    ('Q006', 'C001', 'Medium', 'The Anonymous Account', 'Which bank account sent the ₹50,000 payment?',
     'Start with the payment received by Rohan.', 'B009',
     'The money came from account B009.', ARRAY['B009'], 1),
    ('Q007', 'C001', 'Medium', 'Who Owns the Account?', 'Who owns bank account B009?',
     'Connect the bank account to its owner.', 'Arvind Khanna',
     'The account belongs to Arvind Khanna.', ARRAY['Arvind Khanna'], 1),
    ('Q008', 'C001', 'Hard',   'The Mastermind', 'Who planned Vikram Malhotra''s murder?',
     'Follow the evidence from the victim → waiter → payment → account owner.', 'Arvind Khanna',
     'The evidence points to Arvind as the mastermind.', ARRAY['Arvind Khanna'], 1);

-- Implicit M:N table: "A" = evidences.id, "B" = queries.id
-- WRITE
INSERT INTO "_EvidenceToQuery" ("A", "B") VALUES
    ('EV001', 'Q001'), ('EV002', 'Q002'), ('EV003', 'Q003'), ('EV004', 'Q004'),
    ('EV005', 'Q005'), ('EV006', 'Q006'), ('EV007', 'Q007'), ('EV008', 'Q008');

-- WRITE
INSERT INTO "investigation_tables" ("id", "tableName", "displayName", "description") VALUES
    ('IT001', 'guests',            'Guests',            'People who attended the private dinner.'),
    ('IT002', 'restaurant_orders', 'Restaurant Orders', 'Food and drink orders placed during the dinner.'),
    ('IT003', 'waiters',           'Waiters',           'Restaurant waiters who served the dinner.'),
    ('IT004', 'employees',         'Employees',         'Employees working at The Red Lantern Diner.'),
    ('IT005', 'kitchen_logs',      'Kitchen Logs',      'Records of employee activity inside the kitchen.'),
    ('IT006', 'access_cards',      'Access Cards',      'Electronic access records for restricted areas.'),
    ('IT007', 'payments',          'Payments',          'Financial transactions between bank accounts.'),
    ('IT008', 'bank_accounts',     'Bank Accounts',     'Bank accounts associated with guests and employees.'),
    ('IT009', 'phone_records',     'Phone Records',     'Phone activity associated with people connected to the investigation.');

-- WRITE
INSERT INTO "query_tables" ("caseId", "tableId")
SELECT 'C001', "id" FROM "investigation_tables";

-- Step ids follow seed.js: <caseId>-S<nnn>, numbered by position in the flow.
-- WRITE
INSERT INTO "case_progress" ("id", "caseId", "sequenceId", "dialogueId", "queryId", "locationId") VALUES
    ('C001-S001', 'C001',  1, 'D001', NULL,   'L001'),
    ('C001-S002', 'C001',  2, 'D002', NULL,   'L001'),
    ('C001-S003', 'C001',  3, 'D003', NULL,   'L001'),
    ('C001-S004', 'C001',  4, 'D006', NULL,   'L002'),
    ('C001-S005', 'C001',  5, 'D007', NULL,   'L002'),
    ('C001-S006', 'C001',  6, NULL,   'Q001', 'L001'),
    ('C001-S007', 'C001',  7, NULL,   'Q002', 'L001'),
    ('C001-S008', 'C001',  8, 'D004', NULL,   'L001'),
    ('C001-S009', 'C001',  9, 'D005', NULL,   'L001'),
    ('C001-S010', 'C001', 10, NULL,   'Q003', 'L003'),
    ('C001-S011', 'C001', 11, NULL,   'Q004', 'L003'),
    ('C001-S012', 'C001', 12, 'D008', NULL,   'L001'),
    ('C001-S013', 'C001', 13, 'D011', NULL,   'L001'),
    ('C001-S014', 'C001', 14, NULL,   'Q005', 'L004'),
    ('C001-S015', 'C001', 15, NULL,   'Q006', 'L004'),
    ('C001-S016', 'C001', 16, NULL,   'Q007', 'L006'),
    ('C001-S017', 'C001', 17, 'D009', NULL,   'L006'),
    ('C001-S018', 'C001', 18, 'D010', NULL,   'L006'),
    ('C001-S019', 'C001', 19, NULL,   'Q008', 'L006'),
    ('C001-S020', 'C001', 20, 'D012', NULL,   'L001');

-- 0.2 Investigation records (the tables players query)

-- WRITE
INSERT INTO "guests" ("guest_id", "guest_name", "role", "is_suspect") VALUES
    ('G001', 'Vikram Malhotra', 'Victim / Politician',      FALSE),
    ('G002', 'Neha Kapoor',     'Political Rival',          TRUE),
    ('G003', 'Karan Bedi',      'Political Aide',           TRUE),
    ('G004', 'Meera Sethi',     'Investigative Journalist', TRUE),
    ('G005', 'Rajiv Oberoi',    'Business Contractor',      TRUE),
    ('G006', 'Sana Mirza',      'Personal Assistant',       TRUE),
    ('G007', 'Dev Ahuja',       'Opposition Leader',        TRUE),
    ('G008', 'Arvind Khanna',   'Business Partner',         FALSE),
    ('G009', 'Priya Menon',     'Diner Guest',              FALSE),
    ('G010', 'Sameer Rao',      'Party Treasurer',          FALSE);

-- WRITE
INSERT INTO "waiters" ("id", "waiter_name") VALUES
    ('W001', 'Aman Verma'), ('W002', 'Kabir Shah'), ('W003', 'Rohan Mehra'), ('W004', 'Ishita Rao');

-- WRITE
INSERT INTO "restaurant_orders" ("order_id", "guest_id", "dish", "order_time", "waiter_id") VALUES
    ('O001', 'G001', 'Mushroom Risotto',   '19:42', 'W003'),
    ('O002', 'G002', 'Grilled Salmon',     '19:40', 'W001'),
    ('O003', 'G003', 'Chicken Alfredo',    '19:41', 'W002'),
    ('O004', 'G004', 'Caesar Salad',       '19:39', 'W001'),
    ('O005', 'G005', 'Beef Steak',         '19:43', 'W002'),
    ('O006', 'G006', 'Tomato Pasta',       '19:40', 'W004'),
    ('O007', 'G007', 'Lamb Chops',         '19:42', 'W001'),
    ('O008', 'G008', 'Mushroom Risotto',   '19:44', 'W003'),
    ('O009', 'G009', 'Margherita Pizza',   '19:38', 'W004'),
    ('O010', 'G010', 'Grilled Vegetables', '19:41', 'W002');

-- WRITE
INSERT INTO "employees" ("employee_id", "employee_name", "job_title") VALUES
    ('E001', 'Aman Verma',     'Waiter'),
    ('E002', 'Kabir Shah',     'Waiter'),
    ('E003', 'Rohan Mehra',    'Waiter'),
    ('E004', 'Ishita Rao',     'Waiter'),
    ('E005', 'Vikram Das',     'Head Chef'),
    ('E006', 'Nitin Arora',    'Sous Chef'),
    ('E007', 'Pooja Nair',     'Cashier'),
    ('E008', 'Rahul Sen',      'Manager'),
    ('E009', 'Arjun Malhotra', 'Security Officer'),
    ('E010', 'Kavita Rao',     'Accountant');

-- WRITE
INSERT INTO "kitchen_logs" ("log_id", "employee_id", "action", "timestamp", "kitchen_area") VALUES
    ('K001', 'E001', 'Entered Kitchen',           '19:25', 'Main Kitchen'),
    ('K002', 'E002', 'Entered Kitchen',           '19:31', 'Main Kitchen'),
    ('K003', 'E003', 'Entered Kitchen',           '19:44', 'Main Kitchen'),
    ('K004', 'E004', 'Entered Kitchen',           '19:36', 'Main Kitchen'),
    ('K005', 'E003', 'Collected Mushroom Risotto', '19:45', 'Plating Area'),
    ('K006', 'E002', 'Collected Chicken Alfredo',  '19:46', 'Plating Area'),
    ('K007', 'E001', 'Collected Grilled Salmon',   '19:44', 'Plating Area'),
    ('K008', 'E004', 'Collected Tomato Pasta',     '19:45', 'Plating Area'),
    ('K009', 'E003', 'Exited Kitchen',            '19:47', 'Main Kitchen'),
    ('K010', 'E002', 'Exited Kitchen',            '19:48', 'Main Kitchen');

-- WRITE
INSERT INTO "access_cards" ("access_id", "employee_id", "access_area", "access_time", "action") VALUES
    ('A001', 'E001', 'Kitchen',      '19:24', 'Entry'),
    ('A002', 'E002', 'Kitchen',      '19:30', 'Entry'),
    ('A003', 'E003', 'Kitchen',      '19:44', 'Entry'),
    ('A004', 'E004', 'Kitchen',      '19:35', 'Entry'),
    ('A005', 'E003', 'Kitchen',      '19:47', 'Exit'),
    ('A006', 'E002', 'Kitchen',      '19:48', 'Exit'),
    ('A007', 'E001', 'Kitchen',      '19:51', 'Exit'),
    ('A008', 'E004', 'Kitchen',      '19:52', 'Exit'),
    ('A009', 'E003', 'Staff Office', '20:03', 'Entry'),
    ('A010', 'E003', 'Staff Office', '20:11', 'Exit');

-- WRITE
INSERT INTO "bank_accounts" ("account_id", "account_number", "owner_type", "owner_id") VALUES
    ('B001', '48120591', 'Employee', 'E001'),
    ('B002', '57231864', 'Employee', 'E002'),
    ('B003', '69342178', 'Employee', 'E003'),
    ('B004', '81452963', 'Employee', 'E004'),
    ('B005', '92561743', 'Employee', 'E005'),
    ('B006', '34681295', 'Employee', 'E006'),
    ('B007', '75193426', 'Employee', 'E007'),
    ('B008', '62845197', 'Employee', 'E008'),
    ('B009', '51736284', 'Guest',    'G008'),
    ('B010', '83219475', 'Guest',    'G005');

-- WRITE
INSERT INTO "payments" ("payment_id", "sender_account", "receiver_account", "amount", "payment_time", "description") VALUES
    ('P001', 'B010', 'B002', 12000, '18:12', 'Consulting'),
    ('P002', 'B005', 'B007',  8500, '17:43', 'Staff Expense'),
    ('P003', 'B009', 'B003', 50000, '18:56', NULL),
    ('P004', 'B001', 'B008',  4500, '16:22', 'Personal'),
    ('P005', 'B006', 'B005',  9200, '15:31', 'Supplies'),
    ('P006', 'B004', 'B007',  3800, '17:12', 'Reimbursement'),
    ('P007', 'B008', 'B006',  6700, '14:50', 'Maintenance'),
    ('P008', 'B002', 'B001',  2500, '13:45', 'Loan'),
    ('P009', 'B005', 'B010', 11000, '12:32', 'Contractor'),
    ('P010', 'B007', 'B004',  1800, '11:21', 'Reimbursement');

-- WRITE
INSERT INTO "phone_records" ("phone_record_id", "phone_number", "owner_id", "associated_account", "call_time", "duration") VALUES
    ('PR001', '9876500011', 'E001', 'B001', '18:10', 120),
    ('PR002', '9876500022', 'E002', 'B002', '18:22',  90),
    ('PR003', '9876500033', 'E003', 'B003', '18:54',  45),
    ('PR004', '9876500044', 'E004', 'B004', '18:30', 180),
    ('PR005', '9876500055', 'E005', 'B005', '18:41',  60),
    ('PR006', '9876500066', 'E006', 'B006', '18:20', 120),
    ('PR007', '9876500077', 'E007', 'B007', '18:15',  30),
    ('PR008', '9876500088', 'E008', 'B008', '18:05', 240),
    ('PR009', '9876500099', 'G008', 'B009', '18:51', 300),
    ('PR010', '9876500010', 'G005', 'B010', '17:48',  90);

-- 0.3 Players. Passwords are placeholders: the app stores Argon2id hashes,
-- which are produced in Node and cannot be generated in SQL.

-- WRITE
INSERT INTO "users" ("username", "email", "password") VALUES
    ('detective', 'detective@example.com', NULL),
    ('ananya',    'ananya@example.com',    '$argon2id$placeholder'),
    ('kabir',     'kabir@example.com',     '$argon2id$placeholder');

-- WRITE
INSERT INTO "user_progress" ("userId", "caseId", "status", "locationId", "sequenceId") VALUES
    (2, 'C001', 'IN_PROGRESS', 'L003', 11),
    (3, 'C001', 'COMPLETED',   'L001', NULL);

-- WRITE
COMMIT;



-- =============================================================================
-- MODULE 1: IDENTITY, AUTHENTICATION & PLAYER DIRECTORY
-- Canonical Tables: users, user_progress, cases
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1.1 Registration Availability Check
-- Looks for an existing username or email so the player gets a field-level
-- error. The unique indexes are what actually stop duplicates.
-- Params: username = 'rhea', email = 'rhea@example.com'
-- Source: src/services/auth.service.js, createUser
-- -----------------------------------------------------------------------------
-- READ
SELECT
    u."id",
    u."username",
    u."email"
FROM "users" u
WHERE u."username" = 'rhea'
   OR u."email" = 'rhea@example.com';


-- -----------------------------------------------------------------------------
-- 1.2 Register Player
-- Inserts a new account. The password is an Argon2id hash made in Node.
-- Params: username, email, password hash
-- Source: src/services/auth.service.js, createUser
-- -----------------------------------------------------------------------------
-- WRITE
INSERT INTO "users" (
    "username",
    "email",
    "password"
) VALUES (
    'rhea',
    'rhea@example.com',
    '$argon2id$placeholder'
)
RETURNING "id", "username", "email";


-- -----------------------------------------------------------------------------
-- 1.3 Login Credential Lookup
-- The identifier may be either a username or an email address.
-- Params: identifier = 'ananya'
-- Source: src/services/auth.service.js, verifyCredentials
-- -----------------------------------------------------------------------------
-- READ
SELECT
    u."id",
    u."username",
    u."email",
    u."password"
FROM "users" u
WHERE u."username" = 'ananya'
   OR u."email" = 'ananya'
LIMIT 1;


-- -----------------------------------------------------------------------------
-- 1.4 Player Directory with Case Progress
-- One row per player and case they started; players with no progress still
-- appear with NULL case columns.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    u."id" AS user_id,
    u."username",
    u."email",
    c."caseName",
    up."status",
    up."sequenceId"
FROM "users" u
LEFT JOIN "user_progress" up ON up."userId" = u."id"
LEFT JOIN "cases" c ON c."id" = up."caseId"
ORDER BY u."id", c."caseName";


-- -----------------------------------------------------------------------------
-- 1.5 Players Who Have Not Started Any Case
-- LEFT JOIN anti-join: a player with no user_progress row has NULLs on the
-- right-hand side.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    u."id",
    u."username"
FROM "users" u
LEFT JOIN "user_progress" up ON up."userId" = u."id"
WHERE up."userId" IS NULL;


-- -----------------------------------------------------------------------------
-- 1.6 Delete Player Account
-- user_progress rows are removed with the account (ON DELETE CASCADE).
-- Params: username = 'rhea'
-- -----------------------------------------------------------------------------
-- WRITE
DELETE FROM "users"
WHERE "username" = 'rhea'
RETURNING "id", "username";



-- =============================================================================
-- MODULE 2: CASE CATALOGUE & STORY FLOW
-- Canonical Tables: cases, locations, npcs, dialogues, case_progress, queries
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2.1 Title Screen Case List with Step Counts
-- Every case with its start location and number of steps.
-- Source: src/controllers/case.controller.js, getCases
-- -----------------------------------------------------------------------------
-- READ
SELECT
    c."id",
    c."caseName",
    c."difficulty",
    sl."locationName" AS start_location,
    COUNT(cp."id") AS "stepCount"
FROM "cases" c
LEFT JOIN "locations" sl ON sl."id" = c."startLocationId"
LEFT JOIN "case_progress" cp ON cp."caseId" = c."id"
GROUP BY c."id", sl."id"
ORDER BY c."id";


-- -----------------------------------------------------------------------------
-- 2.2 Full Case Flow in Order
-- Each step with the NPC who speaks and the question asked. The grading
-- columns (queryOutput, answerValues, maxRows) are left out on purpose so the
-- client cannot read the answers.
-- Params: caseId = 'C001'
-- Source: src/controllers/case.controller.js, getCaseSteps
-- -----------------------------------------------------------------------------
-- READ
SELECT
    cp."sequenceId",
    CASE WHEN cp."queryId" IS NOT NULL THEN 'query' ELSE 'dialogue' END AS "stepType",
    l."locationName",
    n."npcName",
    d."dialoguesList"[1] AS "line",
    q."title" AS "queryTitle",
    q."question"
FROM "case_progress" cp
LEFT JOIN "locations" l ON l."id" = cp."locationId"
LEFT JOIN "dialogues" d ON d."id" = cp."dialogueId"
LEFT JOIN "npcs"      n ON n."id" = d."npcId"
LEFT JOIN "queries"   q ON q."id" = cp."queryId"
WHERE cp."caseId" = 'C001'
ORDER BY cp."sequenceId";


-- -----------------------------------------------------------------------------
-- 2.3 Create Case Steps View
-- Packages the four-way LEFT JOIN from 2.2 so later reports reuse it.
-- -----------------------------------------------------------------------------
-- WRITE
CREATE OR REPLACE VIEW "v_case_steps" AS
SELECT
    cp."caseId",
    cp."sequenceId",
    cp."locationId",
    l."locationName",
    cp."dialogueId",
    n."npcName",
    cp."queryId",
    q."title" AS "queryTitle"
FROM "case_progress" cp
LEFT JOIN "locations" l ON l."id" = cp."locationId"
LEFT JOIN "dialogues" d ON d."id" = cp."dialogueId"
LEFT JOIN "npcs"      n ON n."id" = d."npcId"
LEFT JOIN "queries"   q ON q."id" = cp."queryId";


-- -----------------------------------------------------------------------------
-- 2.4 Read Case Steps Through the View
-- Params: caseId = 'C001'
-- -----------------------------------------------------------------------------
-- READ
SELECT
    v.*
FROM "v_case_steps" v
WHERE v."caseId" = 'C001'
ORDER BY v."sequenceId";


-- -----------------------------------------------------------------------------
-- 2.5 Dialogue and Query Steps per Location
-- How many story steps and SQL questions each location holds in a case.
-- Params: caseId = 'C001'
-- -----------------------------------------------------------------------------
-- READ
SELECT
    v."locationName",
    COUNT(v."dialogueId") AS dialogue_steps,
    COUNT(v."queryId")    AS query_steps,
    MIN(v."sequenceId")   AS first_visit
FROM "v_case_steps" v
WHERE v."caseId" = 'C001'
GROUP BY v."locationName"
ORDER BY first_visit;


-- -----------------------------------------------------------------------------
-- 2.6 NPCs Who Speak at a Location
-- Distinct NPCs with dialogue at a location, in any case.
-- Params: locationId = 'L001'
-- Source: src/controllers/location.controller.js, getLocationNpcs
-- -----------------------------------------------------------------------------
-- READ
SELECT DISTINCT
    n."id",
    n."npcName",
    n."role"
FROM "dialogues" d
INNER JOIN "npcs" n ON n."id" = d."npcId"
WHERE d."locationId" = 'L001';


-- -----------------------------------------------------------------------------
-- 2.7 Every NPC Line, One Row per Line
-- dialoguesList is a TEXT[] (see 01_normalization.md, section 4), so UNNEST
-- is needed to treat its elements as rows.
-- Params: caseId = 'C001'
-- -----------------------------------------------------------------------------
-- READ
SELECT
    d."id",
    n."npcName",
    line.no,
    line.text
FROM "dialogues" d
INNER JOIN "npcs" n ON n."id" = d."npcId"
CROSS JOIN LATERAL UNNEST(d."dialoguesList") WITH ORDINALITY AS line(text, no)
WHERE d."caseId" = 'C001'
ORDER BY d."id", line.no;


-- -----------------------------------------------------------------------------
-- 2.8 Questions per Difficulty Level
-- Keeps only levels with more than one question.
-- Params: caseId = 'C001'
-- -----------------------------------------------------------------------------
-- READ
SELECT
    q."difficulty",
    COUNT(*) AS questions,
    STRING_AGG(q."id", ', ' ORDER BY q."id") AS ids
FROM "queries" q
WHERE q."caseId" = 'C001'
GROUP BY q."difficulty"
HAVING COUNT(*) > 1
ORDER BY questions DESC;



-- =============================================================================
-- MODULE 3: PLAYER PROGRESS, GRADING & LEADERBOARD
-- Canonical Tables: user_progress, case_progress, queries, evidences,
--                   _EvidenceToQuery, users, locations
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 Player Progress per Case
-- Cases a player has started, with the name of their current location.
-- Params: userId = 2
-- Source: src/controllers/user.controller.js, getUserProgress
-- -----------------------------------------------------------------------------
-- READ
SELECT
    up."caseId",
    c."caseName",
    up."status",
    up."sequenceId",
    l."locationName"
FROM "user_progress" up
INNER JOIN "cases" c ON c."id" = up."caseId"
LEFT JOIN "locations" l ON l."id" = up."locationId"
WHERE up."userId" = 2
ORDER BY up."caseId";


-- -----------------------------------------------------------------------------
-- 3.2 Save Player Position (Upsert)
-- One row per (userId, caseId), so saving after a step is an upsert on that
-- unique key.
-- Params: userId, caseId, status, locationId, sequenceId
-- Source: src/services/caseSession.service.js, savePosition
-- -----------------------------------------------------------------------------
-- WRITE
INSERT INTO "user_progress" (
    "userId",
    "caseId",
    "status",
    "locationId",
    "sequenceId"
) VALUES (
    4,
    'C001',
    'IN_PROGRESS',
    'L001',
    2
)
ON CONFLICT ("userId", "caseId")
DO UPDATE SET
    "status"     = EXCLUDED."status",
    "locationId" = EXCLUDED."locationId",
    "sequenceId" = EXCLUDED."sequenceId"
RETURNING *;


-- -----------------------------------------------------------------------------
-- 3.3 Grading Data for the Player's Current Query Step
-- Answer rules for the step the player is on, plus the evidence a correct
-- answer reveals.
-- Params: userId = 2, caseId = 'C001'
-- Source: src/services/caseSession.service.js, answerQuery
-- -----------------------------------------------------------------------------
-- READ
SELECT
    q."id",
    q."answerValues",
    q."maxRows",
    q."unlockMessage",
    e."evidenceName",
    e."description" AS "evidenceDescription"
FROM "user_progress" up
INNER JOIN "case_progress" cp ON cp."caseId" = up."caseId"
                             AND cp."sequenceId" = up."sequenceId"
INNER JOIN "queries" q ON q."id" = cp."queryId"
INNER JOIN "_EvidenceToQuery" eq ON eq."B" = q."id"
INNER JOIN "evidences" e ON e."id" = eq."A"
WHERE up."userId" = 2
  AND up."caseId" = 'C001';


-- -----------------------------------------------------------------------------
-- 3.4 Evidence Already Discovered
-- Every query step before the player's current position. A completed case has
-- sequenceId NULL and counts as past every step.
-- Params: userId = 2, caseId = 'C001'
-- Source: src/services/caseProgression.js, discoveredEvidence
-- -----------------------------------------------------------------------------
-- READ
SELECT
    cp."sequenceId",
    e."id",
    e."evidenceName"
FROM "user_progress" up
INNER JOIN "case_progress" cp ON cp."caseId" = up."caseId"
INNER JOIN "_EvidenceToQuery" eq ON eq."B" = cp."queryId"
INNER JOIN "evidences" e ON e."id" = eq."A"
WHERE up."userId" = 2
  AND up."caseId" = 'C001'
  AND (up."sequenceId" IS NULL OR cp."sequenceId" < up."sequenceId")
ORDER BY cp."sequenceId";


-- -----------------------------------------------------------------------------
-- 3.5 Mark Case Completed (Demonstration Transaction)
-- Updates the row, shows it, then rolls back so the sample data stays as
-- loaded.
-- Params: userId = 2, caseId = 'C001'
-- -----------------------------------------------------------------------------
-- WRITE
BEGIN;

-- WRITE
UPDATE "user_progress"
SET
    "status"     = 'COMPLETED',
    "sequenceId" = NULL
WHERE "userId" = 2
  AND "caseId" = 'C001'
RETURNING *;

-- WRITE
ROLLBACK;


-- -----------------------------------------------------------------------------
-- 3.6 Player Leaderboard with Completion Percentage
-- Share of each case's steps every player has cleared. A completed case counts
-- as all steps; otherwise the steps before the current one are done. The
-- per-case step totals are a derived table joined in as a source.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    u."username",
    up."caseId",
    up."status",
    CASE WHEN up."status" = 'COMPLETED' THEN t.total
         ELSE COALESCE(up."sequenceId", 1) - 1 END AS steps_done,
    t.total AS total_steps,
    ROUND(
        100.0 * CASE WHEN up."status" = 'COMPLETED' THEN t.total
                     ELSE COALESCE(up."sequenceId", 1) - 1 END
        / t.total, 1
    ) AS pct_done,
    RANK() OVER (
        PARTITION BY up."caseId"
        ORDER BY up."status" DESC, up."sequenceId" DESC NULLS FIRST
    ) AS "rank"
FROM "user_progress" up
INNER JOIN "users" u ON u."id" = up."userId"
INNER JOIN (
    SELECT "caseId", COUNT(*) AS total
    FROM "case_progress"
    GROUP BY "caseId"
) t ON t."caseId" = up."caseId"
ORDER BY up."caseId", "rank";



-- =============================================================================
-- MODULE 4: INVESTIGATION SCHEMA BROWSER
-- Canonical Tables: query_tables, investigation_tables,
--                   information_schema.columns
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1 Investigation Tables a Case Exposes
-- Params: caseId = 'C001'
-- -----------------------------------------------------------------------------
-- READ
SELECT
    it."id",
    it."tableName",
    it."displayName",
    it."description"
FROM "query_tables" qt
INNER JOIN "investigation_tables" it ON it."id" = qt."tableId"
WHERE qt."caseId" = 'C001'
ORDER BY it."id";


-- -----------------------------------------------------------------------------
-- 4.2 Columns of Each Exposed Table
-- For the in-game schema browser. Joins the case's tables to the system
-- catalogue by table name; it reads the catalogue, not the game tables.
-- Params: caseId = 'C001'
-- Source: src/services/caseSession.service.js, describeTables
-- -----------------------------------------------------------------------------
-- READ
SELECT
    c.table_name,
    c.column_name,
    c.data_type
FROM "query_tables" qt
INNER JOIN "investigation_tables" it ON it."id" = qt."tableId"
INNER JOIN information_schema.columns c ON c.table_name = it."tableName"
                                       AND c.table_schema = current_schema()
WHERE qt."caseId" = 'C001'
ORDER BY c.table_name, c.ordinal_position;



-- =============================================================================
-- MODULE 5: CASE QUESTION SOLUTIONS (Q001 – Q008)
-- Canonical Tables: guests, restaurant_orders, waiters, employees, kitchen_logs,
--                   access_cards, bank_accounts, payments
-- Each query passes the grader: the result has at most maxRows rows and one
-- row contains every value in answerValues.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5.1 Q001 — What dish did Vikram Malhotra order?
-- Expects: Mushroom Risotto
-- -----------------------------------------------------------------------------
-- READ
SELECT
    ro.dish
FROM restaurant_orders ro
INNER JOIN guests g ON g.guest_id = ro.guest_id
WHERE g.guest_name = 'Vikram Malhotra';


-- -----------------------------------------------------------------------------
-- 5.2 Q002 — Which waiter delivered Vikram's Mushroom Risotto?
-- Expects: Rohan Mehra
-- -----------------------------------------------------------------------------
-- READ
SELECT
    w.waiter_name
FROM restaurant_orders ro
INNER JOIN guests  g ON g.guest_id = ro.guest_id
INNER JOIN waiters w ON w.id = ro.waiter_id
WHERE g.guest_name = 'Vikram Malhotra'
  AND ro.dish = 'Mushroom Risotto';


-- -----------------------------------------------------------------------------
-- 5.3 Q003 — Did Rohan Mehra enter the kitchen?
-- Expects: Entered Kitchen, 19:44
-- -----------------------------------------------------------------------------
-- READ
SELECT
    kl.action,
    kl."timestamp",
    kl.kitchen_area
FROM kitchen_logs kl
INNER JOIN employees e ON e.employee_id = kl.employee_id
WHERE e.employee_name = 'Rohan Mehra'
ORDER BY kl."timestamp"::time;


-- -----------------------------------------------------------------------------
-- 5.4 Q004 — Does the access-card system confirm it?
-- Expects: Kitchen, Entry, 19:44
-- Matches each card swipe against a kitchen log entry at the same minute.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    ac.access_area,
    ac.action,
    ac.access_time,
    kl.action AS log_action
FROM access_cards ac
INNER JOIN employees e     ON e.employee_id = ac.employee_id
INNER JOIN kitchen_logs kl ON kl.employee_id = ac.employee_id
                          AND kl."timestamp" = ac.access_time
                          AND kl.action = 'Entered Kitchen'
WHERE e.employee_name = 'Rohan Mehra';


-- -----------------------------------------------------------------------------
-- 5.5 Q005 — Was Rohan paid before the murder?
-- Expects: 50000
-- The risotto was ordered at 19:42, so "before" means earlier than that.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    p.payment_id,
    p.amount,
    p.payment_time
FROM payments p
INNER JOIN bank_accounts b ON b.account_id = p.receiver_account
INNER JOIN employees e     ON e.employee_id = b.owner_id
                          AND b.owner_type = 'Employee'
WHERE e.employee_name = 'Rohan Mehra'
  AND p.payment_time::time < '19:42'::time;


-- -----------------------------------------------------------------------------
-- 5.6 Q006 — Which account sent the ₹50,000?
-- Expects: B009
-- Payment -> receiving account -> its employee owner, all by JOIN.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    p.sender_account
FROM payments p
INNER JOIN bank_accounts b ON b.account_id = p.receiver_account
INNER JOIN employees e     ON e.employee_id = b.owner_id
                          AND b.owner_type = 'Employee'
WHERE e.employee_name = 'Rohan Mehra'
  AND p.amount = 50000;


-- -----------------------------------------------------------------------------
-- 5.7 Q007 — Who owns account B009?
-- Expects: Arvind Khanna
-- owner_id points at a guest or an employee depending on owner_type, so both
-- tables are LEFT JOINed and owner_type picks the right one.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    b.account_id,
    COALESCE(g.guest_name, e.employee_name) AS owner_name,
    b.owner_type
FROM bank_accounts b
LEFT JOIN guests    g ON b.owner_type = 'Guest'    AND g.guest_id    = b.owner_id
LEFT JOIN employees e ON b.owner_type = 'Employee' AND e.employee_id = b.owner_id
WHERE b.account_id = 'B009';


-- -----------------------------------------------------------------------------
-- 5.8 Q008 — Who planned the murder?
-- Expects: Arvind Khanna
-- The whole chain in one statement: victim's order -> waiter -> waiter's
-- employee record -> payment received -> sending account -> its owner.
-- -----------------------------------------------------------------------------
-- READ
WITH victim_order AS (
    SELECT
        ro.waiter_id
    FROM restaurant_orders ro
    INNER JOIN guests g ON g.guest_id = ro.guest_id
    WHERE g.guest_name = 'Vikram Malhotra'
),
waiter_account AS (
    SELECT
        b.account_id
    FROM victim_order vo
    INNER JOIN waiters w       ON w.id = vo.waiter_id
    INNER JOIN employees e     ON e.employee_name = w.waiter_name
    INNER JOIN bank_accounts b ON b.owner_type = 'Employee'
                              AND b.owner_id = e.employee_id
),
bribe AS (
    SELECT
        p.sender_account
    FROM payments p
    INNER JOIN waiter_account wa ON wa.account_id = p.receiver_account
    ORDER BY p.amount DESC
    LIMIT 1
)
SELECT
    g.guest_name AS mastermind,
    g.role,
    g.is_suspect
FROM bribe
INNER JOIN bank_accounts b ON b.account_id = bribe.sender_account
INNER JOIN guests g        ON b.owner_type = 'Guest'
                          AND g.guest_id = b.owner_id;



-- =============================================================================
-- MODULE 6: INVESTIGATION ANALYTICS & REPORTS
-- Canonical Tables: kitchen_logs, employees, waiters, bank_accounts, guests,
--                   payments
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 6.1 Time Between Each Employee's Kitchen Events
-- Window function: LAG over each employee's log, ordered by time.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    e.employee_name,
    kl.action,
    kl."timestamp",
    kl."timestamp"::time
        - LAG(kl."timestamp"::time) OVER (
            PARTITION BY kl.employee_id
            ORDER BY kl."timestamp"::time
        ) AS since_previous
FROM kitchen_logs kl
INNER JOIN employees e ON e.employee_id = kl.employee_id
ORDER BY e.employee_name, kl."timestamp"::time;


-- -----------------------------------------------------------------------------
-- 6.2 Money In and Out of Every Account
-- Totals received and sent per account, with the owner's name resolved from
-- whichever table owner_type points at.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    b.account_id,
    COALESCE(g.guest_name, e.employee_name) AS owner_name,
    COALESCE(SUM(p.amount) FILTER (WHERE p.receiver_account = b.account_id), 0) AS received,
    COALESCE(SUM(p.amount) FILTER (WHERE p.sender_account   = b.account_id), 0) AS sent
FROM bank_accounts b
LEFT JOIN guests    g ON b.owner_type = 'Guest'    AND g.guest_id    = b.owner_id
LEFT JOIN employees e ON b.owner_type = 'Employee' AND e.employee_id = b.owner_id
LEFT JOIN payments  p ON b.account_id IN (p.sender_account, p.receiver_account)
GROUP BY b.account_id, owner_name
ORDER BY received DESC;


-- -----------------------------------------------------------------------------
-- 6.3 Payments Larger Than the Average Payment
-- The average is computed once in a derived table and joined to every payment.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    p.payment_id,
    p.sender_account,
    p.receiver_account,
    p.amount
FROM payments p
INNER JOIN (
    SELECT AVG(amount) AS avg_amount
    FROM payments
) a ON p.amount > a.avg_amount
ORDER BY p.amount DESC;


-- -----------------------------------------------------------------------------
-- 6.4 People Who Are Both a Waiter and an Employee Waiter (INTERSECT)
-- waiters has no link to employees, so a name is the only shared value.
-- -----------------------------------------------------------------------------
-- READ
SELECT waiter_name AS name
FROM waiters
INTERSECT
SELECT employee_name
FROM employees
WHERE job_title = 'Waiter';


-- -----------------------------------------------------------------------------
-- 6.5 Employee Waiters Missing from the Waiters Table (EXCEPT)
-- -----------------------------------------------------------------------------
-- READ
SELECT employee_name AS waiter_missing_from_waiters
FROM employees
WHERE job_title = 'Waiter'
EXCEPT
SELECT waiter_name
FROM waiters;



-- =============================================================================
-- MODULE 7: DATA INTEGRITY CHECKS
-- Canonical Tables: case_progress, bank_accounts, guests, employees, queries,
--                   _EvidenceToQuery
-- Each check should return zero rows on healthy data.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 7.1 Steps That Are Not Exactly One of Dialogue or Query
-- The schema does not enforce this; the application assumes it.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    cp."id",
    cp."dialogueId",
    cp."queryId"
FROM "case_progress" cp
WHERE (cp."dialogueId" IS NULL) = (cp."queryId" IS NULL);


-- -----------------------------------------------------------------------------
-- 7.2 Bank Account Owners That Match Neither Table
-- bank_accounts.owner_id has no foreign key because it can point at two
-- tables. Both LEFT JOINs coming back empty also catches an unknown owner_type.
-- -----------------------------------------------------------------------------
-- READ
SELECT
    b.account_id,
    b.owner_type,
    b.owner_id
FROM bank_accounts b
LEFT JOIN guests    g ON b.owner_type = 'Guest'    AND g.guest_id    = b.owner_id
LEFT JOIN employees e ON b.owner_type = 'Employee' AND e.employee_id = b.owner_id
WHERE g.guest_id IS NULL
  AND e.employee_id IS NULL;


-- -----------------------------------------------------------------------------
-- 7.3 Questions a Player Could Never Pass
-- A question with no evidence attached or no case step placing it.
-- -----------------------------------------------------------------------------
-- READ
SELECT DISTINCT
    q."id",
    q."title",
    eq."B"  IS NULL AS no_evidence,
    cp."id" IS NULL AS not_placed
FROM "queries" q
LEFT JOIN "_EvidenceToQuery" eq ON eq."B" = q."id"
LEFT JOIN "case_progress"    cp ON cp."queryId" = q."id"
WHERE eq."B" IS NULL
   OR cp."id" IS NULL;