# ROUTAI — Schema Build (EX 603 Assignment 2, Task 2.1)

ROUTAI is a ride-sharing service that matches riders with drivers on stated preferences (conversation, music, temperature, vehicle class, accessibility). This repository contains `schema.sql`, a single PostgreSQL 14+ script that builds the full ROUTAI schema from the ERD, and this write-up of the decisions the script encodes.

## Step 1: Creation order

A table can be created only after every table it references. I listed each table's outgoing foreign keys from the ERD, placed tables with no outgoing arrows first, and then added each table once all of its targets existed.

| #  | Table                 | Role              | References                                | Why it sits here                      |
|--- |---                    |---                |---                                        |---                                    |
| 1  | `riders`              | Actor             | itself (`referred_by`)                    | A self-reference needs no other table |
| 2  | `rider_preferences`   | Actor side table  | `riders`                                  | Needs its parent rider                |
| 3  | `vehicles`            | Producer asset    | nothing                                   | Independent                           |
| 4  | `drivers`             | Producer          | nothing                                   | Independent                           |
| 5  | `driver_badges`       | Catalog           | nothing                                   | Independent reference data            |
| 6  | `driver_vehicles`     | Junction          | `drivers`, `vehicles`                     | Both parents exist at 3 and 4         |
| 7  | `driver_badge_awards` | Junction          | `drivers`, `driver_badges`                | Both parents exist at 4 and 5         |
| 8  | `trips`               | Event             | `drivers`, `vehicles`, `driver_vehicles`  | Needs the pairing table from 6        |
| 9  | `trip_riders`         | Junction          | `trips`, `riders`                         | Needs trips from 8                    |
| 10 | `ratings`             | Event child       | `trips`, `trip_riders`                    | Needs both 8 and 9                    |

The script contains no forward references.

## Step 2: Re-runnable setup

The script opens with a reset block that drops all ten tables in exact reverse creation order with `DROP TABLE IF EXISTS ... CASCADE`. Two additions make re-runs clean:

- `SET client_min_messages = warning;` suppresses the harmless "does not exist, skipping" notices on the very first run.
- The whole build is wrapped in `BEGIN; ... COMMIT;`. PostgreSQL DDL is transactional, so if any statement fails, the entire run rolls back and the database is never left half-built.

## Step 3: Type choices

| ERD domain    | PostgreSQL type used                      | Where                                                                                                 |
|---            |---                                        |---                                                                                                    |
| Identifier    | `INTEGER GENERATED ALWAYS AS IDENTITY`    | All surrogate keys. FK columns are plain `INTEGER` so types match exactly.                            |
| Short text    | `VARCHAR(n)` with real limits             | `name` 100, `email` 254 (the practical maximum for an email address), `license_no` 20, `make_model` 60, locations 200, coded values 10–16 |
| Long text     | `TEXT`                                    | `accessibility_needs`, `languages`, `criteria`, `comment`                                             |
| Yes/no        | `BOOLEAN` with `TRUE`/`FALSE` defaults    | `pooled_ok`, `wheelchair_accessible`, `active`                                                        |
| Count         | `INTEGER` | `capacity` (checked 1–15)     |
| Money         | `NUMERIC(10,2)`                           | `fare_amount`, `fare_share`                                                                           |
| Rating/score  | `NUMERIC(3,2)` with a range check         | `avg_rating` (1–5), `match_score` (0–1). `ratings.score` stays `INTEGER` 1–5, as the ERD specifies.   |
| Point in time | `TIMESTAMP`                               | `created_at`, `requested_at`, `completed_at`                                                          |
| Date only     | `DATE`                                    | `effective_from`, `awarded_on`                                                                        |

**Derived value decision.** `avg_rating` on `riders` and `drivers` is stored, not computed at query time. It is a deliberate denormalization so profile and matching reads stay cheap. A `GENERATED ALWAYS AS ... STORED` column cannot be used here, because a generated column can only use values from its own row, and an average needs rows from `ratings`. The application (or a later trigger) recomputes it when a rating is inserted.

## Step 4: Table decisions

**Recursive foreign key: `riders.referred_by`.** The ERD has no self-reference, so I placed it where ROUTAI has a real use for one: a rider-referral program in which one rider invites another. It uses `ON DELETE SET NULL`, because deleting a referrer shouldn't delete the people they referred, and `chk_riders_no_self_referral` prevents a rider from referring themselves. *This column is an addition; the ERD should be updated to show it.*

**Composite primary keys.** The three junction tables (`driver_vehicles`, `driver_badge_awards`, `trip_riders`) use the pair of foreign keys as the primary key, not a new ID. This matches the ERD and also prevents duplicate pairings.

**Composite foreign keys for integrity.** Two rules from the requirements are enforced by the structure itself:
- `trips (driver_id, vehicle_id)` references `driver_vehicles`, so a trip can only use a car the driver is actually paired with.
- `ratings (trip_id, rider_id)` references `trip_riders` and `ratings (trip_id, driver_id)` references `trips`, so a rating can only come from people who were on that trip. The second FK needs `uq_trips_trip_driver` on `trips` as its target.

**Delete behavior.**

| Relationship                                                  | Rule              | Reason                                    |
| preferences, junction rows → their owning rider or driver     | `CASCADE`         | They have no meaning without the parent   |
| junction → catalog (badges) and vehicles                      | `RESTRICT`        | Reference data in use must not disappear  |
| trips → drivers, vehicles, pairings                           | `RESTRICT`        | Trip history is a financial record. Drivers with history are deactivated with `active = FALSE`, not deleted. |
| trip_riders, ratings → trips                                  | `CASCADE`         | If a trip is removed (for example, test data), its riders and ratings go with it |
| trip_riders → riders                                          | `RESTRICT`        | Preserves trip history |

**Business rules as constraints.**

- Trip lifecycle: `status` is limited to REQUESTED, MATCHED, ACCEPTED, IN_PROGRESS, COMPLETED, or CANCELED.
- A trip has no driver or vehicle while REQUESTED (or if canceled before matching). After that, both are required, and they are always set together.
- A COMPLETED trip must have `completed_at` and `fare_amount`, and `completed_at` cannot precede `requested_at`.
- **A driver cannot be on two active trips.** This is enforced by the partial unique index `uq_trips_one_active_per_driver` on `driver_id WHERE status IN ('MATCHED','ACCEPTED','IN_PROGRESS')`.
- Preference vocabularies (conversation, temperature, vehicle class) use identical `CHECK` lists on the rider and driver sides, so the matcher compares like with like.

**Changes from the ERD.**

1. `trips.driver_id` and `vehicle_id` are nullable, because a trip exists as REQUESTED before a driver is matched.
2. `ratings.rater_id` / `ratee_id` became `rider_id`, `driver_id`, and `direction` (RIDER_TO_DRIVER or DRIVER_TO_RIDER). A single `rater_id` column could point at either a rider or a driver, so no foreign key could protect it. The new form keeps the one-table design, is fully FK-protected, and allows one rating per direction per rider per trip.
3. `riders.referred_by` was added, as explained above.

**Known limits (not enforceable with declarative DDL).** "Ratings only after the trip is COMPLETED" and keeping `avg_rating` in sync require a trigger, and `languages` is stored as `TEXT` per the ERD rather than as a separate language table or array. These are candidates for later work.

## Step 5: Run it, then run it again

Create the database once, then run the whole file as a single unit, not statement by statement:

```bash
createdb routai
psql -v ON_ERROR_STOP=1 -d routai -f schema.sql
psql -v ON_ERROR_STOP=1 -d routai -f schema.sql
```

`ON_ERROR_STOP=1` makes `psql` stop at the first error instead of continuing past it, so a failure is visible immediately. Both runs should end with the same verification query listing the same 10 tables. If the second run fails, the cause is almost always a table missing from, or out of order in, the reset block. The fix is to make the `DROP` list the exact reverse of the creation order.
