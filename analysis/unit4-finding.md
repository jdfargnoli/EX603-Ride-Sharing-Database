# Unit 4 Findings

## There were 200 trips among 13 drivers

**The true failure rate is 22%.** 44 of 200 trips ended in a cancellation or dispute, so more than one in five rides fails. Counting only our 10 regular drivers (12 or more trips each), the rate is about the same, 21%.

**The problem is broad, not a few bad actors.** The typical regular driver fails on about 24% of trips. Eight of the ten regular drivers fall between 18% and 39%. If our three worst drivers performed at the platform average, we would avoid only about 5 of the 44 failures. Fixing a few individuals will not fix this. The process itself needs attention.

### Drivers to investigate: 3, 9 and 10

- **Drivers 3 and 9** have the highest failure rates among regular drivers, about two extra failed trips each compared with a typical driver. With so few trips, this could still be bad luck, so treat it as a conversation, not a verdict.
- **Driver 10 is the strongest signal in the data.** Zero failures in 19 trips is very unlikely to be chance (under a 1% probability at our platform rate), and driver 8 is similar. Learning what they do differently, whether in routes, hours, communication or acceptance habits, may do more to fix the 22% than any corrective action.

**Watch list:** Driver 1 failed on 4 of 11 trips (36%). That's just under the 12-trip bar, so it's too early to judge, but worth monitoring.

**One data gap to close:** we can't yet tell *who* cancelled a trip, the rider or the driver, and disputes aren't always the driver's fault. Recording the cancellation initiator would make this analysis much sharper.

| Driver | Trips | Failed | Failure rate | Note |
|---|---|---|---|---|
| 3 | 13 | 5 | 38.5% | Highest among regular drivers |
| 9 | 14 | 5 | 35.7% | Second highest |
| 11 | 16 | 5 | 31.3% | Above typical |
| … | | | | 18–28% for most others |
| 8 | 20 | 1 | 5.0% | Far better than typical |
| 10 | 19 | 0 | 0% | No failures at all |

## Why conditional aggregation: one pass vs. separate queries

Conditional aggregation, `SUM(CASE WHEN … THEN 1 ELSE 0 END)`, evaluates every condition while the database reads each row once. Two separate filtered queries, one with `WHERE trip_status = 'cancelled'` and one with no filter, each read the table independently, so the work roughly doubles. Add a third or fourth metric and it grows again.

At a million rows, the difference stops being academic. Without a selective index, each query performs a full table scan, and reading data is usually the most expensive part of a query. Grouping is also repeated: each query rebuilds its own per-driver groups (hash or sort) before returning. Then the separate results must be joined back together by `driver_id` to compute a failure rate, which adds yet another expensive step.

Correctness matters too. Separate queries run at different moments, so in a live system a trip inserted between them can make numerator and denominator disagree. One pass computes both counts from the same snapshot, so the percentages always reconcile.

One caveat: if one condition is rare and indexed, a separate query reading only those rows may be cheaper for that single number. For dashboards needing several metrics per group, one pass wins.
