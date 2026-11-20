# Unit 6 Write-Up: Window Functions on the Ride-Sharing Platform

**Platform:** a ride-sharing service modeled in PostgreSQL (`ex603_rideshare`): 30 riders, 15 drivers, 5 badge types, 25 badge awards and 200 trips in 2023.
**Mapping:** drivers are the *producers*, trips are the *events*, and `fare_amount` is the main *metric*. Unless stated otherwise, analyses use completed trips only (156 of 200).

---

## Task 6.1: Compute across a window without collapsing

### Question 1: A question that needs each row next to its group's average

**The question:** *Which completed trips earned at least double their own driver's average fare?*

Answering it means comparing a single trip with the norm for the driver who made it, so the trip and the driver's average have to sit on the same row. `AVG(fare_amount) OVER (PARTITION BY driver_id)` does exactly that. It returns all 156 trips, each carrying its driver's average, and flags 9 of them as unusual. The most extreme is Driver_08's $59.14 trip, at 2.48 times their $23.82 average. Next is Driver_04's $70.86 trip, at 2.42 times their $29.23 average.

**Why GROUP BY alone can't answer it:** `GROUP BY driver_id` collapses each driver's trips into one row, so it returns 13 rows instead of 156. The averages are identical, but the individual trips, with their IDs, dates and fares, are gone. With no trip left to compare, the question "is *this* trip unusual?" can't be asked. GROUP BY can say that Driver_08's highest fare was $59.14 (with `MAX`), but not which trip it was, when it happened, or how many other trips were also unusual. You *can* recover the answer by joining the GROUP BY result back to the trips table, but that rebuilds by hand what the window function does in one step.

### Question 2: A platform feature that uses the ranking, and which function it should use

**Feature:** a monthly **"Top Drivers" leaderboard** in the driver app, recognizing drivers by trips completed, revenue and badges earned.

**Function: `RANK()`.** A public leaderboard makes a claim about people, so two drivers with identical results must appear as equals, and a driver's position should reflect how many drivers are genuinely ahead of them. Only RANK does both. My data shows why each alternative fails:

- **`ROW_NUMBER()`** breaks ties arbitrarily. Drivers 8 and 10 both completed 19 trips, yet one would be published as #1 and the other as #2, based on nothing but row order. On a public leaderboard, that's an unfair and unexplainable result.
- **`DENSE_RANK()`** keeps ties together but closes the gaps, which overstates position. Six drivers each earned two badges. Only three drivers are ahead of them (Driver_10 with four, and Drivers 2 and 4 with three), so they are truly fourth, and RANK says so. DENSE_RANK would label them third, implying only two drivers are ahead.
- **`RANK()`** gives tied drivers the same place and then skips (1, 1, 3), so the skipped number honestly shows how many drivers are ahead.

DENSE_RANK would be the right choice for a different feature: *tiers* (Gold, Silver, Bronze), where the question is "which level are you in," not "how many people beat you." ROW_NUMBER fits only when a feature needs exactly N slots, such as a three-card carousel, and then it should have an explicit, defensible tiebreaker like "earliest to reach the total."

---

## Task 6.2: Compare each row to its neighbors

### Question 1: What a large delta tells someone, and what they should do

The delta (current fare minus previous fare) shows how much a driver's earnings jump from one trip to the next. Driver_04's sequence is $8.95, $14.34, $70.86, then $22.77, so the deltas are +$5.39, +$56.52 and −$48.09. Driver_08 has swings of +$48.66 and −$32.04 between consecutive trips.

**What a large delta means here:** on this platform, a large delta usually reflects the *trip*, not the *driver*. Both standout fares were long trips taken at the maximum 2.0× surge multiplier: Driver_04's $70.86 trip covered 26.1 km, and Driver_08's $59.14 trip covered 23.4 km, both in the evening. The average surge on completed trips is about 1.25×. A large positive delta followed by a large negative one is a single surge-priced long trip, not a change in driver performance.

**What to do about it:**
1. **Verify it first.** Check the trip's `distance_km`, `surge_multiplier` and duration. If the fare doesn't match them, treat it as a pricing or data-entry error and correct it.
2. **If it's legitimate, don't judge drivers by single-trip deltas.** Driver dashboards and incentives should use smoothed measures (a moving average, or trips and revenue per week), so one surge trip doesn't make a driver look like they're improving and then collapsing.
3. **Learn from it.** Large positive deltas point to the most valuable trip types: long, evening, surge. Operations can use that to position drivers at the right times and places.

### Question 2: Why a running total answers a question a plain SUM can't

A plain `SUM(fare_amount)` answers one question: how much did the platform earn in total? The answer is $3,418.75 for 2023, a single number available only once the year is over.

A running total, `SUM(...) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`, answers **"are we on track, and when did that change?"** Measured against my target of $3,600 for the year ($300 a month), it shows the *path* to the final number. The platform was ahead of pace only in February ($743.69 against $600). It fell behind in March and stayed behind for the rest of the year. The gap was widest in August (about $173 behind), and the year finished at 95% of target. A plain SUM can't show any of that. Leadership could only have acted on the running total, because it shows the slip while there's still time to respond.

### Question 3: Why I chose this moving-average window size

I used a **three-month** window: `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`. I first generated all twelve months, so three rows always equals three calendar months.

- **The data is noisy at the monthly level.** Each month has only 8 to 17 completed trips, so a single surge fare can move a month's revenue by 15 to 20%. A one-month view (the raw series) mostly shows noise, such as March's 70% drop.
- **Three months is one quarter.** That matches how the business plans and reports, and it matches the "where do we stand this quarter" question leadership asks.
- **It stays responsive.** Longer windows smooth away real changes. The three-month average peaked at $340.26 in October and ended at $278.28 in December, so it catches the November dip, which leaves the platform below its $300 pace. A six-month average ends December at about $289, which hides most of that slide. A twelve-month average is just the annual average of about $285, which reacts to nothing.

A different window tells a different story: the six-month view says "roughly on pace," while the three-month view says "recently slipping." I chose three months because it catches a slide within a quarter while still filtering out one-month spikes.

### Question 4: What a gap means on this platform

The longest gap belongs to **Driver_09**: 112 days with no trips, from January 5 to April 28, 2023, about seven times their usual gap of roughly 16 days. My judgment is that it is **a real stop in activity, as far as this data can show, and not a platform-level data-quality problem**. I can't fully rule out a recording loss specific to this driver.

**How I know:**
- **It isn't a platform-wide outage.** During Driver_09's gap, the system recorded 61 trips from 11 other drivers, so data was flowing.
- **No recorded trips were deleted.** Trip IDs run from 1 to 200 with no missing numbers. A continuous sequence can't reveal trips that were *never* recorded, though.
- **It isn't a side effect of my filter.** I measured gaps using *all* trip statuses, because a cancelled or disputed trip still shows the driver was working. That choice matters: with completed trips only, Driver_11 shows a 135-day gap, but they had cancelled trips during that time. Their "gap" was a side effect of how I filtered events, not a stop in activity.

**What I can't tell:** the trips table records only what happened, so a break, a suspension, a driver who was online but received no requests, and an app that failed to sync all look identical. The `is_active` flag doesn't help, because it's an undated snapshot. It marks Driver_09 inactive even though they drove until December 17. Settling it would need a driver status history with timestamps, session or availability logs, and ingestion audit logs. Each explanation calls for a different response: a real stop calls for re-engagement outreach, a data-quality failure calls for fixing the pipeline, and a recording side effect calls for changing how activity is defined.

---

## Task 6.3: Build the reporting patterns

### Question 1: The feature top-N would power, and why three

**Feature:** a **"Personal Bests" card** on each driver's profile in the driver app, showing their three highest-fare trips with the date, city and fare. Operations can use the same query to see which kinds of trips are most valuable for each driver.

**Why three, rather than one or ten:**
- **One is fragile.** A single top trip is often a fluke. Driver_04's best fare, $70.86, is more than three times their next-best ($22.77) and came from a 2.0× surge trip. Shown alone, it would misrepresent what that driver typically earns.
- **Ten is too many for this platform.** Drivers completed between 4 and 19 trips in the year, with a median of 12. A top ten would be *all* of Driver_04's trips and most of a typical driver's trips, so it stops being a highlight. Ten rows also don't fit on a phone card.
- **Three shows a pattern.** With three trips you can tell a consistent driver from a lucky one. Driver_10's top three are all within a dollar of each other ($35.21, $34.54, $34.41), which is a dependable earner. Driver_04's top three drop from $70.86 to $14.34, which shows one exceptional trip.

Ties at third place use `RANK()`, so tied trips are all kept rather than one being dropped arbitrarily. No driver in the current data has a tie at third.

### Question 2: What a large month-over-month change means, and what to do about it

**What it means here:** revenue is trips multiplied by average fare, so a large change points to either demand and driver supply (how many trips) or pricing and trip mix (how much each trip earns). With only 8 to 17 trips a month, it can also be plain noise. The March drop of 70% ($453.44 to $135.98) combined both: completed trips halved from 17 to 8, and the average fare fell from about $26.67 to $17.00. April then rebounded 91%, and November fell 48% before December recovered 41%. Over the year, eight months improved and three declined: March, June and November.

**What someone should do about it:**
1. **Set a threshold that triggers action.** For example, any month-over-month change beyond ±30%, or the three-month average falling below the $300 pace.
2. **Break the change down before reacting.** Split it into trip count, average fare, and number of active drivers, and confirm the `month_check` column shows no missing month.
3. **Respond to the cause.**
   - If trips dropped because fewer drivers were active, run driver re-engagement or incentives.
   - If rider demand dropped, run rider promotions.
   - If the change came from one or two surge fares, don't overreact; watch the three-month average instead.
4. **Assign an owner and a follow-up.** Someone should report back on whether the next month confirmed or reversed the change.

A month-over-month change becomes a real metric only when a threshold triggers a breakdown and that breakdown leads to an action with an owner.

---

## Reflection

The biggest lesson from this unit is that window functions are about *context without loss*. GROUP BY answers questions about groups. Window functions let every row keep its detail while also seeing its group, its neighbors, or everything before it, and that's what most real business questions need: is this trip unusual, is this driver improving, are we on track.

The second lesson is that every technique carries a decision that someone should be able to explain. How ties are handled decides who counts as equal on a leaderboard. The frame decides what "recent" means. `ROWS` counts rows, not calendar time, so missing months quietly corrupt both moving averages and month-over-month comparisons unless the calendar is filled in first. Even "unusual" needed a definition: I chose double the driver's own average. Making those choices explicit, in comments and in this write-up, made the analysis more trustworthy than the SQL alone.

Finally, the data has limits that SQL can't fix. I can find Driver_09's 112-day gap, but not explain it, and with only about 13 trips a month, percentages swing hard. In a next iteration, I would add a driver status history with timestamps, availability or session logs, and multiple years of trips, so the platform could separate real changes from recording artifacts and seasonal patterns.
