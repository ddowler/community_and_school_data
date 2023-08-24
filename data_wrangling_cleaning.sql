/*
	Project on Finding correlation between community data and school scores
	Step 2: Data Wrangling and Cleaning using SQL
	By Dereck Dowler
	7/10/2023
*/

/* 
	I will combine all the tables into one table for ease of use
	I will take all the features I want from each table and merge them into the created table
	I will then clean up the table to be used
*/

--	First I will create and initialize a table with data from non high schools

/*
	A large number of rows containing null values was imported from the excel file
	These need to be removed
*/

DELETE FROM nonhs_data
WHERE [School code] IS NULL


--	Now I will create the common table using the features I want and renaming features to be more user friendly

SELECT [School code] AS school_code,
	District AS district,
	[School Name] AS school_name,
	[2022 School type] AS school_type,
	[2022 Weighted mean _(Column AL * 0#4 + Column BR *0#6) _or _(Col] AS state_score
INTO community_school_data
FROM nonhs_data

-- Next I will insert the HS data into this table with corrected column names

-- This deletes empty rows imported

DELETE FROM hs_data
WHERE [School code] IS NULL

INSERT INTO community_school_data
SELECT
	[School code] AS school_code,
	District AS district,
	[School Name] AS school_name,
	[2022 School type] AS school_type,
	[2022 Weighted mean          _(Column AX * 0#4 + Column CP * 0#6)] AS state_score
FROM hs_data

/*
	Some of these schools do not have state score data.
	This is for various reasons ranging from schools with limited enrollment, different evaluation requirements, school opening/closing to list a few reasons
	As such I have chosen to remove these schools from the project
*/

DELETE FROM community_school_data WHERE state_score is NULL;

/* 
	Now I will add in the information from combined high schools and middle schools
	This is a little more difficult as each school contains two schools, middle and high
	I want to create two different records for each school while allowing me to differentiate if the are a combined school
	To do this I will add a column is_mshs
	The drawback to this method is there will be duplicate school_codes which could be used as a primary key
	But, I did not want to alter this column so I may use this code in future joins
*/

-- create is_hsms column and populate with no
ALTER TABLE community_school_data
ADD is_mshs VARCHAR(3)

UPDATE community_school_data
SET is_mshs = 'no'

-- remove empty imported rows
DELETE FROM mshs_data
WHERE [School code] IS NULL

-- add the is_mshs column and initialize
ALTER TABLE mshs_data
ADD is_mshs VARCHAR(3)

UPDATE mshs_data
SET is_mshs = 'yes'

UPDATE mshs_data
SET [2022 School type] = 'MS'

-- INSERT combined schools middle school data into the table

INSERT INTO community_school_data
SELECT
	[School code] AS school_code,
	District AS district,
	[School Name] AS school_name,
	[2022 School type] AS school_type,
	[2022 NonHS weighed mean _(Column AL * 0#4 + Column DJ * 0#6)_or ] AS state_score,
	is_mshs
FROM mshs_data

-- change school type to HS and insert combined schools high school data

UPDATE mshs_data
SET [2022 School type] = 'HS'

INSERT INTO community_school_data
SELECT
	[School code] AS school_code,
	District AS district,
	[School Name] AS school_name,
	[2022 School type] AS school_type,
	[2022 HS weighed mean _(Column CD * 0#4 + Column FB * 0#6)_or _(C] AS state_score,
	is_mshs
FROM mshs_data

/*
	Next I will add the towns the schools are in as other data is dependant on town names
	This will be completed with a left join
*/

-- add town name and school type to table

ALTER TABLE community_school_data
ADD
	org_type VARCHAR(20),
	town VARCHAR(30)

/* 
	take town name and org type from the address table
	and left join to our project data table
*/

UPDATE community_school_data
SET
	community_school_data.org_type = a.[Org Type],
	community_school_data.town  = a.Town
FROM community_school_data
LEFT JOIN school_address AS a
ON community_school_data.school_code = a.[Org code]

/*
	Fill in Null vaules for address and org type
	Most of these schools were closed in the past year hence the missing information
	I will fill them in based on their school code as these can be used to identify public vs charter
	I will use town name from school website
*/

UPDATE community_school_data
SET org_type =
CASE school_code
	WHEN '00350013' THEN 'Public School'
	WHEN '00350382' THEN 'Public School'
	WHEN '00350445' THEN 'Public School'
	WHEN '00350485' THEN 'Public School'
	WHEN '00860005' THEN 'Public School'
	WHEN '00860010' THEN 'Public School'
	WHEN '00860020' THEN 'Public School'
	WHEN '00860305' THEN 'Public School'
	WHEN '01370075' THEN 'Public School'
	WHEN '01720020' THEN 'Public School'
	WHEN '02610305' THEN 'Public School'
	WHEN '02810330' THEN 'Public School'
	WHEN '02950020' THEN 'Public School'
	WHEN '02950025' THEN 'Public School'
	WHEN '03360310' THEN 'Public School'
	WHEN '04260205' THEN 'Charter School'
	WHEN '04310205' THEN 'Charter School'
ELSE
	org_type
END

UPDATE community_school_data
SET town =
    CASE school_code
	WHEN '00350013' THEN 'Allston'
	WHEN '00350382' THEN 'Jamaica Plain'
	WHEN '00350445' THEN 'Roslindale'
	WHEN '00350485' THEN 'Roxbury'
	WHEN '00860005' THEN 'Easthampton'
	WHEN '00860010' THEN 'Easthampton'
	WHEN '00860020' THEN 'Easthampton'
	WHEN '00860305' THEN 'Easthampton'
	WHEN '01370075' THEN 'Holyoke'
	WHEN '01720020' THEN 'Mashpee'
	WHEN '02610305' THEN 'Sandwich'
	WHEN '02810330' THEN 'Springfield'
	WHEN '02950020' THEN 'Tewksbury'
	WHEN '02950025' THEN 'Tewksbury'
	WHEN '03360310' THEN 'East Weymouth'
	WHEN '04260205' THEN 'Lawrence'
	WHEN '04310205' THEN 'Lawrence'
ELSE
	town
END

-- Next I will join county name and student enrollment from enroll_by_grade table

ALTER TABLE community_school_data
ADD
	county VARCHAR(20),
	number_students int

UPDATE community_school_data
SET
	community_school_data.county = e.COUNTY,
	community_school_data.number_students  = e.School_Total
FROM community_school_data
LEFT JOIN enroll_by_grade AS e
ON community_school_data.school_code = e.SCHOOL

/*
	I will now bring in school choice nnumbers into the database
	First I will remove unnecessary header rows and empty rows that were imported as well as extra header columns
*/

DELETE FROM school_choice
WHERE F3 IS NULL or F1 = 'LEA'

--Add columns to be inported into table
ALTER TABLE community_school_data
	ADD choice_in float,
		choice_out float

--bring in school choice info through left join
UPDATE community_school_data
SET
	community_school_data.choice_in = s.F3,
	community_school_data.choice_out  = s.F5
FROM community_school_data
LEFT JOIN school_choice AS s
ON community_school_data.district = s.F2

/*
	NULL values for school choice data is due to that charter schools are not part of school choice system
	These values will be replaced by zero
	The others are from differences in district names
*/

UPDATE community_school_data
	SET choice_in = 0, choice_out = 0
	WHERE org_type = 'Charter School'

--one school district didn't import correctly
UPDATE community_school_data
SET choice_in = 159.6, choice_out = 53.0
WHERE district = 'Dudley-Charlton Reg'

/*
	Bring in Median home values
	First I will add needed columns then I will populate them through a left join
*/

ALTER TABLE community_school_data
	ADD home_value int

UPDATE community_school_data
SET community_school_data.home_value = h.column2
FROM community_school_data
LEFT JOIN median_home_value AS h
ON community_school_data.town = h.column1

--I will first clean the NULL values here by replacing them with average of the district's home values
UPDATE csd
SET csd.home_value = temp.avg_value
FROM community_school_data csd
LEFT JOIN
(SELECT district, AVG(home_value) AS avg_value FROM community_school_data GROUP BY district) temp
ON csd.district = temp.district
WHERE csd.home_value IS NULL

--I willl use county averages to fill in the remaining NULL values
UPDATE csd
SET csd.home_value = temp.avg_value
FROM community_school_data csd
LEFT JOIN
(SELECT county, AVG(home_value) AS avg_value FROM community_school_data GROUP BY county) temp
ON csd.county = temp.county
WHERE csd.home_value IS NULL

--Now I will add on the number of colleges in each town

SELECT * fROM community_school_data

ALTER TABLE community_school_data
	ADD colleges int

UPDATE csd
SET csd.colleges = c.No_of_Colleges
FROM community_school_data csd
LEFT JOIN colleges AS c
ON csd.town = c.Town

--replace null values with 0
UPDATE community_school_data
SET colleges = 0
WHERE colleges IS NULL

--Bring in school total populations and district identifiers
SELECT * FROM school_pop ORDER BY org_code
SELECT * FROM community_school_data

ALTER TABLE community_school_data
ADD dist_code varchar(5),
	school_pop int

UPDATE csd
SET csd.dist_code = sp.org_code,
	csd.school_pop = sp.School_Total
FROM community_school_data csd
LEFT JOIN school_pop AS sp
ON  csd.school_code = sp.SCHOOL

--Bring in districts net school spending compliance percentage
