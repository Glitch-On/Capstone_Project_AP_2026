Query timings - dbms/04_queries.sql
========================================================================
Generated: 2026-11-23 23:27 IST
Database: case_select_timing (PostgreSQL 18.4 (Homebrew))
Method: each SELECT/WITH statement executed 3 times via
EXPLAIN (ANALYZE, BUFFERS).  Only SELECT/WITH statements are timed;
data-loading INSERTs, DDL, and transaction control are excluded.

| # | Query | Description | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|-------|-------------|------------|------------|------------|--------------|
| 25 | 2.1 | Title screen: every case with its number of steps. | 0.584 | 0.274 | 0.231 | 0.363 |
| 26 | 2.2 | Full case flow in order, with the NPC who speaks and the question asked. | 3.668 | 0.392 | 0.398 | 1.486 |
| 27 | 2.3 | Registration: check the username and email are free, then insert. | 0.126 | 0.089 | 0.101 | 0.105 |
| 29 | 2.4 | Login: the identifier may be either a username or an email. | 0.090 | 0.050 | 0.043 | 0.061 |
| 30 | 2.5 | A player's progress in each case they have started. | 0.188 | 0.155 | 0.158 | 0.167 |
| 32 | 2.7 | Distinct NPCs who speak at a location, in any case. | 0.377 | 0.157 | 0.163 | 0.232 |
| 33 | 2.8 | Columns of each investigation table a case exposes (system catalogue). | 4.062 | 1.357 | 1.190 | 2.203 |
| 34 | 2.9 | Grading data for the player's current query step and the evidence revealed. | 0.145 | 0.156 | 0.152 | 0.151 |
| 35 | 2.10 | Evidence a player has already found (queries before their current step). | 0.187 | 0.190 | 0.173 | 0.183 |
| 37 | Q001 | Q001 The Victim's Last Meal: dish Vikram Malhotra ordered. | 0.112 | 0.088 | 0.091 | 0.097 |
| 38 | Q002 | Q002 Who Served the Dish?: waiter who delivered the risotto. | 0.163 | 0.089 | 0.116 | 0.123 |
| 39 | Q003 | Q003 The Kitchen Lie: did Rohan enter the kitchen? | 6.915 | 0.154 | 0.141 | 2.403 |
| 40 | Q004 | Q004 The Second Record: does access-card confirm entry? | 0.156 | 0.172 | 0.138 | 0.155 |
| 41 | Q005 | Q005 Follow the Money: was Rohan paid before the murder? | 0.128 | 0.118 | 0.153 | 0.133 |
| 42 | Q006 | Q006 The Anonymous Account: which account sent the 50000 payment? | 0.148 | 0.132 | 0.130 | 0.137 |
| 43 | Q007 | Q007 Who Owns the Account?: owner of B009. | 0.097 | 0.121 | 0.130 | 0.116 |
| 44 | Q008 | Q008 The Mastermind: who planned the murder? | 0.341 | 0.363 | 0.340 | 0.348 |
| 46 | 4.1 | 4.1 v_case_steps view: one row per step with everything the client needs. | 0.376 | 0.524 | 0.397 | 0.432 |
| 47 | 4.2 | 4.2 How many dialogue and query steps each location holds in a case. | 0.235 | 0.263 | 0.280 | 0.259 |
| 48 | 4.3 | 4.3 Questions per difficulty (only levels with more than one question). | 0.203 | 0.154 | 0.146 | 0.168 |
| 49 | 4.4 | 4.4 Player leaderboard: share of each case's steps cleared. | 0.394 | 0.262 | 0.294 | 0.317 |
| 50 | 4.5 | 4.5 Registered players who have not started any case (anti-join). | 0.088 | 0.096 | 0.102 | 0.095 |
| 51 | 4.6 | 4.6 Every NPC line in a case, one row per line (UNNEST). | 0.222 | 0.167 | 0.143 | 0.177 |
| 52 | 4.8 | 4.8 Time between each employee's kitchen events (LAG window). | 0.209 | 0.204 | 0.181 | 0.198 |
| 53 | 4.7 | 4.7 Money in and out of every account, with the owner's name. | 0.316 | 0.436 | 0.254 | 0.335 |
| 54 | 4.9 | 4.9 Payments larger than the average payment (scalar subquery). | 0.116 | 0.103 | 0.117 | 0.112 |
| 55 | 4.10a | 4.10a INTERSECT: employees who are also waiters. | 0.073 | 0.071 | 0.077 | 0.074 |
| 56 | 4.10b | 4.10b EXCEPT: employee waiter missing from waiters table. | 0.070 | 0.085 | 0.069 | 0.075 |
| 57 | 4.11 | 4.11 Integrity check: every step is exactly one of dialogue or query. | 0.044 | 0.043 | 0.046 | 0.044 |
| 58 | 4.12 | 4.12 Integrity check: bank_accounts.owner_id matches a real owner. | 0.111 | 0.114 | 0.109 | 0.111 |
| 59 | 4.13 | 4.13 Integrity check: questions a player could never pass. | 0.150 | 0.138 | 0.139 | 0.142 |

Notes:
- Each query was timed 3 times; the average is the mean of the three runs.
- Times are wall-clock execution time of the SELECT itself
  (EXPLAIN ANALYZE reports the actual query execution time).
- Plan output for every query is in dbms/plans/.
========================================================================