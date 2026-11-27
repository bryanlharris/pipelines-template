# Start a Repo

Makes your own repo from this one. Everyone else then clones it and works
on branches: [targets/dev_team.md](targets/dev_team.md).

This repo is upstream. Your repo pulls from it to get fixes.

## Pick One

- **Team repo:** several datasets. **YOUR_REPO** is e.g. **team-pipelines**.
  The bundle takes the team's name.
- **Dataset repo:** one dataset. **YOUR_REPO** is e.g.
  **treasury-pipelines**. The bundle takes the dataset's name.

## Prerequisites

1. [setup.md](setup.md): set up the computer and the CLI
2. An empty repo on GitHub, with no README, named **YOUR_REPO**, e.g.
   **team-pipelines** or **treasury-pipelines**

## Steps

1. Clone this repo into a folder named **YOUR_REPO**, e.g.
   **team-pipelines** or **treasury-pipelines**.
2. Rename the remote to **upstream**, and add your repo as **origin**.
3. In **databricks.yml**, change the bundle's name, **YOUR_TEAM**, to the
   team or dataset name, e.g. **foobar**. The bundle name comes from this
   line, not from the repo name. It names the bundle's state folder. Don't
   change it after the first deploy: a new name means a destroy and a
   redeploy.
4. Copy the examples you want into **datasets/**: several for a team repo,
   one for a dataset repo. Or add your own later
   with [build_many_table_dataset.md](build_many_table_dataset.md). To
   copy them all, skip **examples/README.md**, so it doesn't overwrite
   **datasets/README.md**. Remove each **genie.yml**: add those after the
   first load, with [add_genie.md](add_genie.md).
5. Commit, and push to origin.
6. Later, to get upstream's fixes, pull from upstream.
7. Check the bundle's name in **databricks.yml**. A pull can set it back
   to **YOUR_TEAM**. Put your name back, or the plan shows create on
   everything.
8. Check the plan. Nothing shows create.
9. Commit, and push to origin. Everyone else gets the fixes with a plain
   pull.
10. End.

```
git clone YOUR_UPSTREAM_URL YOUR_REPO
cd YOUR_REPO
git remote rename origin upstream
git remote add origin YOUR_TEAM_REPO_URL
edit databricks.yml
cp -r examples/YOUR_DATASET datasets/
cp examples/* datasets/ -Recurse -Exclude README.md
rm datasets/*/genie.yml
git add -A
git commit -m "Start YOUR_REPO"
git push -u origin master
git pull upstream master
edit databricks.yml
py tools/bundle_plan.py -t dev
git commit -am "Keep the team's bundle name"
git push
```
