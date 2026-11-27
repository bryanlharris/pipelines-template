# Add a Catalog, Free

The Dev version: [add_catalog.md](../procedures/bootcamp/add_catalog.md).

Free can't create a catalog through the bundle. So you make it with
SQL, then bind it: the bundle takes over the catalog that already exists.

| Target | Prefix | Catalog      |
|--------|--------|--------------|
| free   | none   | YOUR_CATALOG |

1. Make the dataset's folder.
2. Copy the catalog template into it.
3. Replace **YOUR_DATASET**.
4. Change the **CHANGE_ME** lines. For the catalog's comment, give Genie
   the About link and ask for a draft.
5. Create the catalog in the SQL editor.
6. Bind it, so the bundle takes it over.
7. Check the plan. The catalog must show change, to add the comment.
   If it shows create, the bind failed.
8. Deploy.
9. Check the plan again. The catalog shows unchanged.
10. Look at the catalog. It shows its comment.

```
mkdir datasets/YOUR_DATASET/
cp doc/templates/bootcamp/catalog/resources.yml datasets/YOUR_DATASET/
edit datasets/YOUR_DATASET/resources.yml
CREATE CATALOG YOUR_DATASET
databricks bundle deployment bind YOUR_DATASET YOUR_DATASET -t free --auto-approve
py tools/bundle_plan.py -t free
databricks bundle deploy -t free
py tools/bundle_plan.py -t free
databricks catalogs get YOUR_DATASET -p free
```
