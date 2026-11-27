← none | none →

# Downgrade File

Strips a prod file to its bare shape for dev. The data goes. The format stays.

## Prod Steps

1. Download one data file to your laptop.
2. If not already, rename the file after the table, e.g. **YOUR_TABLE.csv**.
3. Delete every data record. Keep the header, the wrapper and the first record's structure.
4. Empty the values in the one record you keep. Leave the quotes, commas, tags and keys.
5. Check no real value is left.
6. Save the file in **datasets/YOUR_DATASET/downgraded/**, and commit it.
7. End.

```
Rename-Item YOUR_DOWNLOAD YOUR_TABLE.YOUR_EXTENSION
edit YOUR_TABLE.YOUR_EXTENSION
git add datasets/YOUR_DATASET/downgraded
git commit -m "YOUR_DATASET: downgraded YOUR_TABLE file"
```

## Dev Steps

1. Run the upload script with **-t dev** and **-Downgraded**.
2. Open the ingest job's latest run. Check: it's green. If it didn't start, run it by hand.
3. Ask Genie: "Show YOUR_CATALOG.silver.YOUR_TABLE." Check: one record, with empty values.
4. End.

```
./datasets/YOUR_DATASET/upload_YOUR_DATASET.ps1 -t dev -Downgraded
databricks bundle run YOUR_DATASET_ingest -t dev
```

← none | none →
