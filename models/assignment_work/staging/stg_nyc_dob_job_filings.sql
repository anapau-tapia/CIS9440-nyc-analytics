-- Clean and standardize 311 dob job apps data
-- One row per service request

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           job_filing_number,
           job_type,
           borough,
           house_no,
           street_name,
           zip,
           initial_cost,
           total_construction_floor_area,
           filing_date,
           first_permit_date,
       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS job_filing_number,

       -- Date/Time
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,

       -- Job details
       UPPER(TRIM(CAST(job_type AS STRING))) AS job_type,


       -- Location - standardized borough, just in case
       CASE
           WHEN UPPER(TRIM(borough)) IN ('Manhattan', 'New York County') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('Bronx', 'The Bronx') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('Brooklyn', 'Kings County') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('Queens', 'Queen', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('Staten Island', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       INTICAP(TRIM(CAST(house_no AS STRING) AS house_no,
       INTICAP(TRIM(CAST(street_name AS STRING) AS street_name,

       -- Location - clean zip code
       CASE
           WHEN UPPER(TRIM(CAST(zip AS String))) IN ('N/A', 'NA', '00000') THEN NULL 
           WHEN LENGTH(CAST(zip AS STRING)) = 5 THEN CAST(zip AS STRING)
           ELSE NULL
       END AS zip,

       -- Numerical & Financial fields
       SAFE_CAST(initial_cost AS NUMERIC) AS initial_cost,
       SAFE_CAST(total_construction_floor_area AS NUMERIC) AS total_construction_floor_area,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND filing_date IS NOT NULL
   AND borough IS NOT NULL
   AND CAST(filing_date AS DATE) >= DATE_SUB('2000-01-01')

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY filing_date DESC) = 1
)

SELECT * FROM cleaned
-- All should be part of this table after running: stg_nyc_job_filings





