# Lesson

## Brief

### Preparation

- Create the conda environment based on the `elt-environment.yml` file. We will also be using google cloud (for which the account was created in the previous unit) in this lesson.

- Please refer to the [Environment Folder](https://github.com/su-ntu-ctp/5m-data-2.1-intro-big-data-eng/tree/main/environments) for the environment files. Please refer to the [installation.md](https://github.com/su-ntu-ctp/5m-data-2.1-intro-big-data-eng/blob/main/installation.md) for setup details.

### Lesson Overview

Imagine you work as a data engineer at a retail chain. Your analytics team needs to answer questions like:

- _Which store had the highest revenue last quarter?_
- _Which product category is growing the fastest?_
- _How has a store's location or name changed over the years?_

The raw transactional data exists — but it is one giant table with millions of rows, full of repeated values and no clean separation between facts (what happened) and dimensions (who, what, where). Running reports directly against it is slow, fragile, and hard to maintain.

A **data warehouse** solves this by reorganising raw data into a structure optimised for analytical queries. In this lesson you will learn how data warehouses are designed and then build one using two industry-standard tools:

- **dbt (data build tool)** — a framework for writing, testing, and documenting SQL transformations.
- **BigQuery** — Google's cloud data warehouse where the transformed data lives.

By the end of this lesson you will be able to:
1. Explain what a star schema is and why it makes analytical queries faster and more maintainable.
2. Understand what Slowly Changing Dimensions (SCDs) are and how snapshots preserve historical data.
3. Run a complete dbt project: seed → snapshot → run → test.
4. Build a new dbt project from scratch for an unfamiliar dataset.

---

## Part 1 - Data Warehouse and Dimensional Modeling

Conceptual knowledge, refer to slides.

---

## Part 2 - Hands-on with dbt and BigQuery

---

### Exercise 1: Exploring a Pre-built Star Schema for Iowa Liquor Sales

#### The Business Problem

The state of Iowa publishes every liquor sale made by licensed retailers. Each row in the raw dataset records one line item of one sale: which store sold it, which product was sold, when, and for how much.

This is fine for record-keeping, but terrible for analysis. To answer "which store had the highest revenue last year", you would have to scan tens of millions of rows, join on repeated store address strings, and hope the data is clean. Store #1234 might appear as "CASEY'S" in some rows and "Casey's General Store" in others — which is the right one?

The solution is to transform the raw data into a **star schema**:

- A central **fact table** (`fact_sales`) keeps only the measurable events: one row per sale, with numeric columns and foreign keys.
- **Dimension tables** (`dim_store`, `dim_item`) hold the descriptive attributes of each entity — cleaned, deduplicated, and tracked over time.

Analytical queries then join the small dimension tables to the fact table, which is far faster and easier to reason about.

In this exercise you will explore a **fully completed** dbt project that implements this star schema, understand how each piece connects, and then complete one intentionally unfinished part yourself.

> **Note:** The `liquor_sales` folder contains a `README.md` file — that is a dbt-generated file with additional reference links. All the setup steps you need are right here in this lesson.

---

#### Prerequisites

Before running the dbt project, make sure you have completed the following:

1. Set up your Google Cloud Platform account and confirm you can access the [console](https://console.cloud.google.com/). Copy your GCP project ID.
2. Install the gcloud CLI ([instructions](https://cloud.google.com/sdk/docs/install)) — you may have done this in Lesson 2.2 or during coaching.
3. Authenticate GCP by running: `gcloud auth application-default login`
4. In GCP IAM, grant yourself the **BigQuery Admin** role — you may have done this in Lesson 2.2.
5. Open `liquor_sales/profiles.yml` and replace `<YOUR-GCP-PROJECT-ID>` with your actual GCP project ID.

#### Setup

Open a terminal and navigate to the `liquor_sales` folder:

```bash
cd liquor_sales
conda activate elt
dbt debug
```

`dbt debug` checks that your project is correctly configured and that the connection to BigQuery works. Resolve any errors before continuing.

Next, load the seed CSV files:

```bash
dbt seed
```

---

#### Exploring the Project Structure

Before running anything, spend a few minutes reading the files. Understanding the structure first will make the commands much less mysterious.

```
liquor_sales/
├── dbt_project.yml          # Project-wide configuration (name, paths, model settings)
├── profiles.yml             # Connection details for BigQuery
├── models/
│   ├── sources.yml          # Declares the raw source table in BigQuery
│   ├── fact_sales.sql       # The central fact table
│   ├── schema.yml           # Tests for the fact table
│   └── star/
│       ├── dim_store.sql    # Store dimension table
│       ├── dim_item.sql     # Item dimension table (intentionally incomplete)
│       └── schema.yml       # Tests for the dimension tables
└── snapshots/
    └── store_snapshot.sql   # Type 2 SCD snapshot for store data
```

**The source** is declared in `models/sources.yml`. It points to the public BigQuery table `bigquery-public-data.iowa_liquor_sales.sales`. This is the raw data you are transforming — you do not own it, you only read from it. (Dataset address reference: [BigQuery Public](https://console.cloud.google.com/bigquery?ws=!1m4!1m3!3m2!1sbigquery-public-data!2siowa_liquor_sales))

**The fact table** (`models/fact_sales.sql`) selects the measurable columns from the source: sale amount, bottles sold, volume, and the foreign keys that link to the dimensions. It is intentionally lightweight — no descriptions, no aggregations.

**The dimension tables** live in the `star/` subdirectory. Open `dbt_project.yml` and look at the `models:` section — you will see that models inside `star/` are configured to materialise as physical tables (not views) and use a custom `star` schema in BigQuery. This is how dbt lets you organise models with different storage strategies.

---

#### Understanding Snapshots: Why Raw Data Isn't Enough

Here is a real problem: store #1234 was once located in one suburb, then moved to another. If `dim_store` just reads from the raw source table, you only ever see the most recent address. Any historical sales from the old address would now appear to come from the new address — corrupting your historical analysis.

The industry solution is called a **Type 2 Slowly Changing Dimension (SCD)**. Instead of overwriting old data, you add a new row each time an attribute changes, and track the time period each version was valid. This is what dbt **snapshots** do.

Open `snapshots/store_snapshot.sql` and read it. Notice:

- The `config` block at the top declares `unique_key='store_number'` (how dbt identifies which entity a row belongs to) and `strategy='timestamp'` (dbt detects changes when the `updated_at` value changes).
- The SQL inside extracts the distinct versions of each store's attributes from the raw data and calculates `start_at` and `end_at` timestamps for each version.
- dbt adds two system columns to every snapshot: `dbt_valid_from` and `dbt_valid_to`. When `dbt_valid_to` is `NULL`, that row is the **current** version.

`dim_store.sql` then reads from this snapshot with `WHERE dbt_valid_to IS NULL` — giving you one current row per store, correctly deduplicated.

---

#### Running the Project

Now that you understand what each file does, run the commands in order:

**1. Run snapshots first** — snapshots must exist before the dimension models that reference them.

The snapshot table is found in GCP console, snapshots

```bash
dbt snapshot
```

You may encounter an error if the `snapshots` dataset doesn't yet exist in your BigQuery. If so, create it manually:
1. In BigQuery, click **+ Add** → **Create Dataset**.
2. Enter `snapshots` as the dataset name and set the location to **US**.
3. Then re-run `dbt snapshot`.

**2. Build the models**

```bash
dbt run
```

This executes every `.sql` file under `models/` and materialises the results in BigQuery. After this you should see `fact_sales`, `dim_store`, and `dim_item` appear in your BigQuery dataset.

If you encounter issues, these commands can help reset state:

```bash
dbt clean
dbt debug
dbt run
```

---

#### Tests: Verifying Data Quality

Running transformations is only half the job. A data warehouse that silently produces wrong results is worse than one that fails loudly. dbt's built-in testing framework lets you assert data quality rules that run against the materialised tables.

Open `models/star/schema.yml`. You will see tests declared on `dim_store` and `dim_item`:

- `unique` — asserts that every value in that column appears only once. A dimension table with duplicate primary keys would cause incorrect join results downstream.
- `not_null` — asserts there are no missing values in the primary key.

Open `models/schema.yml` to see the tests on `fact_sales`. The `relationships` test is a **referential integrity** check: it verifies that every `store_number` in `fact_sales` exists in `dim_store`. This is the SQL equivalent of a foreign key constraint.

Run the tests:

```bash
dbt test
```

**You will see 1 failing test.** This is intentional. The `unique` test on `dim_item.item_number` fails because `dim_item.sql` currently reads directly from the raw source table — where the same product appears in thousands of sale rows. The fix is the same pattern already used for stores: create a snapshot to deduplicate items, then point `dim_item` at it.

---

#### Practice: Complete the `dim_item` Implementation

The failing test is your starting point. Your task is to fix `dim_item` by applying the same snapshot pattern that already works for `dim_store`, and then add a referential integrity test to prove that `fact_sales` correctly links to your fixed dimension.

**Why this matters:** In a real data warehouse, a `dim_item` that returns duplicates would make every downstream query that joins on `item_number` produce inflated or incorrect results — silently, until someone notices the numbers don't add up. The test you are writing is exactly what catches this class of bug in production.

---

**Step 1 — Create an item snapshot**

The snapshot will extract each distinct version of an item's attributes from the raw source, just like `store_snapshot.sql` does for stores.

Create a new file `snapshots/item_snapshot.sql` with the following content:

```sql
{% snapshot item_snapshot %}

{{
  config(
    target_schema='snapshots',
    unique_key='item_number',
    strategy='timestamp',
    updated_at='updated_at',
  )
}}

WITH
item AS (
    SELECT
        item_number,
        item_description,
        category,
        category_name,
        vendor_number,
        vendor_name,
        pack,
        bottle_volume_ml,
        date
    FROM
        {{ source('iowa_liquor_sales', 'sales') }}
),
grouped_data AS (
    SELECT DISTINCT
        item_number,
        item_description,
        category,
        category_name,
        vendor_number,
        vendor_name,
        pack,
        bottle_volume_ml,
        FIRST_VALUE(date) OVER (PARTITION BY item_number, item_description, category, category_name, vendor_number, vendor_name, pack, bottle_volume_ml ORDER BY date) start_date,
        LAST_VALUE(date) OVER (PARTITION BY item_number, item_description, category, category_name, vendor_number, vendor_name, pack, bottle_volume_ml ORDER BY date) end_date,
    FROM
        item
    QUALIFY RANK() OVER (PARTITION BY item_number, item_description, category, category_name, vendor_number, vendor_name, pack, bottle_volume_ml ORDER BY date) = 1
)
SELECT
    item_number,
    item_description,
    category,
    category_name,
    vendor_number,
    vendor_name,
    pack,
    bottle_volume_ml,
    CAST(start_date AS TIMESTAMP) start_at,
    CAST(LEAD(start_date) OVER (PARTITION BY item_number ORDER BY start_date) AS TIMESTAMP) as end_at,
    IF(LEAD(start_date) OVER (PARTITION BY item_number ORDER BY start_date) IS NULL, CURRENT_TIMESTAMP(), NULL) as updated_at,
FROM
    grouped_data
ORDER BY item_number, start_at, end_at

{% endsnapshot %}
```

Key things to notice (compare with `store_snapshot.sql`):
- `unique_key='item_number'` — dbt uses this to track changes to each item over time.
- `strategy='timestamp'` with `updated_at='updated_at'` — dbt detects a new version of a row when `updated_at` changes.
- `QUALIFY RANK() = 1` deduplicates rows so each unique combination of item attributes appears only once in the snapshot input.

Run the snapshot to materialise it in BigQuery:

```bash
dbt snapshot
```

You should see a new `snapshots.item_snapshot` table appear in your BigQuery dataset.

---

**Step 2 — Update `dim_item` to read from the snapshot**

Open `models/star/dim_item.sql`. It currently reads from the raw source:

```sql
SELECT DISTINCT
    item_number,
    ...
FROM {{ source('iowa_liquor_sales', 'sales') }}
```

Replace its contents with the following, mirroring how `dim_store.sql` reads from `store_snapshot`:

```sql
SELECT
    item_number,
    item_description,
    category,
    category_name,
    vendor_number,
    vendor_name,
    pack,
    bottle_volume_ml,
FROM {{ ref('item_snapshot') }}
WHERE CURRENT_TIMESTAMP > dbt_valid_from AND dbt_valid_to IS NULL
```

The `WHERE dbt_valid_to IS NULL` filter keeps only the **current** version of each item. Because the snapshot guarantees one row per unique item-attribute combination, this produces exactly one row per `item_number` — which is what the `unique` test requires.

Rebuild the models:

```bash
dbt run
```

---

**Step 3 — Add a foreign key test for `item_number` in `fact_sales`**

A clean `dim_item` is only half the picture. You also need to verify that every `item_number` in `fact_sales` actually exists in `dim_item`. Without this test, orphaned foreign keys — sale records that reference a product that isn't in the dimension — would silently break any downstream report that joins the two tables.

Open `models/schema.yml`. It already has a `relationships` test for `store_number`. Add the equivalent test for `item_number` so the full file looks like this:

```yaml
version: 2

models:
  - name: fact_sales
    description: "Fact table for item."
    columns:
      - name: invoice_and_item_number
        description: "The primary key for this table"
        tests:
          - unique
          - not_null
      - name: store_number
        description: "The foreign key to the store dimension table"
        tests:
          - relationships:
              arguments:
                to: ref('dim_store')
                field: store_number
      - name: item_number
        description: "The foreign key to the item dimension table"
        tests:
          - relationships:
              arguments:
                to: ref('dim_item')
                field: item_number
```

---

**Step 4 — Run the tests and confirm they all pass**

```bash
dbt test
```

All tests should now pass. You have:
- Fixed the root cause of the failing test (duplicates in `dim_item`) by sourcing from a snapshot instead of raw data.
- Added a referential integrity test that proves `fact_sales` correctly links to `dim_item`.

This combination — a clean dimension plus a tested foreign key — is the foundation of a trustworthy data warehouse.

---

### Exercise 2: Building a Star Schema for Austin Bikeshare from Scratch

#### The Business Problem

Austin, Texas operates a public bikeshare programme. Every bike trip is recorded: when it started, when it ended, which station it departed from, and which it arrived at. City planners and the programme operators want to answer questions like:

- _Which stations are most popular at peak hours?_
- _How has average trip duration changed over the years?_
- _Which start–end station pairs are most common?_

This time there is no pre-built project to guide you. You will design the schema and implement it yourself. This is the closer to what data engineering actually looks like on the job — you receive a raw dataset and a set of business questions, and you decide how to model it.

The dataset is available at [BigQuery Public](https://console.cloud.google.com/bigquery?ws=!1m4!1m3!3m2!1sbigquery-public-data!2saustin_bikeshare).

Browse it in BigQuery before you start. Look at the available tables and their columns. Ask yourself:
- What is the grain of the fact table — what does one row represent?
- Which columns are measures (numbers you want to aggregate)?
- Which columns are descriptive attributes that belong in a dimension?

---

> ⚠️ **Important:** Make sure you are inside the root `5m-data-2.5-data-warehouse` folder before running `dbt init`. Many learners accidentally run it inside the `liquor_sales` folder, which nests one dbt project inside another and causes confusing errors. Each dbt project must be in its own top-level folder.

> Make sure the `elt` environment is active: `conda activate elt`

---

#### Step 1 — Initialise a new dbt project

```bash
dbt init austin_bikeshare_demo
```

Answer the prompts as follows:
- **Database:** `bigquery`
- **Authentication method:** `oauth`
- **GCP project ID:** your project ID
- **Dataset name:** `austin_bikeshare_demo`
- **Threads / timeout:** accept the defaults
- **Location:** `US` (the public dataset lives in US)

Once complete you will see a confirmation message and a new `austin_bikeshare_demo/` folder.

![dbt init success message](assets/dbt_init_msg.PNG)

Remove example folder in models. It will cause error in dbt test

---

#### Step 2 — Set up profiles.yml

dbt stores connection details in a `profiles.yml` file. By default this lives in your home directory, not in the project folder. You need to copy the generated profile into the project so it is self-contained.

Find the generated profile:
- **Mac:** `~/.dbt/profiles.yml`
- **WSL:** `/home/<wsl_username>/.dbt/profiles.yml`

Copy the `austin_bikeshare_demo` profile block. Then create a new file `austin_bikeshare_demo/profiles.yml` and paste it in.

Navigate into the project and verify the connection:

```bash
cd austin_bikeshare_demo
conda activate elt
dbt debug
```

Resolve any errors before continuing.

---

#### Step 3 — Declare your source

Create `models/sources.yml` to tell dbt where the raw data lives. The Austin bikeshare public dataset is at `bigquery-public-data.austin_bikeshare`. You will need to decide which table(s) to use as your source — browse the dataset in BigQuery to find the right one.

A `sources.yml` follows this pattern (from the liquor sales project for reference):

```yaml
version: 2

sources:
  - name: <source_name>
    database: bigquery-public-data
    schema: <dataset_name>
    tables:
      - name: <table_name>
```

---

#### Step 4 — Design and implement your models

Using the liquor sales project as a reference, create:

**A fact model** (`models/fact_trips.sql` or similar):
- One row per trip.
- Include the foreign keys (station IDs) and numeric measures (duration, etc.).
- Reference the source with `{{ source(...) }}`.

```sql
SELECT
    trip_id,
    subscriber_type,
    bike_id,
    bike_type,
    start_time,
    start_station_id,
    start_station_name,
    end_station_id,
    end_station_name,
    duration_minutes
FROM {{ source('austin_bikeshare', 'bikeshare_trips') }}
```

**At least one dimension model** (`models/star/dim_station.sql` or similar):
- One row per station.
- Include the descriptive attributes: station name, location, etc.
- Reference the source with `{{ source(...) }}`.
```sql
SELECT DISTINCT
    station_id,
    name,
    status,
    location,
    address,
    alternate_name,
    city_asset_number,
    property_type,
    number_of_docks,
    power_type,
    footprint_length,
    footprint_width,
    notes,
    council_district,
    image,
    modified_date
FROM {{ source('austin_bikeshare', 'bikeshare_stations') }}
```
Think about whether you need a snapshot. Ask yourself: _could a station's name or location change over time?_ If yes, the same SCD pattern from Exercise 1 applies.

---

#### Step 5 — Add tests

Create `models/schema.yml` and `models/star/schema.yml` with:
- `unique` and `not_null` tests on every primary key.
- At least one `relationships` test checking a foreign key in the fact table against the dimension.

`models/schema.yml`
```yml
version: 2

models:
  - name: fact_trips
    description: "Fact table for bike trips."
    columns:
      - name: trip_id
        description: "The primary key for this table"
        tests:
          - unique
          - not_null
      - name: start_station_id
        description: "The foreign key to the start station dimension table"
        tests:
          - relationships:
              arguments:
                to: ref('dim_station')
                field: station_id
      - name: end_station_id
        description: "The foreign key to the end station dimension table"
        tests:
          - relationships:
              arguments:
                to: ref('dim_station')
                field: station_id
```       

`models/star/schema.yml`
```yml
version: 2

models:
  - name: dim_station
    description: "Dimension table for station."
    columns:
      - name: station_id
        description: "The primary key for this table"
        tests:
          - unique
          - not_null
```

Run the full pipeline:

```bash
dbt snapshot   # only if you created snapshots
dbt run
dbt test
```

All tests should pass.

---

#### Snowflake Schema (Extra)

A star schema has one level of dimensions. A **snowflake schema** normalises those dimensions further — for example, splitting `dim_station` into `dim_station` and `dim_neighbourhood`, where `dim_station` holds a foreign key to `dim_neighbourhood`. This reduces data redundancy at the cost of more joins.

Using the liquor sales project as inspiration:

> 1. Identify at least one dimension that could be normalised. For the bikeshare data, `dim_station` is a good candidate — stations belong to neighbourhoods or zip codes that could become their own dimension.
> 2. Create the normalised sub-dimension models in a `models/snowflake/` subdirectory.
> 3. Add `schema.yml` with `unique`, `not_null`, and `relationships` tests for all primary and foreign keys.
> 4. In `dbt_project.yml`, add a `snowflake` schema configuration that materialises these models as tables, mirroring the `star` config in the liquor sales project.
> 5. Run `dbt run` and `dbt test` and confirm everything passes.

---

## Additional dbt Commands (Optional)

| Command | What it does |
|---|---|
| `dbt build` | Runs `dbt run` and `dbt test` together in dependency order. [Reference](https://docs.getdbt.com/reference/commands/build) |
| `dbt docs generate` | Builds documentation from the descriptions in your `schema.yml` files. [Reference](https://docs.getdbt.com/reference/commands/cmd-docs#dbt-docs-generate) |
| `dbt docs serve` | Launches a local website showing all your generated documentation. [Reference](https://docs.getdbt.com/reference/commands/cmd-docs#dbt-docs-serve) |

Use `severity:` in a test config to control whether a failure is an error or a warning. [Reference](https://docs.getdbt.com/reference/resource-configs/severity)

Full command reference: [dbt commands](https://docs.getdbt.com/reference/dbt-commands)

---

### Possible Warning (Optional)

> ⚠️ **Warning!**
>
> **You may encounter a warning message like this:**
> ![dbt warning 1](assets/dbt_warning1.PNG)
>
> **or this:**
> ![dbt warning 2](assets/dbt_warning2.PNG)
>
> **To resolve it, uncomment the `arguments:` line in `models/schema.yml` under `fact_sales.sql`.**
>
> ![dbt warning solution](assets/dbt_solution_warning.PNG)
>
> Reference: https://docs.getdbt.com/reference/deprecations#missingargumentspropertyingenerictestdeprecation
