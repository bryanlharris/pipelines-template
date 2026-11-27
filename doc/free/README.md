# Set Up Free

Free is only for practice at home. It uses default storage, has no prefix,
and holds only public data.

Deploys every dataset to a Free Edition workspace, and loads its files. Free
can't create catalogs through the bundle, so you make each one with SQL,
then bind it. Free Edition has a daily serverless limit: when a run fails
with RESOURCE_EXHAUSTED, wait.

## Prerequisites

1. [setup.md](../procedures/setup.md): set up the computer and the CLI

## Steps

1. Make a token in your workspace: Settings, Developer, Access tokens
   ([how](https://docs.databricks.com/aws/en/dev-tools/auth/pat)).
2. Add the free profile to the config file, with your host and token.
3. Check the profile. It prints your user.
4. Copy the free targets template into **targets/**, unless you have it.
5. Uncomment **free**. If a dataset has a **genie.yml**, change its
   **CHANGE_ME** line to the SQL warehouse's id.
6. List the catalogs the bundle needs. It prints one name per dataset.
7. Create each catalog in the SQL editor. They can take a minute to show.
8. Bind each one, so the bundle takes it over.
9. Check the plan. All show create, but the catalogs show change. A catalog
   that shows create didn't bind.
10. Deploy. If the ingest job fails with **No volume is defined**, wait a few
    minutes, and deploy again.
11. Check the plan again. All show unchanged.
12. Run govern_catalogs. It limits each catalog to this workspace, and turns
    on data quality monitoring. Classification shows failed: free doesn't
    support it.
13. For each dataset, run the apply settings job. Do this before the files
    land, so each ingest run has its settings. Free runs one or two jobs at
    a time; the rest wait in a queue.
14. For each dataset, run its upload script. Its ingest job starts when the
    files land. A file that lands in the first minute after the deploy
    doesn't start it; then run the ingest job by hand.
15. End.

```
edit ~/.databrickscfg
databricks current-user me --profile free
cp doc/templates/target/targets.free.local.yml targets/
edit targets/targets.free.local.yml
$catalogs = (databricks bundle validate -t free -o json | ConvertFrom-Json).resources.catalogs.PSObject.Properties
$catalogs.Value.name
CREATE CATALOG YOUR_CATALOG
foreach ($c in $catalogs) { databricks bundle deployment bind $c.Name $c.Value.name -t free --auto-approve }
py tools/bundle_plan.py -t free
databricks bundle deploy -t free
py tools/bundle_plan.py -t free
./tools/govern_catalogs.ps1 -t free
databricks bundle run YOUR_DATASET_apply_settings -t free
& ./datasets/YOUR_DATASET/upload_YOUR_DATASET.ps1
databricks bundle run YOUR_DATASET_ingest -t free
```

```
[free]
host  = https://foobar-free.cloud.databricks.com
token = YOUR_TOKEN

[__settings__]
default_profile = free
```

Next: [add_dataset.md](add_dataset.md), then [add_table.md](add_table.md). To
learn the catalog step alone, see [add_catalog.md](add_catalog.md).
