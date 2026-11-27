← none | [add_schemas_and_volumes.md](add_schemas_and_volumes.md) →

# Add a Catalog

The bundle creates the catalog itself.

Each target puts its prefix on the catalog's name, and names its bucket
in your targets file, **targets/targets.team.local.yml**. See
[dev_team.md](../targets/dev_team.md). The template's **targets:** section
adds the storage path on dev, staging and prod only.

| Target  | Prefix          | Catalog                   |
|---------|-----------------|---------------------------|
| dev     | `dev_jim_`      | dev_jim_YOUR_DATASET      |
| staging | `staging_`      | staging_YOUR_DATASET      |
| prod    | none            | YOUR_DATASET              |

1. Make the datasets/YOUR_DATASET folder.
2. Copy the catalog template into the folder.
3. Replace **YOUR_DATASET**.
4. Change the **CHANGE_ME** lines. For the catalog's comment, give Genie
   the About link and ask for a draft.
5. Check the plan. The catalog must show create.
6. Deploy.
7. Check the plan again. The catalog shows unchanged.
8. Look at the catalog. It shows its comment.

```
mkdir datasets/YOUR_DATASET/
cp doc/templates/bootcamp/catalog/resources.yml datasets/YOUR_DATASET/
edit datasets/YOUR_DATASET/resources.yml
py tools/bundle_plan.py -t YOUR_TARGET
databricks bundle deploy -t YOUR_TARGET
py tools/bundle_plan.py -t YOUR_TARGET
databricks catalogs get YOUR_CATALOG -p YOUR_TARGET
```

---

← none | [add_schemas_and_volumes.md](add_schemas_and_volumes.md) →
