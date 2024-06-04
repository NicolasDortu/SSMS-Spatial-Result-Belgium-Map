BEGIN TRANSACTION;

-- Drop the Belgium Zipcode table if it exists
DROP TABLE IF EXISTS #BelgiumZipcode;

CREATE TABLE #BelgiumZipcode (
    PostalCode INT,
    City VARCHAR(MAX),
    Longitude FLOAT,
    Latitude FLOAT,
    Province VARCHAR(MAX)
);

BULK INSERT #BelgiumZipcode
FROM 'PATH_TO_FILE\zipcode-belgium-format.csv' 
WITH (
  FIRSTROW = 1,
  FIELDTERMINATOR = ',',
  ROWTERMINATOR = '\n',
  CODEPAGE = '1252'
);

-- Add the geog column
ALTER TABLE #BelgiumZipcode
ADD Geog GEOGRAPHY;

-- Update the geog column
UPDATE #BelgiumZipcode
SET Geog = GEOGRAPHY::Point(Latitude, Longitude, 4326);

-- Drop the inhabitants table if it exists
DROP TABLE IF EXISTS #population;

-- Create the inhabitants table from the local People.csv file
CREATE TABLE #population (
    inhabitants INT,
    PostalCode INT,
    City VARCHAR(MAX)
);

-- Insert data from the local CSV file into the #population table
BULK INSERT #population
FROM 'PATH_TO_FILE\inhabitants_by_city_random.csv' 
WITH (
  FIRSTROW = 2,
  FIELDTERMINATOR = ',',
  ROWTERMINATOR = '\n',
  CODEPAGE = '1252'
);

-- Declare variables
DECLARE @maxinhabitants BIGINT;
DECLARE @stdDev FLOAT;
DECLARE @scaleFactor INT = 1;

-- Calculate the total of client in the biggest city and Standard Deviation
SELECT 
    @maxinhabitants = MAX(inhabitants),
    @stdDev = SQRT(VAR(inhabitants))
FROM #population;

SELECT 
    b.City,
    b.Latitude,
    b.Longitude,
    t.inhabitants AS Totalinhabitants,
    -- Convert each city's location into a geography point and create a buffer proportional to the normalized number of inhabitants
    geography::Point(b.Latitude, b.Longitude, 4326).STBuffer(
        (((t.inhabitants * 1.0 / @maxinhabitants) * @stdDev) * @scaleFactor) + 1-- Add a scale factor and a minimum buffer size of 1 to ensure visibility
    ) AS CityArea
FROM 
    #BelgiumZipcode b
INNER JOIN 
    #population t ON b.City = t.City AND b.PostalCode = t.PostalCode;

COMMIT TRANSACTION;
