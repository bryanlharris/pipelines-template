← [setup_pc.md](setup_pc.md) or [setup_mac.md](setup_mac.md) | [setup_genie.md](setup_genie.md) →

# Set Up the Databricks CLI

1. Add the dev, staging and prod profiles to the config file, each with
   its host.
2. Log in to each. Each time your browser opens to sign in.
3. Check each profile. It prints your user.

```
edit ~/.databrickscfg
databricks auth login --profile dev
databricks auth login --profile staging
databricks auth login --profile prod
databricks current-user me --profile dev
databricks current-user me --profile staging
databricks current-user me --profile prod
```

```
[dev]
host      = https://foobar-dev.cloud.databricks.com
auth_type = databricks-cli

[staging]
host      = https://foobar-staging.cloud.databricks.com
auth_type = databricks-cli

[prod]
host      = https://foobar-prod.cloud.databricks.com
auth_type = databricks-cli
```

---

← [setup_pc.md](setup_pc.md) or [setup_mac.md](setup_mac.md) | [setup_genie.md](setup_genie.md) →
