DROP TABLE IF EXISTS zomato;

CREATE TABLE zomato (
    restaurant_id INT PRIMARY KEY,
    restaurant_name VARCHAR(150),
    country_code INT,
    city VARCHAR(100),
    address VARCHAR(255),
    locality VARCHAR(150),
    locality_verbose VARCHAR(200),
    longitude NUMERIC(10,6),
    latitude NUMERIC(10,6),
    cuisines VARCHAR(255),
    average_cost_for_two INT,
    currency VARCHAR(50),
    has_table_booking VARCHAR(5),
    has_online_delivery VARCHAR(5),
    is_delivering_now VARCHAR(5),
    switch_to_order_menu VARCHAR(5),
    price_range INT,
    aggregate_rating NUMERIC(3,1),
    rating_color VARCHAR(50),
    rating_text VARCHAR(50),
    votes INT
);


COPY zomato
FROM '/tmp/zomato.csv'
WITH (FORMAT csv, DELIMITER ',', HEADER, ENCODING 'LATIN1');



-- 1. Total restaurants
SELECT COUNT(*) AS total_restaurants 
FROM zomato;

-- 2. Total unique cities
SELECT COUNT(DISTINCT city) AS total_cities 
FROM zomato;

-- 3. Total unique countries
SELECT COUNT(DISTINCT country_code) AS total_countries 
FROM zomato;

-- 4. Top 10 cities by number of restaurants
SELECT city, COUNT(*) AS total_restaurants
FROM zomato
GROUP BY city
ORDER BY total_restaurants DESC
LIMIT 10;

-- 5. Top 10 most popular cuisines
SELECT cuisines, COUNT(*) AS restaurant_count
FROM zomato
WHERE cuisines IS NOT NULL
GROUP BY cuisines
ORDER BY restaurant_count DESC
LIMIT 10;



-- 6. Average rating by city (only cities with 50+ restaurants)
SELECT city,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       COUNT(*) AS total_restaurants
FROM zomato
WHERE aggregate_rating > 0
GROUP BY city
HAVING COUNT(*) > 50
ORDER BY avg_rating DESC
LIMIT 10;

-- 7. Online delivery impact on ratings
SELECT has_online_delivery,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       COUNT(*) AS total_restaurants
FROM zomato
WHERE aggregate_rating > 0
GROUP BY has_online_delivery;

-- 8. Table booking impact on ratings
SELECT has_table_booking,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       COUNT(*) AS total_restaurants
FROM zomato
WHERE aggregate_rating > 0
GROUP BY has_table_booking;

-- 9. Price range analysis
SELECT price_range,
       COUNT(*) AS total_restaurants,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       ROUND(AVG(average_cost_for_two),2) AS avg_cost
FROM zomato
GROUP BY price_range
ORDER BY price_range;

-- 10. Cities with highest average cost for two
SELECT city,
       ROUND(AVG(average_cost_for_two),2) AS avg_cost,
       COUNT(*) AS total_restaurants
FROM zomato
GROUP BY city
HAVING COUNT(*) > 50
ORDER BY avg_cost DESC
LIMIT 10;


-- 11. Rank cities by average rating using window function
SELECT city,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       COUNT(*) AS total_restaurants,
       DENSE_RANK() OVER(
           ORDER BY AVG(aggregate_rating) DESC
       ) AS city_rank
FROM zomato
WHERE aggregate_rating > 0
GROUP BY city
HAVING COUNT(*) > 50;

-- 12. Best rated restaurant in each price range
SELECT price_range, restaurant_name, city, aggregate_rating
FROM (
    SELECT price_range, restaurant_name, city, aggregate_rating,
           ROW_NUMBER() OVER(
               PARTITION BY price_range
               ORDER BY aggregate_rating DESC
           ) AS rn
    FROM zomato
    WHERE aggregate_rating > 0
) x
WHERE rn = 1;

-- 13. Percentage of restaurants offering online delivery per city
SELECT city,
       COUNT(*) AS total,
       SUM(CASE WHEN has_online_delivery = 'Yes' THEN 1 ELSE 0 END) AS delivery_count,
       ROUND(100.0 * SUM(CASE WHEN has_online_delivery = 'Yes' THEN 1 ELSE 0 END) / COUNT(*), 2) AS delivery_percentage
FROM zomato
GROUP BY city
HAVING COUNT(*) > 50
ORDER BY delivery_percentage DESC;

-- 14. Top cuisines by average rating with decent sample size
SELECT cuisines,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       SUM(votes) AS total_votes,
       COUNT(*) AS restaurant_count
FROM zomato
WHERE aggregate_rating > 0
AND cuisines IS NOT NULL
GROUP BY cuisines
HAVING COUNT(*) > 50
ORDER BY avg_rating DESC
LIMIT 10;

-- 15. CTE: Cities where avg cost is above overall average
WITH overall_avg AS (
    SELECT AVG(average_cost_for_two) AS avg_cost
    FROM zomato
),
city_avg AS (
    SELECT city,
           ROUND(AVG(average_cost_for_two),2) AS city_avg_cost,
           COUNT(*) AS total_restaurants
    FROM zomato
    GROUP BY city
    HAVING COUNT(*) > 50
)
SELECT c.city, 
       c.city_avg_cost, 
       c.total_restaurants,
       ROUND(o.avg_cost,2) AS overall_avg_cost
FROM city_avg c
CROSS JOIN overall_avg o
WHERE c.city_avg_cost > o.avg_cost
ORDER BY c.city_avg_cost DESC;

-- 16. Rating distribution with running total
SELECT rating_text,
       COUNT(*) AS total_restaurants,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM zomato
GROUP BY rating_text
ORDER BY total_restaurants DESC;


-- 17. Find cuisines that are HIGH COST but LOW RATED (value for money analysis)
SELECT cuisines,
       ROUND(AVG(average_cost_for_two),2) AS avg_cost,
       ROUND(AVG(aggregate_rating),2) AS avg_rating,
       COUNT(*) AS total_restaurants,
       CASE 
           WHEN AVG(average_cost_for_two) > 1500 AND AVG(aggregate_rating) < 3.5 
           THEN 'Overpriced Underperformer'
           WHEN AVG(average_cost_for_two) < 500 AND AVG(aggregate_rating) > 4.0 
           THEN 'Hidden Gem'
           WHEN AVG(average_cost_for_two) > 1500 AND AVG(aggregate_rating) > 4.0 
           THEN 'Premium Worth It'
           ELSE 'Average'
       END AS value_category
FROM zomato
WHERE aggregate_rating > 0
AND cuisines IS NOT NULL
GROUP BY cuisines
HAVING COUNT(*) > 30
ORDER BY avg_rating DESC;


-- 18. For each city find what percentage of restaurants are "Excellent" rated
SELECT city,
       COUNT(*) AS total_restaurants,
       SUM(CASE WHEN rating_text = 'Excellent' THEN 1 ELSE 0 END) AS excellent_count,
       ROUND(100.0 * SUM(CASE WHEN rating_text = 'Excellent' THEN 1 ELSE 0 END) / COUNT(*), 2) AS excellent_percentage,
       DENSE_RANK() OVER(ORDER BY 
           100.0 * SUM(CASE WHEN rating_text = 'Excellent' THEN 1 ELSE 0 END) / COUNT(*) DESC
       ) AS excellence_rank
FROM zomato
GROUP BY city
HAVING COUNT(*) > 50
ORDER BY excellent_percentage DESC;


-- 19. Identify cities with high votes but low ratings (engaged but unsatisfied customers)
WITH city_stats AS (
    SELECT city,
           ROUND(AVG(aggregate_rating),2) AS avg_rating,
           ROUND(AVG(votes),0) AS avg_votes,
           COUNT(*) AS total_restaurants
    FROM zomato
    WHERE aggregate_rating > 0
    GROUP BY city
    HAVING COUNT(*) > 50
)
SELECT city,
       avg_rating,
       avg_votes,
       total_restaurants,
       CASE
           WHEN avg_votes > 500 AND avg_rating < 3.5 THEN 'High Engagement Low Satisfaction'
           WHEN avg_votes > 500 AND avg_rating >= 4.0 THEN 'High Engagement High Satisfaction'
           WHEN avg_votes < 200 AND avg_rating >= 4.0 THEN 'Underrated City'
           ELSE 'Average'
       END AS city_category
FROM city_stats
ORDER BY avg_votes DESC;


-- 20. Find the top restaurant in each city by votes (most talked about)
SELECT city, restaurant_name, cuisines, votes, aggregate_rating
FROM (
    SELECT city, restaurant_name, cuisines, votes, aggregate_rating,
           ROW_NUMBER() OVER(
               PARTITION BY city
               ORDER BY votes DESC
           ) AS rn
    FROM zomato
    WHERE votes > 0
) x
WHERE rn = 1
ORDER BY votes DESC
LIMIT 15;


COPY zomato TO '/tmp/zomato_clean.csv' WITH (FORMAT csv, HEADER);