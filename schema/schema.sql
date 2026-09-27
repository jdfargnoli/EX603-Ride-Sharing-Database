-- =================================================================
-- EX 603 Assignment 2 — schema.sql
-- Theme:  ROUTAI — preference-matched ride sharing
-- Author: Joseph Fargnoli
-- Target: PostgreSQL 14+
--
-- Run the whole file in one pass, twice in a row:
--   psql -v ON_ERROR_STOP=1 -d routai -f schema.sql
--   psql -v ON_ERROR_STOP=1 -d routai -f schema.sql
--
-- Creation order (a table is created only after every table it references):
--    1 riders               -> (itself: referred_by)
--    2 rider_preferences    -> riders
--    3 vehicles             -> nothing
--    4 drivers              -> nothing
--    5 driver_badges        -> nothing
--    6 driver_vehicles      -> drivers, vehicles
--    7 driver_badge_awards  -> drivers, driver_badges
--    8 trips                -> drivers, vehicles, driver_vehicles
--    9 trip_riders          -> trips, riders
--   10 ratings              -> trips, trip_riders
-- =================================================================

-- Hide "does not exist, skipping" notices on the first run.
-- This setting hides messages below warning level, so the output stays clean.
SET client_min_messages = warning;

-- One transaction: the script either builds everything or nothing.
-- This opens a transaction.Every statement from here until COMMIT; counts as one unit of work. 
-- If any statement fails, PostgreSQL undoes all of them, so the database is never left half-built. 
-- This works because PostgreSQL treats DROP and CREATE as transactional, which not every database does.
BEGIN;

-- Reset. Reverse creation order, so no dependency blocks a drop.
-- DROP TABLE deletes a table and all its data.
-- IF EXISTS means "only if it's there," so the first run doesn't fail on missing tables.
-- CASCADE also removes anything that depends on the table, such as foreign keys pointing at it.
-- The tables are listed in exact reverse creation order.
-- This block is what makes the second run succeed: it clears everything away so the CREATE statements start from an empty database each time.
DROP TABLE IF EXISTS ratings              CASCADE;
DROP TABLE IF EXISTS trip_riders          CASCADE;
DROP TABLE IF EXISTS trips                CASCADE;
DROP TABLE IF EXISTS driver_badge_awards  CASCADE;
DROP TABLE IF EXISTS driver_vehicles      CASCADE;
DROP TABLE IF EXISTS driver_badges        CASCADE;
DROP TABLE IF EXISTS drivers              CASCADE;
DROP TABLE IF EXISTS vehicles             CASCADE;
DROP TABLE IF EXISTS rider_preferences    CASCADE;
DROP TABLE IF EXISTS riders               CASCADE;

-- ----------------------------------------------------------------
-- 1. riders (Actor) — first: references nothing but itself.
--    Recursive FK referred_by supports a rider-referral program.
--    avg_rating is a stored rollup of ratings (see README).
-- ----------------------------------------------------------------
-- Starts the definition of a table named riders. Everything inside the parentheses defines its columns and rules.

CREATE TABLE riders (
    rider_id             INTEGER GENERATED ALWAYS AS IDENTITY,  -- rider_id - The surrogate key. INTEGER is a whole number. GENERATED ALWAYS AS IDENTITY means PostgreSQL assigns the number automatically (1, 2, 3...) 
    name                 VARCHAR(100) NOT NULL,   -- Text of up to 100 characters. NOT NULL means the value is required.
    email                VARCHAR(254) NOT NULL,   -- RFC 5321 practical maximum
    accessibility_needs  TEXT,  -- TEXT is unlimited-length text, used for free-form descriptions. There's no NOT NULL, so it's optional.
    avg_rating           NUMERIC(3,2),            -- NULL until first rating - An exact decimal from -9.99 to 9.99.
    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- date and time
    referred_by          INTEGER,    --ID of the rider who referred this rider
    CONSTRAINT pk_riders PRIMARY KEY (rider_id),    --Declares rider_id as the primary key
    CONSTRAINT uq_riders_email UNIQUE (email),      --No two riders can share an email address.
    CONSTRAINT chk_riders_avg_rating CHECK (avg_rating BETWEEN 1 AND 5),
    CONSTRAINT chk_riders_no_self_referral CHECK (referred_by IS DISTINCT FROM rider_id),    -- blockd=s rider from referring themselves
    CONSTRAINT fk_riders_referrer   --recursive foreign key constraint to enforce that referred_by must reference a valid rider_id in the same table
        FOREIGN KEY (referred_by) REFERENCES riders (rider_id)
        ON DELETE SET NULL
);   --ends the table  

-- ----------------------------------------------------------------
-- 2. rider_preferences (Actor, 1:1 side table) — needs riders.
--    PK is also the FK, which is what makes the relationship 1:1.
--    Vocabularies mirror the driver-side columns so the matcher
--    can compare preference pairs directly.
-- ----------------------------------------------------------------
CREATE TABLE rider_preferences (
    rider_id            INTEGER     NOT NULL,     -- both the primary key and a foreign key
    conversation_pref   VARCHAR(10),
    music_pref          VARCHAR(30),
    temp_pref           VARCHAR(10),
    pooled_ok           BOOLEAN     NOT NULL DEFAULT FALSE,  
    vehicle_class_pref  VARCHAR(10),
    CONSTRAINT pk_rider_preferences PRIMARY KEY (rider_id),
    CONSTRAINT fk_rider_preferences_rider
        FOREIGN KEY (rider_id) REFERENCES riders (rider_id)
        ON DELETE CASCADE,
    CONSTRAINT chk_rider_preferences_conversation
        CHECK (conversation_pref IN ('QUIET', 'SOME', 'CHATTY')),
    CONSTRAINT chk_rider_preferences_temp
        CHECK (temp_pref IN ('COOL', 'MODERATE', 'WARM')),
    CONSTRAINT chk_rider_preferences_vehicle_class
        CHECK (vehicle_class_pref IN ('ECONOMY', 'COMFORT', 'XL', 'LUXURY'))
);

-- ----------------------------------------------------------------
-- 3. vehicles (Producer asset) — references nothing.
-- ----------------------------------------------------------------
CREATE TABLE vehicles (
    vehicle_id             INTEGER GENERATED ALWAYS AS IDENTITY,
    make_model             VARCHAR(60) NOT NULL,
    vehicle_class          VARCHAR(10) NOT NULL,
    capacity               INTEGER     NOT NULL,
    wheelchair_accessible  BOOLEAN     NOT NULL DEFAULT FALSE,
    CONSTRAINT pk_vehicles PRIMARY KEY (vehicle_id),
    CONSTRAINT chk_vehicles_class
        CHECK (vehicle_class IN ('ECONOMY', 'COMFORT', 'XL', 'LUXURY')),
    CONSTRAINT chk_vehicles_capacity CHECK (capacity BETWEEN 1 AND 15)
);
-- checks vehicle capacity 1-15 adn wheel chair accessible is boolean - no foreign keys  
-- ----------------------------------------------------------------
-- 4. drivers (Producer) — references nothing.
--    Matching attributes live directly on the driver row.
-- ----------------------------------------------------------------
CREATE TABLE drivers (
    driver_id          INTEGER GENERATED ALWAYS AS IDENTITY,
    name               VARCHAR(100) NOT NULL,
    license_no         VARCHAR(20)  NOT NULL,
    conversation_pref  VARCHAR(10),
    languages          TEXT,
    home_area          VARCHAR(60),
    avg_rating         NUMERIC(3,2),
    active             BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_drivers PRIMARY KEY (driver_id),
    CONSTRAINT uq_drivers_license_no UNIQUE (license_no),
    CONSTRAINT chk_drivers_conversation
        CHECK (conversation_pref IN ('QUIET', 'SOME', 'CHATTY')),
    CONSTRAINT chk_drivers_avg_rating CHECK (avg_rating BETWEEN 1 AND 5)
);
--uq_drivers_license_no UNIQUE (license_no) prevents two drivers from sharing a 
--   license number, which blocks duplicate or fraudulent accounts.
--active BOOLEAN NOT NULL DEFAULT TRUE is how drivers are deactivated rather than 
--   deleted once they have trip history.
-- ----------------------------------------------------------------
-- 5. driver_badges (Catalog) — references nothing.
--    Reference data: defines which badges exist.
--    This is the catalog: a simple list of which badges exist. 
--    badge_name is unique so no badge is defined twice, and criteria explains how a driver earns it.
-- ----------------------------------------------------------------
CREATE TABLE driver_badges (
    badge_id    INTEGER GENERATED ALWAYS AS IDENTITY,
    badge_name  VARCHAR(60) NOT NULL,
    criteria    TEXT        NOT NULL,
    CONSTRAINT pk_driver_badges PRIMARY KEY (badge_id),
    CONSTRAINT uq_driver_badges_name UNIQUE (badge_name)
);

-- ----------------------------------------------------------------
-- 6. driver_vehicles (first junction table) — needs drivers and vehicles.
--    Resolves M:N: a driver runs many cars, a car has many drivers.
--    Composite PK is the pair of FKs.
--    This is a composite primary key: the pair of columns is the key, with no separate ID.
--    The same driver–vehicle pair can't be entered twice, but one driver can pair with many vehicles 
--    and one vehicle with many drivers. 
--    That's how a many-to-many relationship is resolved.  
-- ----------------------------------------------------------------
CREATE TABLE driver_vehicles (
    driver_id       INTEGER NOT NULL,
    vehicle_id      INTEGER NOT NULL,
    effective_from  DATE    NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_driver_vehicles PRIMARY KEY (driver_id, vehicle_id),
    CONSTRAINT fk_driver_vehicles_driver
        FOREIGN KEY (driver_id) REFERENCES drivers (driver_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_driver_vehicles_vehicle
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (vehicle_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- 7. driver_badge_awards (Junction) — needs drivers and driver_badges.
--    Records who earned which catalog badge, and when.
-- ----------------------------------------------------------------
CREATE TABLE driver_badge_awards (
    driver_id   INTEGER NOT NULL,
    badge_id    INTEGER NOT NULL,
    awarded_on  DATE    NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_driver_badge_awards PRIMARY KEY (driver_id, badge_id),
    CONSTRAINT fk_driver_badge_awards_driver
        FOREIGN KEY (driver_id) REFERENCES drivers (driver_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_driver_badge_awards_badge
        FOREIGN KEY (badge_id) REFERENCES driver_badges (badge_id)
        ON DELETE RESTRICT
);

-- ----------------------------------------------------------------
-- 8. trips (Event) — needs drivers, vehicles, driver_vehicles.
--    Holds lifecycle, locations and the metrics (fare_amount,
--    match_score). driver/vehicle are NULL while status = REQUESTED.
--    The (driver_id, vehicle_id) FK guarantees the car used is one
--    the driver is actually paired with.
-- ----------------------------------------------------------------
CREATE TABLE trips (
    trip_id           INTEGER GENERATED ALWAYS AS IDENTITY,
    driver_id         INTEGER,  --nullable, because a trip exists as REQUESTED before any driver is matched
    vehicle_id        INTEGER,  --nullable, because a trip exists as REQUESTED before any driver is matched
    status            VARCHAR(12)   NOT NULL DEFAULT 'REQUESTED',
    requested_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at      TIMESTAMP,
    pickup_location   VARCHAR(200)  NOT NULL,
    dropoff_location  VARCHAR(200)  NOT NULL,
    match_score       NUMERIC(3,2),
    fare_amount       NUMERIC(10,2),
    CONSTRAINT pk_trips PRIMARY KEY (trip_id),
    CONSTRAINT uq_trips_trip_driver UNIQUE (trip_id, driver_id),  -- target for ratings FK-New trips start in the REQUESTED state automatically.
    CONSTRAINT fk_trips_driver
        FOREIGN KEY (driver_id) REFERENCES drivers (driver_id)
        ON DELETE RESTRICT,    --- trip history must never be delected by accident 
    CONSTRAINT fk_trips_vehicle
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (vehicle_id)
        ON DELETE RESTRICT,
    CONSTRAINT fk_trips_driver_vehicle
        FOREIGN KEY (driver_id, vehicle_id)
        REFERENCES driver_vehicles (driver_id, vehicle_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_trips_status
        CHECK (status IN ('REQUESTED', 'MATCHED', 'ACCEPTED',
                          'IN_PROGRESS', 'COMPLETED', 'CANCELED')),  -enforce trip lifecycle
    CONSTRAINT chk_trips_driver_vehicle_together
        CHECK ((driver_id IS NULL) = (vehicle_id IS NULL)),
    CONSTRAINT chk_trips_assigned_after_request
        CHECK (status IN ('REQUESTED', 'CANCELED') OR driver_id IS NOT NULL),
    CONSTRAINT chk_trips_completed_has_data
        CHECK (status <> 'COMPLETED'
               OR (completed_at IS NOT NULL AND fare_amount IS NOT NULL)),
    CONSTRAINT chk_trips_time_order
        CHECK (completed_at IS NULL OR completed_at >= requested_at),
    CONSTRAINT chk_trips_match_score CHECK (match_score BETWEEN 0 AND 1),
    CONSTRAINT chk_trips_fare CHECK (fare_amount >= 0)
);

-- Business rule: a driver cannot be on two active trips at once.
CREATE UNIQUE INDEX uq_trips_one_active_per_driver     -- index normally speeds up lookups. A unique index also forbids duplicates
    ON trips (driver_id)
    WHERE status IN ('MATCHED', 'ACCEPTED', 'IN_PROGRESS');   --WHERE makes it partial: only active trips count.  
-- ----------------------------------------------------------------
-- 9. trip_riders (Junction) — needs trips and riders - makes pooled rides possible
--  a composite key of (trip_id, rider_id) and a fare_share for each rider, checked to be zero or more.
-- uses CASCADE from trips (the links go with the trip) and RESTRICT from riders (a rider with trip history can't be deleted).
--    Makes trips M:N with riders (pooled rides); per-rider fare split.
-- ----------------------------------------------------------------
CREATE TABLE trip_riders (
    trip_id     INTEGER       NOT NULL,
    rider_id    INTEGER       NOT NULL,
    fare_share  NUMERIC(10,2),
    CONSTRAINT pk_trip_riders PRIMARY KEY (trip_id, rider_id),
    CONSTRAINT fk_trip_riders_trip
        FOREIGN KEY (trip_id) REFERENCES trips (trip_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_trip_riders_rider
        FOREIGN KEY (rider_id) REFERENCES riders (rider_id)
        ON DELETE RESTRICT,
    CONSTRAINT chk_trip_riders_fare_share CHECK (fare_share >= 0)
);

-- ----------------------------------------------------------------
-- 10. ratings — last: needs trips and trip_riders.
--     One table for both directions. Composite FKs guarantee the
--     rider was on the trip and the driver drove it.
-- ----------------------------------------------------------------
CREATE TABLE ratings (
    rating_id  INTEGER GENERATED ALWAYS AS IDENTITY,
    trip_id    INTEGER     NOT NULL,
    rider_id   INTEGER     NOT NULL,
    driver_id  INTEGER     NOT NULL,
    direction  VARCHAR(16) NOT NULL,    -- records who rated whom
    score      INTEGER     NOT NULL,
    comment    TEXT,
    CONSTRAINT pk_ratings PRIMARY KEY (rating_id),
    CONSTRAINT uq_ratings_one_per_direction UNIQUE (trip_id, rider_id, direction),   -- allows each rider one rating per direction per trip
    CONSTRAINT fk_ratings_trip_rider
        FOREIGN KEY (trip_id, rider_id) REFERENCES trip_riders (trip_id, rider_id)
        ON DELETE CASCADE,   -- must exist in trip_riders, so the rider was on this trip
    CONSTRAINT fk_ratings_trip_driver
        FOREIGN KEY (trip_id, driver_id) REFERENCES trips (trip_id, driver_id)
        ON DELETE CASCADE,   -- must match trips, so the driver drove this trip.
    CONSTRAINT chk_ratings_direction
        CHECK (direction IN ('RIDER_TO_DRIVER', 'DRIVER_TO_RIDER')),
    CONSTRAINT chk_ratings_score CHECK (score BETWEEN 1 AND 5)   -- created last bedpedns on both trips and trip_riders 
);

COMMIT;
-- This makes everything since BEGIN permanent. Until this line runs, none of the changes are saved.
-- Verification: should list exactly 10 tables on every run.
SELECT table_name
FROM information_schema.tables    -- built-in catalog of every table in the database
WHERE table_schema = 'public'      -- lists the tables in the default public schema alphabetically
ORDER BY table_name;
