# EX 603 — ROUTAI Ride-Sharing Database: Unit 5 Join Analysis

**Schema roles in my design:** event = `trips` · actor = `riders` · producer = `drivers` · catalog = `driver_badges` · junction = `driver_badge_awards`
**My theme:** failure state = rider no-show · frozen payout = driver bonuses · disputer = senior driver · producer = driver

I produced every result below by running my queries against my `rideshare.sql` dataset (seed 603) in PostgreSQL.

---

## 1A) What feature or report on the platform could use the three-table join from "Who are the people behind the events?"

My join of `trips` → `riders` → `drivers` produces what I think of as a **Trip Activity Ledger**: one row per event, naming the person who requested it, the person who carried it out, and when it happened. On ROUTAI, the feature I would build directly on this join is a **Bonus Dispute Review screen**. A reviewer would open it when a senior driver disputes a bonus that was frozen because of rider no-shows.

I chose this feature because it ties directly to my theme. To decide a dispute fairly, the reviewer needs to see the individual events behind the freeze, not just a total. My three-table join is the only query in my design that shows, for each trip, both parties and the exact time.

I also see the same join supporting other platform features. Only the filter or the audience changes:

- **Rider trip history**: the "Your trips" screen in the rider app.
- **Driver activity and earnings log**: the matching screen in the driver app.
- **Customer support lookup**: an agent searches by trip ID or name to settle complaints, refunds, or lost-item reports.
- **Trust and safety monitoring**: flags riders with repeated no-shows, or rider–driver pairs with repeated disputes.

## 1B) What information would it display?

The core columns come straight from my three-table join: **trip ID, rider name (actor), driver name (producer), and request date and time**. Because `trips` is my fact table, I can also show `trip_status`, `cancellation_reason`, `pickup_city`, `fare_amount`, and `completed_at` without adding any joins. Here is the query I would use to back the dispute screen for one driver:

```sql
-- Evidence view for a disputed bonus: one driver's rider no-shows
SELECT
    t.trip_id,                                    -- Trip reference the reviewer can cite
    r.rider_name       AS rider,                  -- Who failed to show (the actor)
    d.driver_name      AS driver,                 -- Whose bonus was frozen (the producer)
    t.requested_at     AS requested,              -- When the trip was requested
    t.pickup_city,                                -- Where the pickup was supposed to happen
    t.cancellation_reason                         -- Confirms the failure state
FROM trips   AS t
JOIN riders  AS r ON r.rider_id  = t.rider_id     -- Event → actor
JOIN drivers AS d ON d.driver_id = t.driver_id    -- Event → producer
WHERE d.driver_name = 'Driver_02'                 -- The driver whose bonus is in dispute
  AND t.cancellation_reason = 'Rider no show'     -- Only the events that triggered the freeze
ORDER BY t.requested_at;                          -- Oldest first, as a timeline
```

**What I found in my data.** Driver_02 has the most rider no-shows in my dataset: three, on trips 12, 21, and 26, from three different riders (Rider_19, Rider_29, Rider_01). When I looked across the whole ledger, I also found that **Rider_01 and Rider_21 each no-showed twice, with different drivers**. To me, that points to the riders, not the drivers, as the cause. It is exactly the evidence I would expect a senior driver to use to argue that a freeze is unfair.

**Design decisions I made**

- **I would show each audience only what it needs.** My schema stores rider emails and driver licence numbers, but I would not display them on any of these screens. This follows the GDPR data-minimisation principle, Article 5(1)(c).
- **I used an INNER JOIN because it is correct for this report.** In my schema, `trips.rider_id` and `trips.driver_id` are `NOT NULL` foreign keys, so every event matches exactly one rider and one driver, and no rows are lost.
- **I would package the join as a view** (`CREATE VIEW trip_ledger AS ...`) so every feature uses the same definition and each screen only adds its own `WHERE` clause.

---

## 2A) Why is the junction table important for answering "Do the producers identified in Assignment 4 share certain catalog credentials or tags?"

In my design, drivers and badges have a **many-to-many** relationship: a driver can earn several badges, and a badge can go to many drivers. A relational table can't store that directly, so I resolved it with `driver_badge_awards`, which turns it into two one-to-many links. Each row records one fact: *this driver earned this badge on this date*.

Because that table is the only place where a driver and a badge actually meet, it is the only way I can answer the question. My query reaches the shared tags by going **producer → junction → catalog**:

```sql
-- Which other badges do my Five Star drivers (Assignment 4 producers) hold?
WITH five_star AS (                                         -- My Assignment 4 producers
    SELECT a.driver_id
    FROM driver_badge_awards AS a                           -- Junction
    JOIN driver_badges       AS b ON b.badge_id = a.badge_id  -- → catalog
    WHERE b.badge_name = 'Five Star'
)
SELECT
    b.badge_name,                                           -- A tag the group might share
    COUNT(*)                                AS holders,     -- How many Five Star drivers hold it
    string_agg(d.driver_name, ', ' ORDER BY d.driver_name) AS drivers  -- Who they are
FROM five_star            AS f
JOIN driver_badge_awards  AS a ON a.driver_id = f.driver_id -- Producer → junction
JOIN driver_badges        AS b ON b.badge_id  = a.badge_id  -- Junction → catalog
JOIN drivers              AS d ON d.driver_id = a.driver_id -- Names for display
WHERE b.badge_name <> 'Five Star'                           -- Exclude the badge that defines the group
GROUP BY b.badge_name
ORDER BY holders DESC, b.badge_name;
```

| badge_name | holders | drivers |
|---|---|---|
| Safe Driving | 3 | Driver_01, Driver_04, Driver_12 |
| Clean Car | 1 | Driver_04 |
| Night Owl | 1 | Driver_11 |

**My answer:** yes. Three of my four Five Star drivers also hold **Safe Driving**, so that is the credential the group shares most. Driver_11 is the exception, holding Night Owl instead.

I also rely on the junction table to guarantee the data behind this answer:

- **The composite primary key (`driver_id`, `badge_id`)** stops a driver from being awarded the same badge twice, so my counts can't be inflated by duplicates.
- **The foreign keys** make sure every award points to a real driver and a real badge. I used `ON DELETE RESTRICT` on the catalog side so a badge can't be deleted while drivers still hold it.
- **`awarded_on`** stores a date for each award. That date describes the *relationship*, not the driver or the badge, so the junction table is the only place it can live. It lets me ask questions over time, such as whether drivers earned Safe Driving before or after Five Star.

## 2B) What would make this analysis more difficult without it?

My dataset has **25 awards spread across 12 drivers**, and individual drivers hold up to **four badges** (Driver_10). When I considered the alternatives to a junction table, each one breaks down with data like mine:

| Alternative design | What goes wrong |
|---|---|
| **A single `badge_id` column on `drivers`** | Each driver could hold only one badge. I couldn't store Driver_10's four badges or Driver_04's three, so I couldn't answer the shared-tag question at all. |
| **Repeating columns (`badge_1`, `badge_2`, `badge_3`, …)** | Breaks First Normal Form. Every query would have to check every column (`WHERE badge_1 = 5 OR badge_2 = 5 OR …`), and I would have to change the schema whenever a driver earned more badges than there are columns. Counting holders per badge becomes awkward and easy to get wrong. |
| **A comma-separated text list (`'Safe Driving, Five Star'`)** | No foreign key can check the values, so typos and deleted badges would go unnoticed. Filtering would need string matching (`LIKE '%Star%'`), which is slow, can't use indexes well, and can produce false matches. I would have to split the string before I could group or count. |
| **Badge flags on `drivers` (`has_safe_driving BOOLEAN`, …)** | Adding a new badge to my catalog would mean altering the `drivers` table. There would be no place for an award date, and the catalog's names and descriptions would be disconnected from the flags. |

Every one of these designs also loses **`awarded_on`**, because none of them has a place for a fact about the driver–badge pair itself. My timing questions would become impossible.

In short, without the junction table my analysis would be either **impossible** (single column), **fragile and hard to maintain** (repeating columns, flags), or **unreliable** (text lists without referential integrity). By normalising through `driver_badge_awards`, I keep the question to a few simple equi-joins, enforced by keys.
