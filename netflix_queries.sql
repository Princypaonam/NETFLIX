-- ============================================================
--  Netflix Titles Dataset — SQL Analysis Queries
--  Dataset: netflix_titles (8,807 rows, 12 columns)
-- ============================================================

-- TABLE SCHEMA (for reference)
-- CREATE TABLE netflix_titles (
--   show_id      TEXT PRIMARY KEY,
--   type         TEXT,          -- 'Movie' or 'TV Show'
--   title        TEXT,
--   director     TEXT,
--   cast         TEXT,
--   country      TEXT,
--   date_added   TEXT,
--   release_year INTEGER,
--   rating       TEXT,
--   duration     TEXT,
--   listed_in    TEXT,          -- comma-separated genres
--   description  TEXT
-- );


-- ============================================================
-- 1. CONTENT DISTRIBUTION BY TYPE
--    Movies = 6,131 (70%) | TV Shows = 2,676 (30%)
-- ============================================================
SELECT
    type,
    COUNT(*)                                              AS title_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)   AS pct_of_catalog
FROM netflix_titles
GROUP BY type
ORDER BY title_count DESC;


-- ============================================================
-- 2. TOP 10 PRODUCING COUNTRIES WITH CONTENT TYPE SPLIT
--    USA = 2,818 titles | India = 972 | UK = 419
-- ============================================================
SELECT
    country,
    COUNT(*)                                              AS total_titles,
    SUM(CASE WHEN type = 'Movie'   THEN 1 ELSE 0 END)    AS movies,
    SUM(CASE WHEN type = 'TV Show' THEN 1 ELSE 0 END)    AS tv_shows,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)   AS pct_of_catalog
FROM netflix_titles
WHERE country IS NOT NULL
GROUP BY country
ORDER BY total_titles DESC
LIMIT 10;


-- ============================================================
-- 3. ANNUAL CONTENT ADDITIONS (GROWTH TREND)
--    Peak: 1,999 titles added in 2019 (4.6× of 2016 volume)
-- ============================================================
SELECT
    CAST(SUBSTR(date_added, -4) AS INTEGER)              AS year_added,
    COUNT(*)                                             AS titles_added,
    SUM(COUNT(*)) OVER (ORDER BY SUBSTR(date_added, -4)) AS cumulative_total
FROM netflix_titles
WHERE date_added IS NOT NULL
  AND TRIM(date_added) != ''
GROUP BY year_added
ORDER BY year_added;


-- ============================================================
-- 4. TOP GENRES BY FREQUENCY
--    International Movies = 2,752 | Dramas = 2,427 | Comedies = 1,674
-- ============================================================
WITH genre_exploded AS (
    -- Split the comma-separated listed_in field into individual genres
    SELECT
        show_id,
        type,
        TRIM(value) AS genre
    FROM netflix_titles,
         json_each('["' || REPLACE(listed_in, ', ', '","') || '"]')
    WHERE listed_in IS NOT NULL
)
SELECT
    genre,
    COUNT(*)                                              AS title_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)   AS pct_of_catalog,
    ROUND(AVG(CAST(n.release_year AS FLOAT)), 1)          AS avg_release_year
FROM genre_exploded ge
JOIN netflix_titles n USING (show_id)
GROUP BY genre
ORDER BY title_count DESC
LIMIT 10;


-- ============================================================
-- 5. RATING DISTRIBUTION
--    TV-MA = 3,207 (36%) — majority targets adult audiences
-- ============================================================
SELECT
    rating,
    COUNT(*)                                              AS title_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)   AS pct_of_catalog
FROM netflix_titles
WHERE rating IS NOT NULL
GROUP BY rating
ORDER BY title_count DESC;


-- ============================================================
-- 6. AVERAGE MOVIE DURATION BY GENRE
--    Overall average movie runtime: 99.6 minutes
-- ============================================================
WITH movies_with_genre AS (
    SELECT
        show_id,
        TRIM(value)                                       AS genre,
        CAST(REPLACE(duration, ' min', '') AS INTEGER)    AS runtime_mins
    FROM netflix_titles,
         json_each('["' || REPLACE(listed_in, ', ', '","') || '"]')
    WHERE type = 'Movie'
      AND duration LIKE '%min%'
      AND listed_in IS NOT NULL
)
SELECT
    genre,
    COUNT(*)                                              AS movie_count,
    ROUND(AVG(runtime_mins), 1)                           AS avg_runtime_mins,
    MIN(runtime_mins)                                     AS min_mins,
    MAX(runtime_mins)                                     AS max_mins
FROM movies_with_genre
GROUP BY genre
HAVING movie_count >= 50
ORDER BY avg_runtime_mins DESC
LIMIT 10;


-- ============================================================
-- 7. MISSING DATA AUDIT
--    Director field: 2,634 nulls (29.9% of dataset)
-- ============================================================
SELECT
    'show_id'      AS column_name, SUM(CASE WHEN show_id IS NULL OR show_id = ''      THEN 1 ELSE 0 END) AS null_count FROM netflix_titles
UNION ALL
SELECT 'type',         SUM(CASE WHEN type IS NULL OR type = ''         THEN 1 ELSE 0 END) FROM netflix_titles
UNION ALL
SELECT 'director',     SUM(CASE WHEN director IS NULL OR director = '' THEN 1 ELSE 0 END) FROM netflix_titles
UNION ALL
SELECT 'cast',         SUM(CASE WHEN cast IS NULL OR cast = ''         THEN 1 ELSE 0 END) FROM netflix_titles
UNION ALL
SELECT 'country',      SUM(CASE WHEN country IS NULL OR country = ''   THEN 1 ELSE 0 END) FROM netflix_titles
UNION ALL
SELECT 'date_added',   SUM(CASE WHEN date_added IS NULL OR date_added = '' THEN 1 ELSE 0 END) FROM netflix_titles
UNION ALL
SELECT 'rating',       SUM(CASE WHEN rating IS NULL OR rating = ''     THEN 1 ELSE 0 END) FROM netflix_titles;


-- ============================================================
-- 8. CONTENT STRATEGY: HIGH-VOLUME DIRECTORS (TOP 10)
-- ============================================================
SELECT
    director,
    COUNT(*)                                              AS titles_directed,
    COUNT(DISTINCT type)                                  AS content_types,
    MIN(release_year)                                     AS earliest,
    MAX(release_year)                                     AS latest
FROM netflix_titles
WHERE director IS NOT NULL
  AND TRIM(director) != ''
GROUP BY director
ORDER BY titles_directed DESC
LIMIT 10;


-- ============================================================
-- 9. TV SHOWS: SEASON COUNT DISTRIBUTION
-- ============================================================
SELECT
    duration                                              AS seasons,
    COUNT(*)                                              AS show_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)   AS pct
FROM netflix_titles
WHERE type = 'TV Show'
  AND duration IS NOT NULL
GROUP BY duration
ORDER BY show_count DESC
LIMIT 10;


-- ============================================================
-- 10. YEAR-OVER-YEAR GROWTH RATE IN CONTENT ADDITIONS
-- ============================================================
WITH yearly AS (
    SELECT
        CAST(SUBSTR(date_added, -4) AS INTEGER)   AS yr,
        COUNT(*)                                  AS titles_added
    FROM netflix_titles
    WHERE date_added IS NOT NULL
      AND TRIM(date_added) != ''
      AND CAST(SUBSTR(date_added, -4) AS INTEGER) BETWEEN 2015 AND 2021
    GROUP BY yr
)
SELECT
    yr,
    titles_added,
    LAG(titles_added) OVER (ORDER BY yr)                              AS prev_year,
    ROUND(
        (titles_added - LAG(titles_added) OVER (ORDER BY yr)) * 100.0
        / LAG(titles_added) OVER (ORDER BY yr),
        1
    )                                                                  AS yoy_growth_pct
FROM yearly
ORDER BY yr;
