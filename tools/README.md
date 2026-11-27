# Tools

Scripts you run from the repo's root folder.

- [bundle_plan.py](bundle_plan.py) and [bundle_plan.ps1](bundle_plan.ps1): show what a deploy would do. The same output, in Python or PowerShell.
- [govern_catalogs.ps1](govern_catalogs.ps1): binds each catalog to the workspace, isolates it, turns on data classification, and turns on data quality monitoring for silver and gold. Skips what's already done. Prints one row per catalog, with a column for each step: a check if it is on, a cross if it failed, a minus if there is no schema to watch.

## Usage

Run each from the repo's root folder. **YOUR_TARGET** is dev, staging or prod.

```
py tools/bundle_plan.py -t YOUR_TARGET
py tools/bundle_plan.py -t YOUR_TARGET -v
./tools/bundle_plan.ps1 -t YOUR_TARGET
./tools/bundle_plan.ps1 -t YOUR_TARGET -v
./tools/govern_catalogs.ps1 -t YOUR_TARGET
./tools/govern_catalogs.ps1 -t YOUR_TARGET -v
./tools/govern_catalogs.ps1 -t YOUR_TARGET -Schemas bronze,silver,gold
./tools/govern_catalogs.ps1 -t prod -StagingWorkspace YOUR_WORKSPACE_ID
```

- The tools use the bundle in your current folder. Check where you are.
- **-v** adds the bundle keys to the plan. For govern_catalogs, it prints every step.
- **-Schemas** picks the schemas to monitor, instead of silver and gold. A schema that doesn't exist is reported.
- **-StagingWorkspace** is for prod only. It lets staging read each catalog's raw.files.
