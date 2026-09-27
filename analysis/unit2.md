# Task 2.2: Write Up Your Reasoning

Here is the complete explanation starting with the constraints table, then explanation for each foreign key, then one for each CHECK constraint.

## The constraints table

| **Foreign key**                                                                 | **ON DELETE** | **Reason**                                                                                            |
|---------------------------------------------------------------------------------|---------------|-------------------------------------------------------------------------------------------------------|
| fk_riders_referrer: riders.referred_by → riders                                 | SET NULL      | A referred rider remains a customer when their referrer leaves, so only the referral link is cleared. |
| fk_rider_preferences_rider: rider_preferences.rider_id → riders                 | CASCADE       | Preferences describe one rider and have no meaning once that rider is gone.                           |
| fk_driver_vehicles_driver: driver_vehicles.driver_id → drivers                  | CASCADE       | A driver–vehicle pairing means nothing without the driver, and the vehicle itself survives.           |
| fk_driver_vehicles_vehicle: driver_vehicles.vehicle_id → vehicles               | RESTRICT      | A car that drivers are still assigned to must be unassigned deliberately before it can be deleted.    |
| fk_driver_badge_awards_driver: driver_badge_awards.driver_id → drivers          | CASCADE       | A badge award records one driver's achievement and ends with that driver.                             |
| fk_driver_badge_awards_badge: driver_badge_awards.badge_id → driver_badges      | RESTRICT      | A badge cannot be removed from the catalog while drivers still hold it.                               |
| fk_trips_driver: trips.driver_id → drivers                                      | RESTRICT      | Trips are permanent financial and safety records, so a driver with trip history cannot be deleted.    |
| fk_trips_vehicle: trips.vehicle_id → vehicles                                   | RESTRICT      | The record of which car carried a rider must survive for insurance, safety, and disputes.             |
| fk_trips_driver_vehicle: trips(driver_id, vehicle_id) → driver_vehicles         | RESTRICT      | A pairing used on a trip is the proof the driver was authorized to drive that car.                    |
| fk_trip_riders_trip: trip_riders.trip_id → trips                                | CASCADE       | Rider-to-trip links and fare shares are part of the trip and go with it.                              |
| fk_trip_riders_rider: trip_riders.rider_id → riders                             | RESTRICT      | Deleting a rider must not erase their seat from trips other people shared.                            |
| fk_ratings_trip_rider: ratings(trip_id, rider_id) → trip_riders                 | CASCADE       | A rating exists only because that rider was on that trip.                                             |
| fk_ratings_trip_driver: ratings(trip_id, driver_id) → trips(trip_id, driver_id) | CASCADE       | A rating belongs to the trip it describes and goes with it.                                           |

## What each ON DELETE choice governs

The pattern behind these choices is simple.

- Anything that records money, safety, or another person's history is protected with RESTRICT.
- Anything that only extends a single record goes with that record through CASCADE.
- SET NULL is used once, where a link can end without harming either side.

### What happens when a producer (driver) is removed

This is the event the assignment asks about specifically, and three foreign keys govern it together.

Drivers leave ROUTAI regularly: they quit, fail a background re-check, or are banned after a complaint. What the database does depends on the driver's history.

- **A driver who never completed a trip** can be deleted. Their vehicle pairings and badge awards are removed automatically by the two CASCADE rules below, and the vehicles stay available for other drivers.
- **A driver with trip history** cannot be deleted: fk_trips_driver blocks it. The platform offboards them by setting active = FALSE instead, which removes them from matching while keeping every record intact.

### fk_trips_driver (RESTRICT)

**Event:** An administrator tries to delete a driver who has driven trips, for example after a safety ban.

**Who is affected:** Every rider who rode with that driver keeps their receipts and trip history. ROUTAI's finance team can still reconcile the fares. A safety investigator can still see who was driving.

**Under the alternative:** CASCADE would delete every trip the driver ever drove, and through the trip rules, every fare share and rating on those trips. Riders would lose their receipts, other drivers' and riders' averages would no longer match their stored ratings, and the evidence behind the ban would disappear. SET NULL would leave completed trips with no driver, which chk_trips_assigned_after_request rejects, and it would erase accountability anyway.

### fk_driver_vehicles_driver (CASCADE)

**Event:** A driver who never drove is deleted, for example a signup who abandoned onboarding.

**Who is affected:** Only that driver's pairing rows are removed. The vehicles remain, and so do other drivers' pairings with the same car.

**Under the alternative:** RESTRICT would force an administrator to delete each pairing by hand before removing the driver. That is extra work that protects nothing, because a pairing without a driver has no use.

### fk_driver_badge_awards_driver (CASCADE)

**Event:** The same deletion of a driver with no trips.

**Who is affected:** That driver's badge awards are removed. The badges themselves remain in the catalog for everyone else.

**Under the alternative:** RESTRICT would block removing a driver simply because they had once earned a badge. That makes no sense, because the award is a fact about that driver alone.

### fk_driver_vehicles_vehicle (RESTRICT)

**Event:** A car is sold, totaled, or fails inspection, and staff try to delete it.

**Who is affected:** The drivers currently paired with the car. RESTRICT forces staff to unassign it from them first, so the drivers are informed and no driver is left paired with a car that no longer exists.

**Under the alternative:** CASCADE would silently unpair every driver of that car. A driver could log in and find they have no vehicle, with no record of why.

### fk_trips_vehicle (RESTRICT)

**Event:** Staff try to delete a vehicle that has carried riders.

**Who is affected:** Riders and insurers. A lost item, an accident claim, or an accessibility complaint all depend on knowing exactly which car was used.

**Under the alternative:** CASCADE would delete the trip records of every ride in that car. SET NULL would leave trips with a driver but no vehicle, which chk_trips_driver_vehicle_together rejects. The cost of RESTRICT is that a used vehicle can never be deleted; a future active flag on vehicles would let it be retired instead.

### fk_trips_driver_vehicle (RESTRICT)

**Event:** Staff try to remove a driver–vehicle pairing that was used on a trip.

**Who is affected:** Anyone who later needs to prove the driver was authorized to drive that car, such as an insurer handling a claim.

**Under the alternative:** CASCADE would delete the trips that used the pairing. Without this rule, a driver's authorization could be erased after the fact, leaving no record that they were permitted to drive the car on the day of the trip.

### fk_driver_badge_awards_badge (RESTRICT)

**Event:** ROUTAI discontinues a badge, such as "Night Owl," and staff try to delete it from the catalog.

**Who is affected:** The drivers who earned it, because badges contribute to their visibility in matching.

**Under the alternative:** CASCADE would strip the badge from every holder in one catalog edit, with no record of why their standing changed. Drivers could reasonably dispute that. RESTRICT forces a deliberate two-step decision: remove the awards visibly, then retire the badge.

### fk_rider_preferences_rider (CASCADE)

**Event:** A rider with no trip history closes their account.

**Who is affected:** Only that rider. Their preference row is deleted with them.

**Under the alternative:** RESTRICT would block account deletion until the preferences were removed first. Keeping them would leave personal preference data for a person who no longer uses the service, which is the kind of sensitive data the design aims to minimize.

### fk_riders_referrer (SET NULL)

**Event:** A rider who referred other riders closes their account.

**Who is affected:** The riders they referred. Those riders keep their accounts, and only the "referred by" link is cleared.

**Under the alternative:** CASCADE would delete every account the leaving rider had referred, removing paying customers because someone else left. RESTRICT would stop a rider from leaving until everyone they had invited left too.

### fk_trip_riders_rider (RESTRICT)

**Event:** A rider with trip history asks to delete their account.

**Who is affected:** The other riders on their pooled trips, whose fare shares were calculated together with this rider's, and the drivers, whose earnings and ratings come from those trips.

**Under the alternative:** CASCADE would remove the rider's seat from shared trips, leaving fare shares that no longer add up to the fare and trips that appear to have carried fewer people than they did. The cost of RESTRICT is that such a rider must be anonymized (name and email cleared) rather than deleted, which the application must support.

### fk_trip_riders_trip (CASCADE)

**Event:** A trip is removed. Real trips are never deleted, so this governs cleanup of test data and of duplicate or fraudulent requests.

**Who is affected:** Only the rider-to-trip links for that trip, which have no meaning without it.

**Under the alternative:** RESTRICT would require deleting rider links by hand before every trip cleanup. That is safe but error-prone, and adds nothing.

### fk_ratings_trip_driver (CASCADE)

**Event:** The same trip cleanup.

**Who is affected:** The ratings on that trip, and indirectly the avg_rating of the people involved, which the application must recompute.

**Under the alternative:** RESTRICT would block removing a fraudulent trip until its ratings were deleted by hand. A rating about a trip that doesn't exist would be misleading if it were kept.

### fk_ratings_trip_rider (CASCADE)

**Event:** A rider is removed from a pooled trip, for example because they cancel before pickup.

**Who is affected:** Any rating that rider left on that trip. It is removed, which is correct, because only people who actually rode may rate.

**Under the alternative:** RESTRICT would block the cancellation because of a rating that should never have existed. SET NULL isn't possible, because a rating with no rider would break the rule that only participants can rate.

## What each CHECK constraint prevents

One principle applies to all of them: a CHECK passes when its value is NULL. That is intentional. A missing avg_rating means "no ratings yet," and a missing preference means "the rider didn't say." The constraints stop wrong values, not missing ones.

### Riders and preferences

**chk_riders_avg_rating** makes it impossible to store a rider's average outside 1–5, such as 0 or 6.40. Without it, a bug in the code that recalculates averages, such as dividing by the wrong count or including another rider's ratings, would save an impossible number that then skews matching.

**chk_riders_no_self_referral** makes it impossible for a rider to be recorded as their own referrer. Without it, a signup form that pre-fills the referral field from the current user, or a user entering their own code to collect a referral bonus, would create a self-referral and possibly a fraudulent reward.

**chk_rider_preferences_conversation** allows only QUIET, SOME, or CHATTY. Without it, different app versions could store "Quiet," "quiet," or "no talking," and none of those would ever equal a driver's preference. The matcher would silently fail to pair compatible riders and drivers.

**chk_rider_preferences_temp** allows only COOL, MODERATE, or WARM. Without it, free-text entries like "68F" or misspellings would store preferences the matcher can't compare with anything.

**chk_rider_preferences_vehicle_class** allows only ECONOMY, COMFORT, XL, or LUXURY. Without it, a typo such as "LUXERY" or a class name from an old app version would request a class no vehicle has, and the rider would never be matched.

### Vehicles and drivers

**chk_vehicles_class** allows only the four approved classes. Without it, onboarding staff typing "SUV" or "Standard" would register cars that no rider preference could ever match.

**chk_vehicles_capacity** limits seats to 1–15. Without it, a data-entry slip such as 40 instead of 4 would let the matcher assign a pooled trip with more riders than the car can safely carry.

**chk_drivers_conversation** allows the same three values as the rider side. It uses the identical list on purpose, because matching only works when both sides share one vocabulary.

**chk_drivers_avg_rating** makes a driver's average outside 1–5 impossible. Without it, the same recalculation bug could give a driver an impossibly high average that pushes them to the top of matching, or a low one that triggers unfair deactivation.

### Trips

**chk_trips_status** allows only the six lifecycle states: REQUESTED, MATCHED, ACCEPTED, IN_PROGRESS, COMPLETED, CANCELED. Without it, a developer writing "DONE," "cancelled," or "PENDING" would create trips that every status-based report, and the one-active-trip rule, would silently ignore.

**chk_trips_driver_vehicle_together** makes it impossible to store a trip with a driver but no vehicle, or a vehicle but no driver. Without it, a matching process that crashes between assigning the driver and assigning the car would leave a half-assigned trip.

**chk_trips_assigned_after_request** makes it impossible for a trip to be MATCHED or later without a driver. Without it, a status update that runs before the assignment is saved, or a manual status change by support staff, would record a trip as "in progress" with no one driving it.

**chk_trips_completed_has_data** makes it impossible to mark a trip COMPLETED without a completion time and a fare. Without it, a trip marked complete before the payment step finishes would become a finished ride that was never charged and can't be timed.

**chk_trips_time_order** makes it impossible for a trip to finish before it was requested. Without it, a phone with the wrong time zone, or imported data with swapped columns, would produce negative trip durations that corrupt wait-time and duration metrics.

**chk_trips_match_score** limits the match score to 0–1. Without it, an algorithm update that returns a percentage (87) instead of a fraction (0.87) would silently break every comparison between match scores and ratings, the very analysis the score exists for.

**chk_trips_fare** makes a negative fare impossible. Without it, a refund or promotion entered as a negative fare would make revenue totals wrong and hide the refund, which should be recorded separately.

### Pooled fares and ratings

**chk_trip_riders_fare_share** makes a negative fare share impossible. Without it, a fare-splitting bug that applies a discount to the wrong rider would record one rider as being paid to ride.

**chk_ratings_direction** allows only RIDER_TO_DRIVER or DRIVER_TO_RIDER. Without it, a new feature writing "rider" or "R2D" would store ratings that neither average calculation counts, so the feedback would vanish from both profiles.

**chk_ratings_score** limits scores to whole numbers 1–5. Without it, an app that sends 0 to mean "no rating given," or a future 10-point scale, would drag averages down and break the 1–5 range that avg_rating depends on.

### What CHECK constraints cannot do

A CHECK examines one row at a time, so rules that compare rows or read another table are handled differently:

- "A driver cannot be on two active trips" compares rows, so it is enforced by the partial unique index uq_trips_one_active_per_driver.
- "Ratings only after the trip is completed" needs the trip's status from another table. The composite foreign keys guarantee only participants can rate; the completion rule needs a trigger and is recorded as future work.
