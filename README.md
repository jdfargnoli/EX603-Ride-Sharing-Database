# EX603-Ride-Sharing-Database

1. ROUTAI is a new ride sharing service that give users and drivers a greater ability to find the type of riders/drivers that they will match up best with to improve the experience of all parties and make ride sharing much more enjoyable and safe by creating a deeper and well-matched relationship between all parties.

## 2. The domain — your theme and the questions the platform must answer. Two to three paragraphs.
Designing this database will start with requirements-elicitation questions organized around the entities in the given table: actors (riders), producers (drivers), and events (trips). The first cluster of questions concerns what I need to know about each party and why. What attributes of a driver matter for matching quality — vehicle type and capacity, languages spoken, accessibility accommodations, home service area, schedule availability, driving-style preferences (music, conversation, temperature)? Symmetrically, what rider attributes and preferences should be captured — accessibility needs, preferred vehicle class, tolerance for pooled rides, rating history? For each attribute, I will ask whether it is static (stored once on the profile), slowly changing (needs effective-dating, like a vehicle change), or per-trip (belongs on the trip record, not the profile). This distinction drives normalization decisions later, and it's the entity-vs-attribute analysis at the heart of conceptual design.

The second cluster concerns relationships, cardinality, and the matching process itself. Can a driver operate multiple vehicles, and can a vehicle be shared between drivers? Is a trip always one rider to one driver, or do pooled rides make trips many-to-many with riders? What exactly does "precise matching" mean operationally — is it a scoring function over preference compatibility, and if so, which preference pairs must the schema make queryable (e.g., rider wants quiet ride ↔ driver's conversation preference)? What history does the matching algorithm needs: do past ratings, cancellations, and completed-trip counts feed the match, and should the schema store the match score and the candidate drivers considered so the algorithm's decisions are auditable and improvable?

The third cluster concerns lifecycle, integrity, and measurement. What states does a trip pass through (requested → matched → accepted → in-progress → completed/canceled), and what timestamps and geolocations must be captured at each transition to compute metrics like fare_amount, wait time, and match quality? What business rules become constraints — a driver can't be on two active trips, a rating must be 1–5 and only from a participant of a completed trip? Finally, I should ask about privacy and retention up front: preference and location data is sensitive, so which fields need restricted access, and how long is trip-level location history kept? 

Answering these three question clusters gives exactly whats needed to move from requirements to an ER diagram, and then mechanically into DDL.

3. Schema — embed the ERD image; summarize the five roles and your key design decisions.

The core transaction is a TRIP. A trip is fulfilled by exactly one DRIVER using exactly one VEHICLE (the two FK arrows coming in from the left), and it carries one or more RIDERS through the TRIP_RIDERS junction table — that junction is what makes pooled rides possible, and it splits the cost via fare_share. The trip row itself holds the lifecycle data (status, timestamps, locations), the fare_amount metric, and the match_score your algorithm assigned.

People and their matching data are kept separate. RIDERS holds stable identity info; RIDER_PREFERENCES is a 1:1 side table holding the volatile matching attributes (music, conversation, temperature, pooled tolerance). Drivers carry their matching attributes (languages, conversation_pref, home_area) directly on DRIVERS. Matching works by comparing the two sides — e.g., rider's conversation_pref against driver's.

Two many-to-many relationships resolve through junctions. DRIVER_VEHICLES lets a driver operate multiple cars and a car be shared between drivers, with effective_from dating each pairing. DRIVER_BADGE_AWARDS connects drivers to the DRIVER_BADGES catalog — the catalog defines what badges exist, the junction records who earned which one and when.

RATINGS hang off completed trips. One trip can receive multiple ratings (rider rates driver, driver rates rider), distinguished by rater_id/ratee_id. The avg_rating on RIDERS and DRIVERS is just a stored rollup of these.

<img width="1239" height="1129" alt="image" src="https://github.com/user-attachments/assets/c69dfbc0-b724-4956-96fe-55d053b52d57" />


<img width="1045" height="299" alt="image" src="https://github.com/user-attachments/assets/a578c701-6aa7-4112-bd95-42d1adf7726a" />

The metric (fare_amount, plus match_score) isn't its own table — it lives as attributes on the event, which is where metrics belong: computed per occurrence, aggregated later.

Key design decisions
Preferences split from identity (1:1 table). RIDER_PREFERENCES isolates volatile matching attributes from stable profile data, and mirrors the driver-side attributes so the matcher can join and compare preference pairs directly. This is the schema's answer to "precise matching."
Pooled rides via junction, not a rider FK on trips. TRIP_RIDERS makes trip-to-rider many-to-many with per-rider fare_share. A single rider_id column on TRIPS would have locked the service into solo rides forever.
Trips reference both driver AND specific vehicle. Since drivers can operate multiple vehicles (DRIVER_VEHICLES junction with effective_from history), the trip must record which one was actually used — capacity and accessibility matter for match quality.
Match auditability. Storing match_score on each trip lets you correlate the algorithm's confidence against actual ratings afterward, so the matcher is improvable rather than a black box.
One RATINGS table for both directions. rater_id/ratee_id handles rider→driver and driver→rider without duplicate structures; avg_rating on the profile tables is a deliberate denormalization — a cheap-to-read rollup updated per new rating.

Each decision traces to a requirement: pooling → junction, precision → mirrored preferences, quality improvement → auditable scores. That requirements-to-schema traceability is usually what graders look for.

4. Query catalogue — per unit, a short table listing the queries and the business question each answers, linked to the .sql files.
I will use the following structure
00 query catalogue
01 schema
02 seed data
03 actors producers
04 matching
05 trips operations
06 metrics analytics 
<img width="961" height="1075" alt="image" src="https://github.com/user-attachments/assets/1ab98606-a1a8-492d-b7d1-112cadfdfecb" />


6. Technical highlights — three to five things a reader should notice.
7. What I would do differently — an honest paragraph. Critiquing your own work is a senior signal, not a weakness.
8. Video presentation — embed or link the video.
9. How to run it — the commands to create the schema and execute a query. Assume the reader has a database and nothing else.

#### The five roles
#### Role    |    What it is                                  |                                   Always has
#### actor   |    The user who acts on the platform.                                        |     A primary key and a display name. 
#### producer |   The supply-side entity being acted upon.                                  |     A primary key, a display name, an activity flag, and a     ####                                                                                       |         numeric attribute used for filtering. 
#### event     |  The high-volume fact table recording each action.                         |     Foreign keys to actor and producer, a timestamp, and a                                                                                               |      numeric metric you will aggregate. 
#### catalog  |   A descriptive dimension: the tags or categories that classify producers. |      A primary key and a name. 
#### junction |   The many-to-many link between producer and catalog.                    |        A composite primary key over foreign keys to producer and                                                                                                  catalog. 

