# World Life Expectancy Project 

USE world_life_expectancy;

-- STEP 1: DATA CLEANING

-- Switching off SQL Safety mode to allow updates
SET SQL_SAFE_UPDATES = 0;

-- Reviewing all data
SELECT * FROM world_life_expectancy
;

-- Making a copy of the original data to a new table
CREATE TABLE world_life_expectancy_backup LIKE world_life_expectancy;
INSERT INTO world_life_expectancy_backup
SELECT * FROM world_life_expectancy
;

-- Checking for duplicates using the Country and Year columns
SELECT
  Row_ID, 
  Country,
  Year,
  CONCAT(Country, Year),
  COUNT(CONCAT(Country, Year))
FROM world_life_expectancy
GROUP BY
  Country,
  Year,
  CONCAT(Country, Year)
HAVING
  COUNT(CONCAT(Country, Year)) > 1
  ;
  
-- Deleting the duplicate rows using Row_ID
DELETE FROM world_life_expectancy
WHERE Row_ID IN (
    SELECT Row_ID
    FROM (
        SELECT
            Row_ID,
            CONCAT(Country, Year) AS CountryYear,
            ROW_NUMBER() OVER (
                PARTITION BY CONCAT(Country, Year)
                ORDER BY   CONCAT(Country, Year)
            ) AS Row_Num
        FROM world_life_expectancy
    ) AS Row_table
    WHERE Row_Num > 1
);

-- Checking nulls in Status Column
SELECT *
FROM world_life_expectancy
WHERE Status = ''
;

-- Checking what entries are possible in Status Column
SELECT DISTINCT(Status)
FROM world_life_expectancy
WHERE Status <> ''
;

-- Checking Countries with "Developing" Status
SELECT DISTINCT(Country)
FROM world_life_expectancy
WHERE Status = 'Developing'
;

-- Filling in blank Status entries for "Developing" Countries
UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
SET t1.Status = 'Developing'
WHERE t1.Status = ''
  AND t2.Status <> ''
  AND t2.Status = 'Developing';
;

-- Filling in blank Status entries for "Developed" Countries
UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
	ON t1.Country = t2.Country
SET t1.Status = 'Developed'
WHERE t1.Status = ''
  AND t2.Status <> ''
  AND t2.Status = 'Developed';

-- Checking nulls in Life expectancy Column
SELECT *
FROM world_life_expectancy
WHERE `Life expectancy` = '';

-- Checking best way to fill nulls in Life expectancy Column
SELECT
  Country,
  Year,
  `Life expectancy`
FROM world_life_expectancy
WHERE Country IN (
  SELECT DISTINCT Country
  FROM world_life_expectancy
  WHERE `Life expectancy` = ''
)
ORDER BY
  Country,
  Year
  ;

-- Calculating average values (from year above and below) to use to fill Life expectancy blanks 
SELECT t1.Country, t1.Year, t1.`Life expectancy`,
       t2.Country, t2.Year, t2.`Life expectancy`,
       t3.Country, t3.Year, t3.`Life expectancy`,
       ROUND((t2.`Life expectancy` + t3.`Life expectancy`)/2,1) AS "Avg Value"
FROM world_life_expectancy t1
JOIN world_life_expectancy t2
  ON t1.Country = t2.Country
  AND t1.Year    = t2.Year - 1
JOIN world_life_expectancy t3
  ON t1.Country = t3.Country
  AND t1.Year    = t3.Year + 1
WHERE t1.`Life expectancy` = ''
;

-- Updating the Life expectancy blanks to insert the appropriate average values
UPDATE world_life_expectancy t1
JOIN world_life_expectancy t2
  ON t1.Country = t2.Country
  AND t1.Year    = t2.Year - 1
JOIN world_life_expectancy t3
  ON t1.Country = t3.Country
  AND t1.Year    = t3.Year + 1
SET t1.`Life expectancy` = ROUND((t2.`Life expectancy` + t3.`Life expectancy`)/2,1)
WHERE t1.`Life expectancy` = '';
;

-- STEP 2: EXPLORATORY DATA ANALYSIS

-- Checking Min and Max Life expectancy by country and Life expectancy gains
SELECT Country, MIN(`Life expectancy`), 
MAX(`Life expectancy`), 
ROUND(MAX(`Life expectancy`)-MIN(`Life expectancy`),1) AS 'Life expectancy gains'
FROM world_life_expectancy
GROUP BY Country
HAVING Min(`Life Expectancy`) <> 0
AND MAX(`Life Expectancy`) <> 0
ORDER BY `Life expectancy gains` DESC
;

-- Checking how Global Avg Life Expectancy Changed by Year
SELECT Year, ROUND(AVG(`Life expectancy`), 2) AS 'Avg Life Expectancy'
FROM world_life_expectancy
WHERE `Life Expectancy` <> 0
AND `Life Expectancy` <> 0
GROUP BY Year
;

-- Checking the correlation between a country's avg Life Expectancy and their avg GDP
SELECT Country,
       ROUND(AVG(`Life expectancy`),1) AS 'Avg Life Expectancy',
       ROUND(AVG(GDP),2) AS 'Avg GDP'
FROM world_life_expectancy
GROUP BY Country
Having `Avg Life Expectancy` > 0
AND `Avg GDP`>0
ORDER BY `Avg GDP` DESC
;

-- Computing the overall average GDP, 
-- then for countries above and below that average:
-- returning row count, average life expectancy, and average GDP in each segment.
WITH avg_gdp AS (
  SELECT AVG(GDP) AS avg_val
  FROM world_life_expectancy
  )
SELECT
  -- High‐GDP segment metrics
  SUM(CASE WHEN w.GDP >= a.avg_val THEN 1 ELSE 0 END) AS High_GDP_Count,
  ROUND(AVG(CASE WHEN w.GDP >= a.avg_val THEN w.GDP ELSE NULL END),1) AS High_GDP_Avg_GDP,
  ROUND(AVG(CASE WHEN w.GDP >= a.avg_val THEN w.`Life expectancy` ELSE NULL END),1) AS High_GDP_Life_Expectancy,
  -- Low‐GDP segment metrics
  SUM(CASE WHEN w.GDP <  a.avg_val THEN 1 ELSE 0 END) AS Low_GDP_Count,
  ROUND(AVG(CASE WHEN w.GDP <  a.avg_val THEN w.GDP ELSE NULL END),1) AS Low_GDP_Avg_GDP,
  ROUND(AVG(CASE WHEN w.GDP <  a.avg_val THEN w.`Life expectancy` ELSE NULL END),1) AS Low_GDP_Life_Expectancy
FROM world_life_expectancy AS w
CROSS JOIN avg_gdp AS a
;

-- Comparing Life expectancy between Developing / Developed countries
SELECT Status,
       COUNT(DISTINCT Country) AS "No. of Countries",
       ROUND(AVG(`Life expectancy`),1) AS "Average Life Expectancy"
FROM world_life_expectancy
GROUP BY Status
;

-- Checking correlation between BMI and Life Expectancy
SELECT Country,
	ROUND(AVG(BMI),1) AS BMI,
	ROUND(AVG(`Life expectancy`),1) AS Life_Exp
FROM world_life_expectancy
GROUP BY Country
HAVING Life_Exp > 0
   AND BMI > 0
ORDER BY BMI DESC
;

-- Creating rolling total for adult deaths per contry deaths per year 
SELECT Country,
       Year,
       `Life expectancy`,
       `Adult Mortality`,
       SUM(`Adult Mortality`) OVER (PARTITION BY Country ORDER BY Year) AS 'Rolling Total'
FROM world_life_expectancy
;

-- Switching on SQL Safety mode to stop updates
SET SQL_SAFE_UPDATES = 0;