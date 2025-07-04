/*--
• Database, schema, warehouse, and stage creation
--*/
DROP ROLE cortex_user_role;


USE ROLE SECURITYADMIN;

CREATE ROLE cortex_user_role;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE cortex_user_role;

-- TODO: Replace <your_user> with your username
GRANT ROLE cortex_user_role TO USER ANALYTICSWITHANAND ;

USE ROLE sysadmin;

-- Create demo database
CREATE OR REPLACE DATABASE cortex_analyst_demo;

-- Create schema
CREATE OR REPLACE SCHEMA cortex_analyst_demo.revenue_timeseries;

-- Create warehouse
CREATE OR REPLACE WAREHOUSE cortex_analyst_wh
    WAREHOUSE_SIZE = 'large'
    WAREHOUSE_TYPE = 'standard'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
COMMENT = 'Warehouse for Cortex Analyst demo';

GRANT USAGE ON WAREHOUSE cortex_analyst_wh TO ROLE cortex_user_role;
GRANT OPERATE ON WAREHOUSE cortex_analyst_wh TO ROLE cortex_user_role;

GRANT OWNERSHIP ON SCHEMA cortex_analyst_demo.revenue_timeseries TO ROLE cortex_user_role;
GRANT OWNERSHIP ON DATABASE cortex_analyst_demo TO ROLE cortex_user_role;


USE ROLE cortex_user_role;

-- Use the created warehouse
USE WAREHOUSE cortex_analyst_wh;

USE DATABASE cortex_analyst_demo;
USE SCHEMA cortex_analyst_demo.revenue_timeseries;

-- Create stage for raw data
CREATE OR REPLACE STAGE raw_data DIRECTORY = (ENABLE = TRUE);

/*--
• Fact and Dimension Table Creation
--*/

-- Fact table: daily_revenue
CREATE OR REPLACE TABLE cortex_analyst_demo.revenue_timeseries.daily_revenue (
    date DATE,
    revenue FLOAT,
    cogs FLOAT,
    forecasted_revenue FLOAT,
    product_id INT,
    region_id INT
);

-- Dimension table: product_dim
CREATE OR REPLACE TABLE cortex_analyst_demo.revenue_timeseries.product_dim (
    product_id INT,
    product_line VARCHAR(16777216)
);

-- Dimension table: region_dim
CREATE OR REPLACE TABLE cortex_analyst_demo.revenue_timeseries.region_dim (
    region_id INT,
    sales_region VARCHAR(16777216),
    state VARCHAR(16777216)
);



/*--
• looad data into tables
--*/

USE ROLE CORTEX_USER_ROLE;
USE DATABASE CORTEX_ANALYST_DEMO;
USE SCHEMA CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES;
USE WAREHOUSE CORTEX_ANALYST_WH;

COPY INTO CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.DAILY_REVENUE
FROM @raw_data
FILES = ('daily_revenue.csv')
FILE_FORMAT = (
    TYPE=CSV,
    SKIP_HEADER=1,
    FIELD_DELIMITER=',',
    TRIM_SPACE=FALSE,
    FIELD_OPTIONALLY_ENCLOSED_BY=NONE,
    REPLACE_INVALID_CHARACTERS=TRUE,
    DATE_FORMAT=AUTO,
    TIME_FORMAT=AUTO,
    TIMESTAMP_FORMAT=AUTO
    EMPTY_FIELD_AS_NULL = FALSE
    error_on_column_count_mismatch=false
)

ON_ERROR=CONTINUE
FORCE = TRUE ;



COPY INTO CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.PRODUCT_DIM
FROM @raw_data
FILES = ('product.csv')
FILE_FORMAT = (
    TYPE=CSV,
    SKIP_HEADER=1,
    FIELD_DELIMITER=',',
    TRIM_SPACE=FALSE,
    FIELD_OPTIONALLY_ENCLOSED_BY=NONE,
    REPLACE_INVALID_CHARACTERS=TRUE,
    DATE_FORMAT=AUTO,
    TIME_FORMAT=AUTO,
    TIMESTAMP_FORMAT=AUTO
    EMPTY_FIELD_AS_NULL = FALSE
    error_on_column_count_mismatch=false
)

ON_ERROR=CONTINUE
FORCE = TRUE ;



COPY INTO CORTEX_ANALYST_DEMO.REVENUE_TIMESERIES.REGION_DIM
FROM @raw_data
FILES = ('region.csv')
FILE_FORMAT = (
    TYPE=CSV,
    SKIP_HEADER=1,
    FIELD_DELIMITER=',',
    TRIM_SPACE=FALSE,
    FIELD_OPTIONALLY_ENCLOSED_BY=NONE,
    REPLACE_INVALID_CHARACTERS=TRUE,
    DATE_FORMAT=AUTO,
    TIME_FORMAT=AUTO,
    TIMESTAMP_FORMAT=AUTO
    EMPTY_FIELD_AS_NULL = FALSE
    error_on_column_count_mismatch=false
)

ON_ERROR=CONTINUE
FORCE = TRUE 


USE DATABASE cortex_analyst_demo;
USE SCHEMA revenue_timeseries;

CREATE OR REPLACE CORTEX SEARCH SERVICE product_line_search_service
  ON product_dimension
  WAREHOUSE = cortex_analyst_wh
  TARGET_LAG = '1 hour'
  AS (
      SELECT DISTINCT product_line AS product_dimension FROM product_dim
  );
