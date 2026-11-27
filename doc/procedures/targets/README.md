# Targets

## Overview

A target is a place to deploy: dev, staging or prod. Each target
usually maps to one workspace.

Configure via the **targets/** folder (git ignores \*.local.\*). The
templates are in **doc/templates/target/**. Copy and customize the one(s)
you want.

- **targets.team.local.yml**: dev, staging and prod, for a team at work.

## Development and Targets

Here is a basic idea of the workflow. Everyone can deploy to the dev target
side by side (notice the catalogs don't conflict). An elevated user makes
tags and deploys to the staging and prod targets. Again, notice the catalog
names.

```
(bundle name: team)
repo     branch/tag          target   catalog
team-pipelines
├─────── jim/add-fred     →  dev      dev_jim_treasury  (branch)
├─────── sue/fix-rules    →  dev      dev_sue_treasury  (branch)
├─────── bob/new-table    →  dev      dev_bob_treasury  (branch)
└─────── master                                         (branch)
         └─ staging_v0.01 →  staging  staging_treasury  (tag)
            └─ prod_v0.1  →  prod     treasury          (tag)
```

### Target Details

Dev, staging and prod keep each catalog in **s3://some-bucket/catalogs/**.
Prod gets files from the fetch job. Dev gets fake files. Staging's pipelines
read prod's **raw.files** volume, and staging's **raw.files** volume stays
empty.

| Target  | Prefix            | Who              | Table data     | Procedure                            |
|---------|-------------------|------------------|----------------|--------------------------------------|
| dev     | `dev_jim_`        | each person      | Fake           | [dev_team.md](dev_team.md)           |
| staging | `staging_`        | the team lead    | Private/Public | [staging_team.md](staging_team.md)   |
| prod    | none              | the lead, as sp  | Private/Public | [prod_team.md](prod_team.md)         |
