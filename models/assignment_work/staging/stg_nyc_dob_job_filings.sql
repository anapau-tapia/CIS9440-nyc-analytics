-- Clean and standardize NYC DOB Job Applications data
-- One row per job application

WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       * EXCEPT (
           job_s_no,
           job_type,
           job_status,
           job_status_descr_cp,
           borough,
           house_no,
           street_name,
           zis_code, -- or zip_code depending on exact column name
           initial_cost,
           total_construction_floor_area,
           filing_date,
           issuance_date
       ),

       -- Identifiers
       CAST(job_s_no AS STRING) AS job_number,

       -- Date/Time
       CAST(filing_date AS TIMESTAMP) AS filing_date,
       CAST(issuance_date AS TIMESTAMP) AS issuance_date,

       -- Job details
       UPPER(TRIM(CAST(job_type AS STRING))) AS job_type,
       UPPER(TRIM(CAST(job_status AS STRING))) AS job_status,
       INITCAP(TRIM(CAST(job_status_descr_cp AS STRING))) AS job_status_description,

       -- Location - standardized borough
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       INITCAP(TRIM(CAST(house_no AS STRING))) AS house_number,
       INITCAP(TRIM(CAST(street_name AS STRING))) AS street_name,

       -- Location - clean zip code (adjust column name if your source uses zip_code vs zis_code)
       CASE
           WHEN UPPER(TRIM(CAST(zip_code AS STRING))) IN ('N/A', 'NA', '00000') THEN NULL
           WHEN LENGTH(CAST(zip_code AS STRING)) = 5 THEN CAST(zip_code AS STRING)
           ELSE NULL
       END AS zip_code,

       -- Numerical & Financial fields (handling negative or zero values if needed)
       SAFE_CAST(initial_cost AS NUMERIC) AS initial_cost,
       SAFE_CAST(total_construction_floor_area AS NUMERIC) AS total_construction_floor_area,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters to remove bad records
   WHERE job_s_no IS NOT NULL
   AND filing_date IS NOT NULL
   AND borough IS NOT NULL
   -- Optional: Filter out data older than a reasonable window if needed
   AND CAST(filing_date AS DATE) >= DATE('2000-01-01')

   -- Deduplicate based on unique job identifier
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_s_no ORDER BY filing_date DESC) = 1
)

SELECT * FROM cleaned