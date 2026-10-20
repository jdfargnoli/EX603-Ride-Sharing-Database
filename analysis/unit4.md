# Unit 4

## Who acts on it

The Driver Operations Manager acts on it. This is the person accountable for driver quality, who decides which drivers get coaching, performance review, incentives or deactivation. Regional operations leads use the region × driver view from Q4 to do the same within their region.

## What the average conceals: its distribution

A driver's average fare collapses every trip into one number. Two drivers can both average about $20, one with consistent fares and the other swinging between $7 and $47. In my data, Driver 1's completed fares range from $7.40 (Danang, 3.12 km) to $29.07 (Haiphong, 23.97 km).

The average also blends three effects that are not driver performance: trip length, surge exposure (1.00 vs. 1.25 multipliers), and city mix. It is also pulled down by cancelled trips recorded at $0.00, which is the zero minimum I flagged in Q1. A higher average can mean a driver gets longer or surge-priced trips, not that they perform better.

## What the count conceals: who is counted

The event count, and the failure rate built on it, treats every non-completed trip as the driver's failure. The `cancellation_reason` column shows that's not true. Trip 4 failed because of a rider no-show and trip 8 because of a payment failure; neither is the driver's fault. Trips 5 and 11 are disputed, with an unresolved outcome. Counting all of these against the driver would penalize them for rider and system behavior.

The count also can't show whether a driver's volume comes from many different riders or a few repeat ones. In addition, cancelled trips still log a distance (10.65 km on trip 4), which suggests the event logging itself counts things that never happened.

## What I'd need to see next

- **Failures attributed by cause:** separate driver-caused, rider-caused and system-caused failures, and rebuild the failure rate using only driver-caused cases.
- **The distribution behind each average:** median, standard deviation, and min/max of completed fares per driver.
- **Normalized performance:** fare per km and average surge per driver, so pricing and trip mix are separated from performance.
- **Rider concentration:** distinct riders per driver.
- **Trend over time:** monthly results per driver, to tell a bad month from a persistent problem.
- **Dispute resolution data:** the final outcome and fare for disputed trips, which this table doesn't contain.
