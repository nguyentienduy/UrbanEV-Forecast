-- Step 3: sql/queries.sql
CREATE OR REPLACE TABLE ev AS SELECT * FROM 'data/processed/urbanev.parquet';
-- Q1: daily profile of charged energy per zone-hour on weekdays and weekends, with the electricity price
SELECT hour, AVG(CASE WHEN dow < 5 THEN volume END) AS weekday_kwh, AVG(CASE WHEN dow >= 5 THEN volume END) AS weekend_kwh, AVG(e_price) AS price FROM ev GROUP BY 1 ORDER BY 1;
-- Q2: the three regimes used in RQ3
SELECT CASE WHEN festival = 1 THEN 'Spring Festival' WHEN rain = 1 THEN 'rain' ELSE 'normal' END AS regime, COUNT(*) AS zone_hours,
       AVG(volume) AS mean_kwh, STDDEV(volume) AS sd_kwh FROM ev GROUP BY 1 ORDER BY 2 DESC;
-- Q3: zones ranked by mean demand, with their number of charging piles
SELECT zone, MIN(piles) AS piles, AVG(volume) AS mean_kwh, RANK() OVER (ORDER BY AVG(volume) DESC) AS rank FROM ev GROUP BY 1 ORDER BY 4 LIMIT 15;
-- Q4: model table; target is the energy charged in the zone 24 hours ahead; history is known now, tariff and calendar of the target hour are known in advance
CREATE OR REPLACE TABLE feat AS
WITH b AS (
  SELECT zone, ts, hour, piles, volume, occupancy, T, U, rain,
         LEAD(volume, 24) OVER w AS y, LEAD(ts, 24) OVER w AS ts_y, LEAD(e_price, 24) OVER w AS e_price_y, LEAD(s_price, 24) OVER w AS s_price_y,
         LEAD(holiday, 24) OVER w AS holiday_y, LEAD(festival, 24) OVER w AS festival_y, LEAD(dow, 24) OVER w AS dow_y, LEAD(rain, 24) OVER w AS rain_y,
         LAG(volume, 1) OVER w AS vol_lag1, LAG(volume, 24) OVER w AS vol_lag24, LAG(volume, 144) OVER w AS vol_same_hour_last_week,
         AVG(volume) OVER (PARTITION BY zone ORDER BY ts ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) AS vol_mean24,
         AVG(volume) OVER (PARTITION BY zone ORDER BY ts ROWS BETWEEN 167 PRECEDING AND CURRENT ROW) AS vol_mean168,
         SIN(2 * PI() * hour / 24) AS hour_sin, COS(2 * PI() * hour / 24) AS hour_cos
  FROM ev WINDOW w AS (PARTITION BY zone ORDER BY ts))
SELECT * FROM b WHERE y IS NOT NULL AND vol_same_hour_last_week IS NOT NULL;
SELECT COUNT(*) AS n, COUNT(DISTINCT zone) AS zones, MIN(ts) AS first_ts, MAX(ts) AS last_ts FROM feat;
