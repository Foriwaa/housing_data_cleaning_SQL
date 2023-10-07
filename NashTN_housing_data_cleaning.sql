-- show global variables like 'local_infile';
-- set global local_infile=true;
-- OPT_LOCAL_INFILE=1 (in connection tab)

LOAD DATA LOCAL INFILE '/Filepath/NashvilleHousingData.csv'
INTO TABLE Datasets.housing  -- load the csv data to my_table
FIELDS TERMINATED BY ','  -- field separator
ENCLOSED BY '"' -- fields that contain commas
LINES TERMINATED BY '\r\n'  -- line ending
IGNORE 1 ROWS;  -- ignore the header line 

/*

Cleaning Data in SQL Queries

*/
SELECT * FROM Datasets.housing;

--------------------------------------------------------------------------------------------------------------------------
-- Standardize Date Format
SELECT  
SUBSTRING_INDEX(SaleDate,"-",1) AS Day,
SUBSTRING_INDEX((SUBSTRING_INDEX(SaleDate,"-",2)),"-",-1) AS Month,
CONCAT("20",SUBSTRING_INDEX(SaleDate,"-",-1)) AS Year
FROM housing;


WITH FormatSaleDate AS (
SELECT SaleDate, Day ,
CASE
WHEN Month = "Jan" THEN "01"
WHEN Month = "Feb" THEN "02"
WHEN Month = "Mar" THEN "03"
WHEN Month = "Apr" THEN "04"
WHEN Month = "May" THEN "05"
WHEN Month = "Jun" THEN "06"
WHEN Month = "Jul" THEN "07"
WHEN Month = "Aug" THEN "08"
WHEN Month = "Sep" THEN "09"
WHEN Month = "Oct" THEN "10"
WHEN Month = "Nov" THEN "11"
WHEN Month = "Dec" THEN "12"
END AS MonthNum,
Year
FROM
(
SELECT  SaleDate,
SUBSTRING_INDEX(SaleDate,"-",1) AS Day,
SUBSTRING_INDEX((SUBSTRING_INDEX(SaleDate,"-",2)),"-",-1) AS Month,
CONCAT("20",SUBSTRING_INDEX(SaleDate,"-",-1)) AS Year
FROM housing
) AS DateTable
)
SELECT SaleDate,STR_TO_DATE((CONCAT(MonthNum,"-",Day,"-",Year)),'%m-%d-%Y') AS FormattedSaleDate
FROM FormatSaleDate;

--------------------------------------------------------------------------------------------------------------------------
-- Update SaleDate Format Very slow in MySQL Workbench better of cleaning in excel
WITH FormatSaleDate AS (
SELECT SaleDate, Day ,
CASE
WHEN Month = "Jan" THEN "01"
WHEN Month = "Feb" THEN "02"
WHEN Month = "Mar" THEN "03"
WHEN Month = "Apr" THEN "04"
WHEN Month = "May" THEN "05"
WHEN Month = "Jun" THEN "06"
WHEN Month = "Jul" THEN "07"
WHEN Month = "Aug" THEN "08"
WHEN Month = "Sep" THEN "09"
WHEN Month = "Oct" THEN "10"
WHEN Month = "Nov" THEN "11"
WHEN Month = "Dec" THEN "12"
END AS MonthNum,
Year
FROM
(
SELECT  SaleDate,
SUBSTRING_INDEX(SaleDate,"-",1) AS Day,
SUBSTRING_INDEX((SUBSTRING_INDEX(SaleDate,"-",2)),"-",-1) AS Month,
CONCAT("20",SUBSTRING_INDEX(SaleDate,"-",-1)) AS Year
FROM housing
) AS DateTable
)
UPDATE housing
JOIN FormatSaleDate
ON FormatSaleDate.SaleDate = housing.SaleDate
SET housing.SaleDate = STR_TO_DATE((CONCAT(MonthNum,"-",Day,"-",Year)),'%m-%d-%Y');

--------------------------------------------------------------------------------------------------------------------------

-- Populate Property Address data
SELECT *
FROM housing
WHERE PropertyAddress IS NULL;

-- Can use same parcelID with addresses as reference point to populate missing property address
-- same parcelID but unique rows
SELECT x.ParcelID, x.PropertyAddress, y.ParcelID, y.PropertyAddress,
IFNULL(x.PropertyAddress,y.PropertyAddress)
FROM housing AS x
JOIN housing AS y
ON x.ParcelID = y.ParcelID
AND x.UniqueID != y.UniqueID
WHERE x.PropertyAddress IS NULL;

-- Fill in missing PropertyAddress
UPDATE housing AS x
JOIN housing AS y
ON x.ParcelID = y.ParcelID
AND x.UniqueID != y.UniqueID
SET x.PropertyAddress = IFNULL(x.PropertyAddress,y.PropertyAddress)
WHERE x.PropertyAddress IS NULL;

--------------------------------------------------------------------------------------------------------------------------
-- Breaking out Address into Individual Columns (Address, City, State)

-- Split Property Address delimiter ', '
SELECT
SUBSTRING_INDEX(PropertyAddress,",",1) AS PropertyStreet,
SUBSTRING_INDEX(PropertyAddress,",",-1) AS PropertyCity
FROM housing;

-- Add new columns for PropertyAddress split into street and city
ALTER TABLE housing ADD COLUMN PropertyStreet VARCHAR(255) AFTER PropertyAddress;
ALTER TABLE housing ADD COLUMN PropertyCity VARCHAR(255) AFTER PropertyStreet;

UPDATE housing SET PropertyStreet = SUBSTRING_INDEX(PropertyAddress,",",1);
UPDATE housing SET PropertyCity = SUBSTRING_INDEX(PropertyAddress,",",-1);

-- Split Owner Address delimiter ','
SELECT
SUBSTRING_INDEX(OwnerAddress,",",1) AS OwnerStreet,
SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress,",",-2),",",1) AS OwnerCity,
SUBSTRING_INDEX(OwnerAddress,",",-1) AS OwnerState
FROM housing;

-- Add new columns for OwnerAddress split into street, city and state
ALTER TABLE housing ADD COLUMN OwnerStreet VARCHAR(255) AFTER OwnerAddress;
ALTER TABLE housing ADD COLUMN OwnerCity VARCHAR(255) AFTER OwnerStreet;
ALTER TABLE housing ADD COLUMN OwnerState VARCHAR(255) AFTER OwnerCity;

UPDATE housing SET OwnerStreet = SUBSTRING_INDEX(OwnerAddress,",",1);
UPDATE housing SET OwnerCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress,",",-2),",",1);
UPDATE housing SET OwnerState = SUBSTRING_INDEX(OwnerAddress,",",-1);

--------------------------------------------------------------------------------------------------------------------------
-- In "Sold as Vacant" field change Y,N to Yes and No to make consistent
SELECT Distinct SoldAsVacant, Count(*)
FROM housing
GROUP BY SoldAsVacant;

SELECT SoldAsVacant,CASE 
WHEN SoldAsVacant="Y" THEN "Yes"
WHEN SoldAsVacant="N" THEN "No"
ELSE SoldAsVacant
END
FROM housing;

UPDATE housing
SET SoldAsVacant = CASE 
WHEN SoldAsVacant="Y" THEN "Yes"
WHEN SoldAsVacant="N" THEN "No"
ELSE SoldAsVacant
END;

--------------------------------------------------------------------------------------------------------------------------
-- Identify Duplicates
WITH RowNumCTE AS(
SELECT *, 
ROW_NUMBER() OVER(
		PARTITION BY ParcelID,
					PropertyAddress,
                    SaleDate,
                    SalePrice,
                    LegalReference
        ORDER BY UniqueID
        ) AS row_num
FROM housing
)
SELECT * 
FROM RowNumCTE
WHERE row_num>1;

--------------------------------------------------------------------------------------------------------------------------
-- Delete Unused Columns
ALTER TABLE housing
DROP COLUMN OwnerAddress, 
DROP COLUMN PropertyAddress

