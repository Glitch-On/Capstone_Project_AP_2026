# Case-SELECT: Normalization of the Game Database

| | |
|---|---|
| Course | Database Management Systems, AP Checkpoint 1 (CP1) |
| Team | T0022 · Section B |
| Members | Simran Sobhani (lead), Vansh Gaur, Mayank Dhanuka, Shashank Badhautia |
| Application | Case-SELECT, a 2D detective game solved by writing SQL |
| Repository | [Glitch-On/Case-SELECT](https://github.com/Glitch-On/Case-SELECT), `main` at commit `68d55f2` |
| DBMS | PostgreSQL (accessed through Prisma 7) |
| File | `dbms/01_normalization.md` |

---

## 1. What the application stores

Case-SELECT is a pixel-art detective game. The player walks through a crime
scene, talks to NPCs, and answers each open question by writing a SQL query
against the case records. A correct answer reveals a piece of evidence and
unlocks the next location. The backend is Express 5 with Prisma 7 on
PostgreSQL; the game client is React and Phaser.

The database holds three kinds of data:

1. **Players and their progress**: accounts, and where each player is in each case.
2. **Case content**: cases, locations, NPCs, dialogue, the ordered list of
   steps, the SQL questions with their grading rules, and the evidence each
   question uncovers.
3. **Investigation records**: the tables the player is allowed to query inside
   the game (guests, waiters, orders, employees, kitchen logs, access cards,
   bank accounts, payments, phone records). For case C001, "The Murderer Is Not
   a Suspect", these describe a poisoning at The Red Lantern Diner.

Everything in this document comes from `prisma/schema.prisma`, the migrations
in `prisma/migrations/`, the case content in `prisma/data/caseC001.js`, and the
code that reads them (`prisma/seed.js`, `src/services/caseSession.service.js`,
`src/services/caseProgression.js`).

### 1.1 Out of scope

These are not relational data in the app and are left out of the analysis:

- Tile maps, sprites and character art (`frontend/public/assets/`), which are files.
- Scene layouts and NPC placement code in `frontend/src/game/`.
- The SQL result sets players produce at runtime. They are computed and graded,
  then discarded; only the resulting position in `user_progress` is saved.

### 1.2 Current tables (as deployed)

| # | Table | Purpose | Primary key |
|---|-------|---------|-------------|
| 1 | `users` | Player accounts | `id` |
| 2 | `user_progress` | A player's position in one case | `id`, unique `(userId, caseId)` |
| 3 | `cases` | Case header | `id` |
| 4 | `locations` | Places in the game world | `id` |
| 5 | `npcs` | Characters the player talks to | `id` |
| 6 | `dialogues` | One block of NPC speech, `dialoguesList TEXT[]` | `id` |
| 7 | `case_progress` | One step of a case (dialogue or query) | `id`, unique `(caseId, sequenceId)` |
| 8 | `evidences` | Evidence a case can reveal | `id` |
| 9 | `queries` | A SQL question and its grading rule, `answerValues TEXT[]` | `id` |
| 10 | `_EvidenceToQuery` | Prisma's implicit M:N join, columns `A`, `B` | `(A, B)` |
| 11 | `investigation_tables` | Catalogue of tables a player may query | `id` |
| 12 | `query_tables` | Which catalogue tables a case exposes | `(caseId, tableId)` |
| 13 | `guests` | Dinner guests | `guest_id` |
| 14 | `waiters` | Waiters who served | `id` |
| 15 | `restaurant_orders` | What each guest ordered | `order_id` |
| 16 | `employees` | Diner staff | `employee_id` |
| 17 | `kitchen_logs` | Kitchen activity | `log_id` |
| 18 | `access_cards` | Card swipes at restricted doors | `access_id` |
| 19 | `bank_accounts` | Accounts of guests and staff | `account_id` |
| 20 | `payments` | Transfers between accounts | `payment_id` |
| 21 | `phone_records` | Calls made by people in the case | `phone_record_id` |

The current schema is already close to 3NF because it was designed as separate
entities from the start. The walk-through below starts from the flat, single
sheet a case designer would write by hand, normalizes it step by step, and
points out where the deployed schema still breaks a normal form.

---

## 2. Unnormalized form (UNF)

A case designer writing C001 in a spreadsheet would put one row per step, with
everything about that step, the case, the dialogue and the question on the same
row. Players and their progress would sit in a second sheet. The investigation
data would arrive as a third sheet of "people and what they did".

### 2.1 `CASE_SHEET` (UNF)

| caseId | caseName | difficulty | startLocation | seq | locationId | locationName | npcId | npcName | npcRole | dialogueLines | queryId | question | answerValues | maxRows | evidenceId | evidenceName | tables |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C001 | The Murderer Is Not a Suspect | Medium | L005 Parking Area | 1 | L001 | The Red Lantern Diner | N001 | Rahul Sen | Diner Manager | "Detective, I'm glad you're here..." | | | | | | | guests, restaurant_orders, waiters, … |
| C001 | The Murderer Is Not a Suspect | Medium | L005 Parking Area | 6 | L001 | The Red Lantern Diner | | | | | Q001 | What dish did Vikram Malhotra order? | {Mushroom Risotto} | 1 | EV001 | Mushroom Risotto Order | guests, restaurant_orders, waiters, … |
| C001 | The Murderer Is Not a Suspect | Medium | L005 Parking Area | 10 | L003 | Main Kitchen | | | | | Q003 | Did Rohan Mehra enter the kitchen? | {Entered Kitchen, 19:44} | 3 | EV003 | Kitchen Entry | guests, restaurant_orders, waiters, … |
| C001 | The Murderer Is Not a Suspect | Medium | L005 Parking Area | 13 | L001 | The Red Lantern Diner | N002 | Rohan Mehra | Waiter | "Fine... I entered the kitchen..." | | | | | | | guests, restaurant_orders, waiters, … |

### 2.2 `PLAYER_SHEET` (UNF)

| userId | username | email | password | casesInProgress | casesCompleted |
|---|---|---|---|---|---|
| 1 | detective | detective@caseselect.local | (hash) | C001 @ step 10, in L003 | |

The comment in `schema.prisma` ("Replaces 'cases completed' / 'cases
inprogress'") shows the original design really did keep these as lists on the
user.

### 2.3 `EVIDENCE_SHEET` (UNF)

| personId | name | type | role/jobTitle | isSuspect | account | accountNo | phone | ordersServed / ordered | kitchenActions | cardSwipes | paymentsSent | paymentsReceived |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| E003 | Rohan Mehra | Employee | Waiter | | B003 | 69342178 | 9876500033 | O001 Mushroom Risotto 19:42; O008 Mushroom Risotto 19:44 | 19:44 Entered Kitchen; 19:45 Collected Mushroom Risotto; 19:47 Exited Kitchen | 19:44 Kitchen Entry; 19:47 Kitchen Exit; 20:03 Staff Office Entry; … | | P003 ₹50,000 from B009 at 18:56 |
| G008 | Arvind Khanna | Guest | Business Partner | false | B009 | 51736284 | 9876500099 | O008 Mushroom Risotto 19:44 | | | P003 ₹50,000 to B003 at 18:56 | |

### 2.4 Problems with the UNF

- **Repeating groups and multi-valued cells.** `dialogueLines`, `answerValues`,
  `tables`, `casesInProgress`, `kitchenActions`, `cardSwipes`, `paymentsSent`
  and the order list hold many values in one cell.
- **Redundancy.** `caseName`, `difficulty` and `startLocation` repeat on all 20
  steps. `locationName` repeats every time a step happens in L001. The full
  list of exposed tables repeats on every row.
- **Update anomaly.** Renaming the case or a location means editing every row
  that mentions it; missing one leaves the data contradicting itself.
- **Insertion anomaly.** A new location or NPC cannot be recorded until some
  step uses it. A new player cannot be stored without inventing a case entry.
- **Deletion anomaly.** Deleting the only step at L006 also deletes the only
  record that "Vikram's Office" exists.

---

## 3. Functional dependencies

FDs are written as `X → Y`. They come from the meaning of the data and from the
unique constraints and code paths in the repository. The same short names are
used in every later section.

### 3.1 Players and progress

| # | Dependency | Reason |
|---|---|---|
| FD1 | `userId → username, email, password` | One account per id |
| FD2 | `username → userId` | `username` is `@unique` |
| FD3 | `email → userId` | `email` is `@unique` |
| FD4 | `(userId, caseId) → status, currentSeq, currentLocationId` | `@@unique([userId, caseId])`; one position per player per case |
| FD5 | `currentSeq → status` (within one row) | `positionAfter()` sets `sequenceId = null` exactly when `status = COMPLETED`; a non-null step means `IN_PROGRESS` |

### 3.2 Case content

| # | Dependency | Reason |
|---|---|---|
| FD6 | `caseId → caseName, description, difficulty, startLocationId` | Case header |
| FD7 | `locationId → locationName, description` | |
| FD8 | `npcId → npcName, role` | |
| FD9 | `dialogueId → caseId, npcId, locationId` | One speech block belongs to one case and one NPC |
| FD10 | `(dialogueId, lineNo) → lineText` | Lines are ordered inside a block |
| FD11 | `(caseId, seq) → stepId, locationId, dialogueId, queryId` | `@@unique([caseId, sequenceId])` |
| FD12 | `stepId → caseId, seq` | Surrogate id, so `stepId` and `(caseId, seq)` are both candidate keys |
| FD13 | `queryId → caseId, title, question, hint, difficulty, queryOutput, unlockMessage, maxRows` | |
| FD14 | `(queryId, valueNo) → answerValue` | Values that must appear together in one result row |
| FD15 | `evidenceId → caseId, evidenceName, description` | |
| FD16 | `tableId → tableName, displayName, description` | |
| FD17 | `tableName → tableId` | Each catalogue entry names a different physical table |
| FD18 | `dialogueId → stepId` and `queryId → stepId` | In C001 every dialogue and every query is placed on exactly one step (`steps` in `caseC001.js`) |

### 3.3 Investigation records

| # | Dependency | Reason |
|---|---|---|
| FD19 | `guestId → guestName, role, isSuspect` | |
| FD20 | `employeeId → employeeName, jobTitle` | |
| FD21 | `waiterId → waiterName` | |
| FD22 | `waiterId → employeeId` | Every waiter is also an employee: W001–W004 are E001–E004 with the same names |
| FD23 | `orderId → guestId, dish, orderTime, waiterId` | |
| FD24 | `logId → employeeId, action, timestamp, kitchenArea` | |
| FD25 | `accessId → employeeId, accessArea, accessTime, action` | |
| FD26 | `accountId → accountNumber, ownerId` | |
| FD27 | `accountNumber → accountId` | Real account numbers are unique |
| FD28 | `ownerId → ownerType` | `E…` ids are always `Employee`, `G…` ids are always `Guest` |
| FD29 | `paymentId → senderAccount, receiverAccount, amount, paymentTime, description` | |
| FD30 | `phoneNumber → ownerId, associatedAccount` | A phone number belongs to one person |
| FD31 | `associatedAccount → ownerId` | In all 10 phone records the phone owner equals the account owner |
| FD32 | `phoneRecordId → phoneNumber, callTime, duration` | |

---

## 4. First normal form (1NF)

**Rule:** every attribute holds one atomic value from its domain, there are no
repeating groups, and every row is identified by a key.

### 4.1 Splitting the sheets

Each multi-valued cell from section 2 becomes its own relation, with one row
per value:

| UNF cell | 1NF relation |
|---|---|
| `dialogueLines` | `DIALOGUE_LINE(dialogueId, lineNo, lineText)` |
| `answerValues` | `QUERY_ANSWER_VALUE(queryId, valueNo, answerValue)` |
| `tables` | `CASE_TABLE(caseId, tableId, tableName, displayName)` |
| `casesInProgress` / `casesCompleted` | `PLAYER_CASE(userId, caseId, username, status, currentSeq, currentLocationId)` |
| `ordersServed / ordered` | `ORDER(orderId, guestId, dish, orderTime, waiterId, waiterName)` |
| `kitchenActions` | `KITCHEN_LOG(logId, employeeId, action, timestamp, kitchenArea)` |
| `cardSwipes` | `ACCESS_CARD(accessId, employeeId, accessArea, accessTime, action)` |
| `paymentsSent` / `paymentsReceived` | `PAYMENT(paymentId, senderAccount, receiverAccount, amount, paymentTime, description)` |

After this step the step sheet is a flat relation with one row per step:

```
STEP_1NF(caseId, seq, caseName, difficulty, startLocationId,
         locationId, locationName,
         dialogueId, npcId, npcName, npcRole,
         queryId, question, hint, maxRows,
         evidenceId, evidenceName)
Key: (caseId, seq)
```

### 4.2 1NF problems still in the deployed schema

The deployed tables are already split into entities, but two columns use
PostgreSQL arrays, which are repeating groups inside one cell:

| Table.column | Type | Example value | Why it breaks 1NF |
|---|---|---|---|
| `dialogues.dialoguesList` | `TEXT[]` | `{"Detective, I'm glad you're here…"}` | A list of lines in one cell. A line cannot be referenced, ordered or searched on its own without unnesting the array. |
| `queries.answerValues` | `TEXT[]` | `{"Kitchen","Entry","19:44"}` | A list of grading values in one cell. One value cannot be changed without rewriting the array, and nothing stops duplicates or empty strings. |

Both are replaced by child tables:

**`dialogue_lines`** (key `(dialogue_id, line_no)`)

| dialogue_id | line_no | line_text |
|---|---|---|
| D001 | 1 | Detective, I'm glad you're here. This was supposed to be a private dinner. |
| D011 | 1 | Fine... I entered the kitchen. But I didn't kill Vikram. |

**`query_answer_values`** (key `(query_id, value_no)`)

| query_id | value_no | answer_value |
|---|---|---|
| Q003 | 1 | Entered Kitchen |
| Q003 | 2 | 19:44 |
| Q004 | 1 | Kitchen |
| Q004 | 2 | Entry |
| Q004 | 3 | 19:44 |

The grader (`src/services/grading.js`) already loops over `answerValues`, so it
can read the same list from a join ordered by `value_no`.

### 4.3 Atomicity notes that do not change the design

- `kitchen_logs.action` holds values such as `Collected Mushroom Risotto`,
  which mixes an action and a dish. The value is still one string from one
  domain, and the puzzle expects players to search it with `LIKE`, so it stays
  as is. A stricter design would split it into `action` and `item`.
- Times are stored as `TEXT` (`'19:44'`). Each value is atomic, so this is a
  data-type issue for `03_schema.sql`, where they become `TIME`.

---

## 5. Second normal form (2NF)

**Rule:** the relation is in 1NF and no non-key attribute depends on only part
of a composite candidate key.

2NF only matters for relations whose key has more than one attribute. In the
1NF design these are `STEP_1NF`, `PLAYER_CASE`, `CASE_TABLE`, `DIALOGUE_LINE`
and `QUERY_ANSWER_VALUE`.

### 5.1 `STEP_1NF(caseId, seq, …)`

Partial dependencies on `caseId` alone:

- FD6: `caseId → caseName, difficulty, startLocationId`

These attributes repeat on all 20 steps of C001. Move them out:

```
CASE(caseId, caseName, description, difficulty, startLocationId)    key: caseId
STEP(caseId, seq, locationId, locationName, dialogueId, npcId, npcName,
     npcRole, queryId, question, hint, maxRows, evidenceId, evidenceName)
                                                                     key: (caseId, seq)
```

`STEP` is now in 2NF: no remaining attribute depends on `caseId` or `seq`
alone. It still has transitive dependencies, which section 6 handles.

### 5.2 `PLAYER_CASE(userId, caseId, username, status, currentSeq, currentLocationId)`

Partial dependency: FD1 `userId → username` (and `email`, `password` from the
user sheet). Split:

```
USER(userId, username, email, password)                              key: userId
USER_PROGRESS(userId, caseId, status, currentSeq, currentLocationId) key: (userId, caseId)
```

This matches the deployed `users` and `user_progress`.

### 5.3 `CASE_TABLE(caseId, tableId, tableName, displayName)`

Partial dependency: FD16 `tableId → tableName, displayName`. Split:

```
INVESTIGATION_TABLE(tableId, tableName, displayName, description)    key: tableId
QUERY_TABLE(caseId, tableId)                                         key: (caseId, tableId)
```

This matches the deployed `investigation_tables` and `query_tables`. The
deployed `query_tables` has no other columns, so it is already in 2NF.

### 5.4 `DIALOGUE_LINE` and `QUERY_ANSWER_VALUE`

`(dialogueId, lineNo) → lineText` and `(queryId, valueNo) → answerValue` are
full dependencies. If the 1NF split had carried along `npcId` or `question`,
those would depend on `dialogueId` or `queryId` alone and be moved back to
`DIALOGUE` and `QUERY`. As defined in 4.2, both relations are in 2NF.

### 5.5 Tables with single-attribute keys

`guests`, `waiters`, `employees`, `restaurant_orders`, `kitchen_logs`,
`access_cards`, `bank_accounts`, `payments`, `phone_records`, `npcs`,
`locations`, `evidences`, `queries`, `cases` and `users` all have a
single-column primary key, so a partial dependency is not possible. They are
in 2NF as soon as they are in 1NF.

---

## 6. Third normal form (3NF)

**Rule:** the relation is in 2NF and no non-key attribute depends on another
non-key attribute. For every FD `X → A`, either `X` is a superkey or `A` is
part of some candidate key.

### 6.1 `STEP`: location, NPC, query and evidence details

From 5.1, `STEP(caseId, seq, locationId, locationName, dialogueId, npcId,
npcName, npcRole, queryId, question, hint, maxRows, evidenceId, evidenceName)`
has these transitive chains:

| Chain | Transitive FD |
|---|---|
| `(caseId, seq) → locationId → locationName` | FD7 |
| `(caseId, seq) → dialogueId → npcId → npcName, npcRole` | FD9, FD8 |
| `(caseId, seq) → queryId → question, hint, maxRows` | FD13 |
| `(caseId, seq) → queryId → evidenceId → evidenceName` | FD15 |

Decompose into:

```
LOCATION(locationId, locationName, description)
NPC(npcId, npcName, role)
DIALOGUE(dialogueId, caseId, npcId)
QUERY(queryId, caseId, title, question, hint, difficulty, queryOutput,
      unlockMessage, maxRows)
EVIDENCE(evidenceId, caseId, evidenceName, description)
QUERY_EVIDENCE(queryId, evidenceId)
STEP(stepId, caseId, seq, locationId, dialogueId, queryId)
```

`QUERY_EVIDENCE` is the deployed `_EvidenceToQuery`. It is renamed so the
columns say what they hold instead of `A` and `B`.

### 6.2 3NF problems still in the deployed schema

The deployed schema already has the tables from 6.1, but four places keep a
transitive dependency.

#### (a) `case_progress.evidenceId` duplicates `queries → evidences`

`case_progress` has an `evidenceId` column next to `queryId`. The schema
comment calls them "one of the two", but in C001 no step sets `evidenceId`;
evidence is always reached through the query
(`discoveredEvidence()` reads `step.query.evidences`). If a step did set both,
`stepId → queryId → evidenceId` and the stored `evidenceId` could disagree
with `query_evidences`.

**Fix:** drop `case_progress.evidenceId`. Evidence is found through
`query_evidences`.

#### (b) `dialogues.locationId` repeats the step's location

`dialogues.locationId` and `case_progress.locationId` both say where a line is
spoken. In C001 each dialogue appears on exactly one step (FD18) and the two
values always match, so the dependency `stepId → dialogueId → locationId`
stores the same fact twice. `caseWorld()` reads `dialogue.locationId ??
step.locationId`, so the code already treats them as the same thing.

**Fix:** drop `dialogues.location_id`. The step's `location_id` says where the
NPC speaks, and the NPC's position in a scene is the location of the first step
that uses one of their dialogues.

#### (c) `bank_accounts.ownerType` depends on `ownerId`

```
bank_accounts(account_id, account_number, owner_type, owner_id)
account_id → owner_id → owner_type            (FD26, FD28)
```

`owner_type` is decided by `owner_id` (`E…` is always an employee, `G…` always
a guest), so it is a non-key attribute that depends on another non-key
attribute. The column also exists because `owner_id` is a polymorphic
reference: it points into `employees` or `guests` and has no foreign key at
all. Nothing stops `owner_id = 'G999'` or `owner_type = 'Guest'` next to an
employee id.

**Fix:** replace the pair with two nullable foreign keys and a check that
exactly one is set:

| account_id | account_number | employee_id | guest_id |
|---|---|---|---|
| B003 | 69342178 | E003 | |
| B009 | 51736284 | | G008 |

`owner_type` is no longer stored; a query gets it from which column is set.
Q007 ("Who owns bank account B009?") becomes a join on `guest_id`, and the
database now guarantees that the guest it reaches exists.

#### (d) `phone_records` mixes the phone with the call

```
phone_records(phone_record_id, phone_number, owner_id, associated_account,
              call_time, duration)
phone_record_id → phone_number → owner_id, associated_account   (FD32, FD30)
associated_account → owner_id                                    (FD31)
```

Who owns a number and which account it is linked to depend on the number, not
on the call. With more than one call per number, those facts would repeat on
every call and could drift apart. `owner_id` is also derivable from the linked
account and has the same polymorphic problem as (c).

**Fix:** split the phone from its calls and drop the owner, which comes from
the account:

**`phones`** (key `phone_number`)

| phone_number | account_id |
|---|---|
| 9876500033 | B003 |
| 9876500099 | B009 |

**`phone_calls`** (key `call_id`)

| call_id | phone_number | call_time | duration |
|---|---|---|---|
| PR003 | 9876500033 | 18:54 | 45 |
| PR009 | 9876500099 | 18:51 | 300 |

The owner of a number is `phones → bank_accounts → employees/guests`.

#### (e) `waiters.waiter_name` repeats `employees.employee_name`

W001–W004 are the same people as E001–E004. `waiter_name` is a copy of
`employee_name` reached through `waiter_id → employee_id → employee_name`
(FD22, FD20). Renaming Rohan Mehra in `employees` would leave the old name in
`waiters`, and the two halves of the Q002/Q003 puzzle would then disagree.

**Fix:** store the employee link and drop the copied name:

| waiter_id | employee_id |
|---|---|
| W003 | E003 |

Q002 ("Which waiter delivered the risotto?") then needs one more join, from
`waiters` to `employees`. That is a small change in difficulty, which the team
should agree on before the schema changes.

### 6.3 `user_progress.status` (kept on purpose)

FD5 says `sequenceId` determines `status`: a row with a step is
`IN_PROGRESS`, a row with no step is `COMPLETED`. Strictly, `status` is
derivable. It is kept because the progress API and the case list filter on it
directly, and dropping it would make every reader re-derive it. The redundancy
is made safe with a constraint instead of a decomposition:

```sql
CHECK ((status = 'COMPLETED') = (sequence_id IS NULL))
```

With this check the two columns can never disagree, so the update anomaly 3NF
guards against cannot happen.

### 6.4 Tables already in 3NF

| Table | Why |
|---|---|
| `users` | Only key attributes determine anything (FD1–FD3) |
| `cases`, `locations`, `npcs`, `evidences`, `queries`, `investigation_tables` | Every non-key column describes the key directly |
| `guests`, `employees`, `restaurant_orders`, `kitchen_logs`, `access_cards`, `payments` | Every non-key column describes the key directly; FKs point to other tables instead of copying their columns |
| `query_tables`, `query_evidences`, `dialogue_lines`, `query_answer_values` | Key-only or key plus one dependent column |

---

## 7. Boyce-Codd normal form (BCNF)

**Rule:** for every non-trivial FD `X → Y`, `X` is a superkey. This is stricter
than 3NF because it also covers FDs whose right side is part of a key.

### 7.1 Tables with more than one candidate key

| Table | Candidate keys | Other determinants | BCNF? |
|---|---|---|---|
| `users` | `id`, `username`, `email` | none | Yes |
| `user_progress` | `id`, `(user_id, case_id)` | `sequence_id → status` | Yes with the 6.3 check: the FD is reduced to a nullness rule that the constraint enforces in the same row |
| `investigation_tables` | `id`, `table_name` | none | Yes, once `table_name` is declared `UNIQUE` (it is not today) |
| `bank_accounts` | `account_id`, `account_number` | none after 6.2(c) | Yes, once `account_number` is declared `UNIQUE` |
| `case_progress` | `id`, `(case_id, sequence_id)` | `dialogue_id → case_id`, `query_id → case_id` | **No**, see 7.2 |

### 7.2 `case_progress` is in 3NF but not in BCNF

In `case_progress(id, case_id, sequence_id, location_id, dialogue_id, query_id)`
the dialogue and the query each belong to a case:

```
dialogue_id → case_id      (FD9)
query_id    → case_id      (FD13)
```

`case_id` is part of the candidate key `(case_id, sequence_id)`, so 3NF allows
these FDs. BCNF does not, because `dialogue_id` and `query_id` are not
superkeys of `case_progress`: they are nullable, and nothing in the schema says
a dialogue appears on only one step. The practical risk is a step of case C002
that points at a dialogue of case C001, which the database would accept today.

The nullable pair is also how the table encodes "a step is either a dialogue or
a query". Nothing stops a step with both or neither.

**Decomposition:**

```
STEP(step_id, case_id, sequence_id, location_id)
    keys: step_id, (case_id, sequence_id)

STEP_DIALOGUE(step_id, dialogue_id)
    keys: step_id, dialogue_id

STEP_QUERY(step_id, query_id)
    keys: step_id, query_id
```

| step_id | case_id | sequence_id | location_id |
|---|---|---|---|
| C001-S001 | C001 | 1 | L001 |
| C001-S006 | C001 | 6 | L001 |

| step_id | dialogue_id |
|---|---|
| C001-S001 | D001 |

| step_id | query_id |
|---|---|
| C001-S006 | Q001 |

Every determinant in each new table is now a candidate key, so all three are in
BCNF. `UNIQUE(dialogue_id)` and `UNIQUE(query_id)` record FD18, that each
dialogue and query is used once. The rule that a step's dialogue or query must
belong to the step's own case is kept with composite foreign keys:
`dialogues` and `queries` get `UNIQUE(case_id, id)`, and the link tables carry
`case_id` in a composite FK to both `steps` and the target table.

"Exactly one of the two" cannot be written as a single-table `CHECK` after the
split. It is enforced in `seed.js`, which builds every step from either a
`dialogueId` or a `queryId`, and can be checked with:

```sql
SELECT s.step_id
  FROM steps s
  LEFT JOIN step_dialogues d USING (step_id)
  LEFT JOIN step_queries   q USING (step_id)
 WHERE (d.step_id IS NULL) = (q.step_id IS NULL);   -- should return no rows
```

**Trade-off.** The BCNF version is stricter but makes `loadCaseData()` join two
more tables. If the team prefers fewer joins, the 3NF version of
`case_progress` with `CHECK (num_nonnulls(dialogue_id, query_id) = 1)` and the
composite FKs gives the same integrity in practice. We use the BCNF version in
the final schema because it is what this checkpoint asks for, and the extra
joins run on 20 rows per case.

---

## 8. Final relations

All relations below are in BCNF. `PK` is the primary key and `FK →` names the
referenced table.

### 8.1 Players

| Relation | Attributes | Keys |
|---|---|---|
| `users` | user_id, username, email, password_hash | PK user_id · UNIQUE username · UNIQUE email |
| `user_progress` | user_id, case_id, status, sequence_id, location_id | PK (user_id, case_id) · FK user_id → users · FK case_id → cases · FK (case_id, sequence_id) → steps · FK location_id → locations · CHECK on status/sequence_id |

The surrogate `user_progress.id` is dropped: nothing references it and
`(user_id, case_id)` is already the key every query uses.

### 8.2 Case content

| Relation | Attributes | Keys |
|---|---|---|
| `cases` | case_id, case_name, description, difficulty, start_location_id | PK case_id · FK start_location_id → locations |
| `locations` | location_id, location_name, description | PK location_id |
| `npcs` | npc_id, npc_name, role | PK npc_id |
| `dialogues` | dialogue_id, case_id, npc_id | PK dialogue_id · FK case_id → cases · FK npc_id → npcs · UNIQUE (case_id, dialogue_id) |
| `dialogue_lines` | dialogue_id, line_no, line_text | PK (dialogue_id, line_no) · FK dialogue_id → dialogues |
| `steps` | step_id, case_id, sequence_id, location_id | PK step_id · UNIQUE (case_id, sequence_id) · UNIQUE (case_id, step_id) · FK case_id → cases · FK location_id → locations |
| `step_dialogues` | step_id, case_id, dialogue_id | PK step_id · UNIQUE dialogue_id · FK (case_id, step_id) → steps · FK (case_id, dialogue_id) → dialogues |
| `step_queries` | step_id, case_id, query_id | PK step_id · UNIQUE query_id · FK (case_id, step_id) → steps · FK (case_id, query_id) → queries |
| `queries` | query_id, case_id, title, question, hint, difficulty, query_output, unlock_message, max_rows | PK query_id · FK case_id → cases · UNIQUE (case_id, query_id) |
| `query_answer_values` | query_id, value_no, answer_value | PK (query_id, value_no) · FK query_id → queries |
| `evidences` | evidence_id, case_id, evidence_name, description | PK evidence_id · FK case_id → cases |
| `query_evidences` | query_id, evidence_id | PK (query_id, evidence_id) · FK → queries, evidences |
| `investigation_tables` | table_id, table_name, display_name, description | PK table_id · UNIQUE table_name |
| `query_tables` | case_id, table_id | PK (case_id, table_id) · FK → cases, investigation_tables |

### 8.3 Investigation records

| Relation | Attributes | Keys |
|---|---|---|
| `guests` | guest_id, guest_name, role, is_suspect | PK guest_id |
| `employees` | employee_id, employee_name, job_title | PK employee_id |
| `waiters` | waiter_id, employee_id | PK waiter_id · UNIQUE employee_id · FK → employees |
| `restaurant_orders` | order_id, guest_id, dish, order_time, waiter_id | PK order_id · FK → guests, waiters |
| `kitchen_logs` | log_id, employee_id, action, logged_at, kitchen_area | PK log_id · FK → employees |
| `access_cards` | access_id, employee_id, access_area, access_time, action | PK access_id · FK → employees |
| `bank_accounts` | account_id, account_number, employee_id, guest_id | PK account_id · UNIQUE account_number · FK → employees, guests · CHECK exactly one owner |
| `payments` | payment_id, sender_account, receiver_account, amount, payment_time, description | PK payment_id · FK sender_account, receiver_account → bank_accounts · CHECK sender ≠ receiver · CHECK amount > 0 |
| `phones` | phone_number, account_id | PK phone_number · FK → bank_accounts |
| `phone_calls` | call_id, phone_number, call_time, duration | PK call_id · FK → phones · CHECK duration ≥ 0 |

25 relations in total, up from 21.

---

## 9. Changes from the deployed schema

| # | Change | Normal form | Effect on the game |
|---|---|---|---|
| 1 | `dialogues.dialoguesList TEXT[]` → `dialogue_lines` | 1NF | Seed writes one row per line; session loader joins and orders by `line_no` |
| 2 | `queries.answerValues TEXT[]` → `query_answer_values` | 1NF | Grader reads values from a join |
| 3 | Drop `case_progress.evidenceId` | 3NF | None; it is never set |
| 4 | Drop `dialogues.locationId` | 3NF | `caseWorld()` uses the step's location |
| 5 | `bank_accounts.owner_type/owner_id` → `employee_id` / `guest_id` | 3NF | Q007's expected query changes; answer stays "Arvind Khanna" |
| 6 | `phone_records` → `phones` + `phone_calls`, drop `owner_id` | 3NF | Phone puzzles join through the account |
| 7 | `waiters.waiter_name` → `waiters.employee_id` | 3NF | Q002 needs a join to `employees`; answer stays "Rohan Mehra" |
| 8 | `case_progress` → `steps` + `step_dialogues` + `step_queries` | BCNF | `loadCaseData()` includes two more relations |
| 9 | Rename `_EvidenceToQuery(A, B)` → `query_evidences(query_id, evidence_id)` | naming | Explicit Prisma relation model instead of an implicit one |
| 10 | Add `UNIQUE` on `investigation_tables.table_name`, `bank_accounts.account_number` | BCNF (declares existing keys) | None |
| 11 | Add `CHECK` on `user_progress` status/sequence | 3NF (controlled redundancy) | None; the code already keeps them consistent |

Changes 5, 6 and 7 touch the tables players query, so the expected answers in
`prisma/data/caseC001.js` (`answerValues`, `maxRows`, hints) need to be
re-checked once the schema changes.

## 10. Anomalies removed

| Anomaly | Before | After |
|---|---|---|
| Update | Renaming Rohan Mehra had to happen in `employees` and `waiters` | One row in `employees` |
| Update | Editing one grading value meant rewriting the whole `answerValues` array | One row in `query_answer_values` |
| Update | A phone's owner was stored on every call | Stored once, through `phones → bank_accounts` |
| Insertion | A bank account could reference an owner id that does not exist | FK to `employees` or `guests` rejects it |
| Insertion | A step could point at another case's dialogue or query, or at both | Composite FKs and the split step tables reject it |
| Deletion | Deleting a number's last call also deleted the record of who owned the phone | The `phones` row stays when calls are deleted |
| Consistency | A step could name evidence directly and through its query, and the two could differ | Evidence has one path: `step → query → query_evidences` |
