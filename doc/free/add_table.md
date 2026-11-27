# Add a Table, Free

The Dev version: [add_table.md](../procedures/build_many_table_dataset/add_table.md).

1. Set **$d**, **$t** and **$f**: the dataset, the table, and its file,
   e.g. **powerPlay.json**. Name the file after the table.
2. In **conf/onboarding.yml**, copy the table block, and uncomment the
   copy. Change its **CHANGE_ME** lines.
3. Do the same in **conf/silver_transformations.yml**. For the casts, give
   Genie a sample file, and ask for the select lines.
4. Do the same with the commented line in the upload script. If the
   dataset will run on enterprise too, do the same in **fetch.yml**.
5. In **resources.yml**, copy the **# - YOUR_TABLE** line under
   **--names**, and the view's **# - file** block under **libraries**.
   Uncomment the copies.
6. Copy the view template into **tables/**. Change its **CHANGE_ME** line.
7. Copy the silver rules template into **conf/silver_expectations/**.
   Change its **CHANGE_ME** line: the key every record needs. The rules
   in **conf/bronze_expectations.yml** check every table, so each must
   name only columns the new table has.
8. Replace **YOUR_TABLE** and **YOUR_FILE** in the uncommented lines.
9. Search for leftovers outside comments. Nothing shows.
10. Check the plan. The ingest job and the pipeline show change. Nothing
   else changes.
11. Deploy.
12. Check the plan again. All show unchanged.
13. Run the upload script. It sends every file it lists, not just the new
    table's; repeats add no new versions. The ingest job runs, and skips
    the new table: its settings come next.
14. Run the apply settings job. Apply settings after the file lands: the
    pipeline fails on a new table with no files.
15. Run the ingest job by hand. The run is green.
16. Ask Genie: "How many records are in YOUR_CATALOG.silver.YOUR_TABLE_history?"
17. Ask Genie: "How many records are in YOUR_CATALOG.silver.YOUR_TABLE?"
18. End.

```
$d = "YOUR_DATASET"
$t = "YOUR_TABLE"
$f = "YOUR_FILE"
edit datasets/$d/conf/onboarding.yml
edit datasets/$d/conf/silver_transformations.yml
edit datasets/$d/upload_$d.ps1
edit datasets/$d/fetch.yml
edit datasets/$d/resources.yml
cp doc/templates/dataset/tables/silver.YOUR_TABLE.sql datasets/$d/tables/silver.$t.sql
edit datasets/$d/tables/silver.$t.sql
cp doc/templates/dataset/conf/silver_expectations/YOUR_TABLE.yml datasets/$d/conf/silver_expectations/$t.yml
edit datasets/$d/conf/silver_expectations/$t.yml
sed -i "/^\s*#/!{s/YOUR_TABLE/$t/g; s/YOUR_FILE/$f/g}" (grep -rlE "YOUR_TABLE|YOUR_FILE" datasets/$d)
grep -rnE "YOUR_|CHANGE_ME" datasets/$d | grep -vE ":[0-9]+:\s*(#|--)"
py tools/bundle_plan.py -t free
databricks bundle deploy -t free
py tools/bundle_plan.py -t free
& ./datasets/$d/upload_$d.ps1
databricks bundle run ${d}_apply_settings -t free
databricks bundle run ${d}_ingest -t free
```
