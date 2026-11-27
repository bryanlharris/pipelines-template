← [add_bronze_settings.md](add_bronze_settings.md) | [add_silver_scd2.md](add_silver_scd2.md) →

# Add the Pipeline

The pipeline loads files into bronze and silver.

1. Add the pipeline template to the end of **resources.yml**.
2. Read the ingest tasks template into the ingest job, after the router
   task. Go to the router's last line, **YOUR_TABLE**, and add the
   template's lines below it.
   - Template is here: **doc/templates/bootcamp/pipeline/ingest_tasks.yml**
   - In vim: type **:r** then paste the template's path, then **Enter**
   - In VS Code: open the template, press **Ctrl+A** and **Ctrl+C**. Go back
     to **resources.yml**, click the very start of the next line, and
     press **Ctrl+V**.
   - Then replace **YOUR_DATASET** in **resources.yml**.
3. Check the plan. One pipeline shows create, and the ingest job change.
4. Deploy.
5. Check the plan again. All show unchanged.
6. Open the ingest job in Jobs & Pipelines. Its tasks now run **router**,
   **any_moved**, **pipeline**, in a chain.
7. Upload a file. The ingest job runs the router, then the pipeline.
8. Open the pipeline's latest update. Its graph shows the bronze table.
9. Ask Genie how many records the bronze table has.

```
cat doc/templates/bootcamp/pipeline/resources.yml >> datasets/YOUR_DATASET/resources.yml
edit datasets/YOUR_DATASET/resources.yml
py tools/bundle_plan.py -t YOUR_TARGET
databricks bundle deploy -t YOUR_TARGET
py tools/bundle_plan.py -t YOUR_TARGET
./datasets/YOUR_DATASET/upload_YOUR_DATASET.ps1 -t YOUR_TARGET
Genie → How many records in YOUR_DATASET.bronze.YOUR_TABLE?
```

---

← [add_bronze_settings.md](add_bronze_settings.md) | [add_silver_scd2.md](add_silver_scd2.md) →
