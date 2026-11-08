-- Task 5.3 Part A: CROSS JOIN (3 teams x 4 statuses = 12 rows)
WITH teams(team) AS (                                          -- Small inline table named teams with one column, team
    VALUES ('Bills'), ('Patriots'), ('Dolphins')       ),      -- 3 rows
statuses(status) AS (                                          -- Small inline table named statuses with one column, status
    VALUES ('Conference Home Field'), ('Division Winner'),
           ('Wildcard'), ('Did Not Qualify')         ),        -- 4 rows
pairs AS (                                                     -- The CROSS JOIN result, saved under the name pairs
    SELECT team, status                                        -- Keep the team and status of each pair
    FROM teams CROSS JOIN statuses              ),             -- Pair every team with every status (12 rows)
report AS (                                                    -- Build the printed report, one row per line of output
    SELECT 1 AS line, '1. Rows in teams' AS step,              -- Line 1: label
           COUNT(*) AS result FROM teams                       -- Count rows in teams (3)
    UNION ALL                                                  -- Stack the next line underneath
    SELECT 2, '1. Rows in statuses', COUNT(*) FROM statuses  -- Line 2: count rows in statuses (4)
    UNION ALL
    SELECT 3, '2. Rows in cross join', COUNT(*) FROM pairs   -- Line 3: count rows in the cross join (12)
)
SELECT step, result                                            -- Show the label and value for each line
FROM report
ORDER BY line;                                                 -- Print the 3 lines in order
-- Step 4: When is a Cartesian product useful, and when is it an error?
-- Useful: when you deliberately want every combination, like the 12 team/playoff-status possibilities above, a schedule grid (every team x every week), or test data.
-- Error: when a join condition is accidentally left out. For example, FROM games, teams with no WHERE games.team_id = teams.team_id pairs every
--   game with every team: far too many rows, inflated totals, and very slow on large tables (10,000 x 1,000 = 10,000,000 rows).