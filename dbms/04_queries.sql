-- Case-SELECT: SQL queries (CP3)
--
-- Runs against the schema in 03_schema.sql. The file is in four parts:
--   Part 1  Sample data: case C001 and its investigation records, as loaded
--           by prisma/seed.js from prisma/data/caseC001.js.
--   Part 2  Queries the application runs. Each one is the SQL form of a
--           Prisma call in src/, and the comment names the file it comes from.
--   Part 3  The solutions to the eight case questions (Q001 to Q008), i.e.
--           queries a player can type in the game to pass each step.
--   Part 4  Reports and integrity checks over the game data: aggregates,
--           joins, CTEs, window functions, views and set operations.
--
-- Every statement is tagged on the line directly above it:
--   -- READ    the statement only reads data (SELECT).
--   -- WRITE   the statement changes data or schema (INSERT, UPDATE, DELETE,
--              TRUNCATE, CREATE VIEW). BEGIN / COMMIT / ROLLBACK are tagged
--              WRITE too, because they only exist to frame writes.
--
-- Where a query needs rows from more than one table it uses JOINs (INNER,
-- LEFT, CROSS LATERAL) rather than IN / EXISTS / scalar subqueries. The only
-- subqueries left are derived tables used as a JOIN source (4.4, 4.9) and
-- CTEs (Q008). INTERSECT / EXCEPT in 4.10 are kept as the set-operation demo.
--
-- Times in the investigation tables are stored as TEXT ('19:44'), matching the
-- schema, so queries that compare them cast to TIME.
--
-- Run with:
--   psql -v ON_ERROR_STOP=1 -f 03_schema.sql  <database>
--   psql -v ON_ERROR_STOP=1 -f 04_queries.sql <database>
-- Part 1 empties the tables first, so this file can be run more than once.


-- ═════════════════════════════ Part 1: Sample data ═════════════════════════════

-- WRITE
BEGIN;

-- WRITE
TRUNCATE "users", "user_progress", "cases", "npcs", "locations", "dialogues",
         "case_progress", "evidences", "queries", "investigation_tables",
         "query_tables", "_EvidenceToQuery", "guests", "waiters",
         "restaurant_orders", "employees", "kitchen_logs", "access_cards",
         "bank_accounts", "payments", "phone_records"
RESTART IDENTITY CASCADE;

-- 1.1 Case content

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

-- 1.2 Investigation records (the tables players query)

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

-- 1.3 Players. Passwords are placeholders: the app stores Argon2id hashes,
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


-- ═══════════════════ Part 2: Queries the application runs ═══════════════════

-- 2.1 Title screen: every case with its number of steps.
--     src/controllers/case.controller.js, getCases
-- READ
SELECT c."id", c."caseName", c."difficulty", COUNT(cp."id") AS "stepCount"
FROM "cases" c
LEFT JOIN "case_progress" cp ON cp."caseId" = c."id"
GROUP BY c."id"
ORDER BY c."id";

-- 2.2 Full case flow in order, with the NPC who speaks and the question asked.
--     The grading columns (queryOutput, answerValues, maxRows) are left out
--     on purpose so the client cannot read the answers.
--     src/controllers/case.controller.js, getCaseSteps
-- READ
SELECT cp."sequenceId",
       CASE WHEN cp."queryId" IS NOT NULL THEN 'query' ELSE 'dialogue' END AS "stepType",
       l."locationName",
       n."npcName",
       d."dialoguesList"[1] AS "line",
       q."title"            AS "queryTitle",
       q."question"
FROM "case_progress" cp
LEFT JOIN "locations" l ON l."id" = cp."locationId"
LEFT JOIN "dialogues" d ON d."id" = cp."dialogueId"
LEFT JOIN "npcs"      n ON n."id" = d."npcId"
LEFT JOIN "queries"   q ON q."id" = cp."queryId"
WHERE cp."caseId" = 'C001'
ORDER BY cp."sequenceId";

-- 2.3 Registration: check the username and email are free, then insert.
--     The unique indexes are what actually stop duplicates; the SELECT only
--     gives the player a field-level error message.
--     src/services/auth.service.js, createUser
-- READ
SELECT "username", "email"
FROM "users"
WHERE "username" = 'rhea' OR "email" = 'rhea@example.com';

-- WRITE
INSERT INTO "users" ("username", "email", "password")
VALUES ('rhea', 'rhea@example.com', '$argon2id$placeholder')
RETURNING "id", "username", "email";

-- 2.4 Login: the identifier may be either a username or an email.
--     src/services/auth.service.js, verifyCredentials
-- READ
SELECT "id", "username", "email", "password"
FROM "users"
WHERE "username" = 'ananya' OR "email" = 'ananya'
LIMIT 1;

-- 2.5 A player's progress in each case they have started.
--     src/controllers/user.controller.js, getUserProgress
-- READ
SELECT up."caseId", up."status", up."sequenceId", l."locationName"
FROM "user_progress" up
LEFT JOIN "locations" l ON l."id" = up."locationId"
WHERE up."userId" = 2
ORDER BY up."caseId";

-- 2.6 Save a player's position after a step. One row per (userId, caseId),
--     so this is an upsert on that unique key.
--     src/services/caseSession.service.js, savePosition
-- WRITE
INSERT INTO "user_progress" ("userId", "caseId", "status", "locationId", "sequenceId")
VALUES (4, 'C001', 'IN_PROGRESS', 'L001', 2)
ON CONFLICT ("userId", "caseId")
DO UPDATE SET "status"     = EXCLUDED."status",
              "locationId" = EXCLUDED."locationId",
              "sequenceId" = EXCLUDED."sequenceId"
RETURNING *;

-- 2.7 Distinct NPCs who speak at a location, in any case.
--     src/controllers/location.controller.js, getLocationNpcs
-- READ
SELECT DISTINCT n."id", n."npcName", n."role"
FROM "dialogues" d
JOIN "npcs" n ON n."id" = d."npcId"
WHERE d."locationId" = 'L001';

-- 2.8 Columns of each investigation table a case exposes, for the in-game
--     schema browser. Reads the system catalogue, not the game tables.
--     The case's tables are joined to the catalogue by table name.
--     src/services/caseSession.service.js, describeTables
-- READ
SELECT c.table_name, c.column_name, c.data_type
FROM "query_tables" qt
JOIN "investigation_tables" it ON it."id" = qt."tableId"
JOIN information_schema.columns c ON c.table_name = it."tableName"
                                 AND c.table_schema = current_schema()
WHERE qt."caseId" = 'C001'
ORDER BY c.table_name, c.ordinal_position;

-- 2.9 Grading data for the player's current query step and the evidence a
--     correct answer reveals.
--     src/services/caseSession.service.js, answerQuery
-- READ
SELECT q."id", q."answerValues", q."maxRows", q."unlockMessage",
       e."evidenceName", e."description" AS "evidenceDescription"
FROM "user_progress" up
JOIN "case_progress" cp ON cp."caseId" = up."caseId" AND cp."sequenceId" = up."sequenceId"
JOIN "queries" q        ON q."id" = cp."queryId"
JOIN "_EvidenceToQuery" eq ON eq."B" = q."id"
JOIN "evidences" e      ON e."id" = eq."A"
WHERE up."userId" = 2 AND up."caseId" = 'C001';

-- 2.10 Evidence a player has already found: every query step before their
--      current position. A completed case has sequenceId NULL and counts as
--      past every step.
--      src/services/caseProgression.js, discoveredEvidence
-- READ
SELECT cp."sequenceId", e."id", e."evidenceName"
FROM "user_progress" up
JOIN "case_progress" cp ON cp."caseId" = up."caseId"
JOIN "_EvidenceToQuery" eq ON eq."B" = cp."queryId"
JOIN "evidences" e ON e."id" = eq."A"
WHERE up."userId" = 2 AND up."caseId" = 'C001'
  AND (up."sequenceId" IS NULL OR cp."sequenceId" < up."sequenceId")
ORDER BY cp."sequenceId";

-- 2.11 Delete an account. user_progress rows go with it (ON DELETE CASCADE).
-- WRITE
DELETE FROM "users" WHERE "username" = 'rhea';


-- ═══════════════════ Part 3: Solutions to the case questions ═══════════════════
-- Each query passes the grader: the result has at most maxRows rows and one
-- row contains every value in answerValues.

-- Q001 What dish did Vikram Malhotra order?            expects: Mushroom Risotto
-- READ
SELECT ro.dish
FROM restaurant_orders ro
JOIN guests g ON g.guest_id = ro.guest_id
WHERE g.guest_name = 'Vikram Malhotra';

-- Q002 Which waiter delivered Vikram's Mushroom Risotto?  expects: Rohan Mehra
-- READ
SELECT w.waiter_name
FROM restaurant_orders ro
JOIN guests  g ON g.guest_id = ro.guest_id
JOIN waiters w ON w.id = ro.waiter_id
WHERE g.guest_name = 'Vikram Malhotra' AND ro.dish = 'Mushroom Risotto';

-- Q003 Did Rohan Mehra enter the kitchen?        expects: Entered Kitchen, 19:44
-- READ
SELECT kl.action, kl."timestamp", kl.kitchen_area
FROM kitchen_logs kl
JOIN employees e ON e.employee_id = kl.employee_id
WHERE e.employee_name = 'Rohan Mehra'
ORDER BY kl."timestamp"::time;

-- Q004 Does the access-card system confirm it?   expects: Kitchen, Entry, 19:44
--      Matches each card swipe against a kitchen log entry at the same minute.
-- READ
SELECT ac.access_area, ac.action, ac.access_time, kl.action AS log_action
FROM access_cards ac
JOIN employees e     ON e.employee_id = ac.employee_id
JOIN kitchen_logs kl ON kl.employee_id = ac.employee_id
                    AND kl."timestamp" = ac.access_time
                    AND kl.action = 'Entered Kitchen'
WHERE e.employee_name = 'Rohan Mehra';

-- Q005 Was Rohan paid before the murder?                     expects: 50000
--      The risotto was ordered at 19:42, so "before" means earlier than that.
-- READ
SELECT p.payment_id, p.amount, p.payment_time
FROM payments p
JOIN bank_accounts b ON b.account_id = p.receiver_account
JOIN employees e     ON e.employee_id = b.owner_id AND b.owner_type = 'Employee'
WHERE e.employee_name = 'Rohan Mehra'
  AND p.payment_time::time < '19:42'::time;

-- Q006 Which account sent the ₹50,000?                          expects: B009
--      Payment -> receiving account -> its employee owner, all by JOIN.
-- READ
SELECT p.sender_account
FROM payments p
JOIN bank_accounts b ON b.account_id = p.receiver_account
JOIN employees e     ON e.employee_id = b.owner_id AND b.owner_type = 'Employee'
WHERE e.employee_name = 'Rohan Mehra'
  AND p.amount = 50000;

-- Q007 Who owns account B009?                           expects: Arvind Khanna
--      owner_id points at a guest or an employee depending on owner_type,
--      so both tables are joined and owner_type picks the right one.
-- READ
SELECT b.account_id,
       COALESCE(g.guest_name, e.employee_name) AS owner_name,
       b.owner_type
FROM bank_accounts b
LEFT JOIN guests    g ON b.owner_type = 'Guest'    AND g.guest_id    = b.owner_id
LEFT JOIN employees e ON b.owner_type = 'Employee' AND e.employee_id = b.owner_id
WHERE b.account_id = 'B009';

-- Q008 Who planned the murder?                          expects: Arvind Khanna
--      The whole chain in one statement: victim's order -> waiter -> waiter's
--      employee record -> payment received -> sending account -> its owner.
-- READ
WITH victim_order AS (
    SELECT ro.waiter_id
    FROM restaurant_orders ro
    JOIN guests g ON g.guest_id = ro.guest_id
    WHERE g.guest_name = 'Vikram Malhotra'
),
waiter_account AS (
    SELECT b.account_id
    FROM victim_order vo
    JOIN waiters w       ON w.id = vo.waiter_id
    JOIN employees e     ON e.employee_name = w.waiter_name
    JOIN bank_accounts b ON b.owner_type = 'Employee' AND b.owner_id = e.employee_id
),
bribe AS (
    SELECT p.sender_account
    FROM payments p
    JOIN waiter_account wa ON wa.account_id = p.receiver_account
    ORDER BY p.amount DESC
    LIMIT 1
)
SELECT g.guest_name AS mastermind, g.role, g.is_suspect
FROM bribe
JOIN bank_accounts b ON b.account_id = bribe.sender_account
JOIN guests g        ON b.owner_type = 'Guest' AND g.guest_id = b.owner_id;


-- ═════════════════════ Part 4: Reports and integrity checks ═════════════════════

-- 4.1 View: one row per step with everything the client needs to draw it.
--     Saves repeating the four-way LEFT JOIN from 2.2 elsewhere.
-- WRITE
CREATE OR REPLACE VIEW "v_case_steps" AS
SELECT cp."caseId", cp."sequenceId", cp."locationId", l."locationName",
       cp."dialogueId", n."npcName", cp."queryId", q."title" AS "queryTitle"
FROM "case_progress" cp
LEFT JOIN "locations" l ON l."id" = cp."locationId"
LEFT JOIN "dialogues" d ON d."id" = cp."dialogueId"
LEFT JOIN "npcs"      n ON n."id" = d."npcId"
LEFT JOIN "queries"   q ON q."id" = cp."queryId";

-- READ
SELECT * FROM "v_case_steps" WHERE "caseId" = 'C001' ORDER BY "sequenceId";

-- 4.2 How many dialogue and query steps each location holds in a case.
-- READ
SELECT "locationName",
       COUNT("dialogueId") AS dialogue_steps,
       COUNT("queryId")    AS query_steps,
       MIN("sequenceId")   AS first_visit
FROM "v_case_steps"
WHERE "caseId" = 'C001'
GROUP BY "locationName"
ORDER BY first_visit;

-- 4.3 Questions per difficulty, keeping only levels with more than one question.
-- READ
SELECT "difficulty", COUNT(*) AS questions, STRING_AGG("id", ', ' ORDER BY "id") AS ids
FROM "queries"
WHERE "caseId" = 'C001'
GROUP BY "difficulty"
HAVING COUNT(*) > 1
ORDER BY questions DESC;

-- 4.4 Player leaderboard: share of each case's steps every player has cleared.
--     A completed case counts as all steps; otherwise the steps before the
--     current one are done. The per-case step totals are a derived table
--     joined in as a source.
-- READ
SELECT u."username", up."caseId", up."status",
       CASE WHEN up."status" = 'COMPLETED' THEN t.total
            ELSE COALESCE(up."sequenceId", 1) - 1 END                 AS steps_done,
       t.total                                                       AS total_steps,
       ROUND(100.0 * CASE WHEN up."status" = 'COMPLETED' THEN t.total
                          ELSE COALESCE(up."sequenceId", 1) - 1 END
             / t.total, 1)                                           AS pct_done,
       RANK() OVER (PARTITION BY up."caseId"
                    ORDER BY up."status" DESC, up."sequenceId" DESC NULLS FIRST) AS "rank"
FROM "user_progress" up
JOIN "users" u ON u."id" = up."userId"
JOIN (SELECT "caseId", COUNT(*) AS total FROM "case_progress" GROUP BY "caseId") t
     ON t."caseId" = up."caseId"
ORDER BY up."caseId", "rank";

-- 4.5 Registered players who have not started any case (LEFT JOIN anti-join:
--     a player with no user_progress row has NULLs on the right side).
-- READ
SELECT u."id", u."username"
FROM "users" u
LEFT JOIN "user_progress" up ON up."userId" = u."id"
WHERE up."userId" IS NULL;

-- 4.6 Every NPC line in a case, one row per line, with the line's position.
--     dialoguesList is a TEXT[] (see 01_normalization.md, section 4), so
--     UNNEST is needed to treat its elements as rows.
-- READ
SELECT d."id", n."npcName", line.no, line.text
FROM "dialogues" d
JOIN "npcs" n ON n."id" = d."npcId"
CROSS JOIN LATERAL UNNEST(d."dialoguesList") WITH ORDINALITY AS line(text, no)
WHERE d."caseId" = 'C001'
ORDER BY d."id", line.no;

-- 4.7 Time between each employee's kitchen events, using LAG over the log.
-- READ
SELECT e.employee_name, kl.action, kl."timestamp",
       kl."timestamp"::time
         - LAG(kl."timestamp"::time) OVER (PARTITION BY kl.employee_id
                                           ORDER BY kl."timestamp"::time) AS since_previous
FROM kitchen_logs kl
JOIN employees e ON e.employee_id = kl.employee_id
ORDER BY e.employee_name, kl."timestamp"::time;

-- 4.8 Money in and out of every account, with the owner's name.
-- READ
SELECT b.account_id,
       COALESCE(g.guest_name, e.employee_name)                         AS owner_name,
       COALESCE(SUM(p.amount) FILTER (WHERE p.receiver_account = b.account_id), 0) AS received,
       COALESCE(SUM(p.amount) FILTER (WHERE p.sender_account   = b.account_id), 0) AS sent
FROM bank_accounts b
LEFT JOIN guests    g ON b.owner_type = 'Guest'    AND g.guest_id    = b.owner_id
LEFT JOIN employees e ON b.owner_type = 'Employee' AND e.employee_id = b.owner_id
LEFT JOIN payments  p ON b.account_id IN (p.sender_account, p.receiver_account)
GROUP BY b.account_id, owner_name
ORDER BY received DESC;

-- 4.9 Payments larger than the average payment. The average is computed once
--     in a derived table and joined to every payment.
-- READ
SELECT p.payment_id, p.sender_account, p.receiver_account, p.amount
FROM payments p
JOIN (SELECT AVG(amount) AS avg_amount FROM payments) a
     ON p.amount > a.avg_amount
ORDER BY p.amount DESC;

-- 4.10 People who are both an employee and a waiter, matched by name, and
--      whether the two tables agree (INTERSECT / EXCEPT). waiters has no
--      link to employees, so a name is the only shared value.
-- READ
SELECT waiter_name AS name FROM waiters
INTERSECT
SELECT employee_name FROM employees WHERE job_title = 'Waiter';

-- READ
SELECT employee_name AS waiter_missing_from_waiters
FROM employees WHERE job_title = 'Waiter'
EXCEPT
SELECT waiter_name FROM waiters;

-- 4.11 Integrity check: every step must be exactly one of dialogue or query.
--      The schema does not enforce this; the application assumes it.
-- READ
SELECT "id", "dialogueId", "queryId"
FROM "case_progress"
WHERE ("dialogueId" IS NULL) = ("queryId" IS NULL);

-- 4.12 Integrity check: bank_accounts.owner_id has no foreign key because it
--      can point at two tables. List owners that match neither: both LEFT
--      JOINs come back empty (this also catches an unknown owner_type).
-- READ
SELECT b.account_id, b.owner_type, b.owner_id
FROM bank_accounts b
LEFT JOIN guests    g ON b.owner_type = 'Guest'    AND g.guest_id    = b.owner_id
LEFT JOIN employees e ON b.owner_type = 'Employee' AND e.employee_id = b.owner_id
WHERE g.guest_id IS NULL AND e.employee_id IS NULL;

-- 4.13 Integrity check: questions a player could never pass because no
--      evidence or no case step is attached to them.
-- READ
SELECT DISTINCT q."id", q."title",
       eq."B" IS NULL AS no_evidence,
       cp."id" IS NULL AS not_placed
FROM "queries" q
LEFT JOIN "_EvidenceToQuery" eq ON eq."B" = q."id"
LEFT JOIN "case_progress"    cp ON cp."queryId" = q."id"
WHERE eq."B" IS NULL OR cp."id" IS NULL;

-- 4.14 Update inside a transaction: mark a player's case finished, check the
--      row, then roll back so the sample data stays as loaded.
-- WRITE
BEGIN;

-- WRITE
UPDATE "user_progress"
SET "status" = 'COMPLETED', "sequenceId" = NULL
WHERE "userId" = 2 AND "caseId" = 'C001'
RETURNING *;

-- WRITE
ROLLBACK;
