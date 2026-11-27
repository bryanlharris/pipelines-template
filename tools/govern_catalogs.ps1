#!/usr/bin/env pwsh
# Binds each of the bundle's catalogs to this workspace, isolates it, turns
# on data classification, and turns on data quality monitoring for silver
# and gold. The bundle can't do these yet.
# Safe to run again; it skips each step that is already done.
#
# It prints one line per catalog: what changed or failed, or "ok" when every
# step was already done. -v prints every step.
#
# -Schemas picks the schemas to monitor, instead of silver and gold. A named
# schema that doesn't exist is reported.
#
# On prod, -StagingWorkspace also binds each catalog read-only to staging, so
# staging's pipelines can read its raw.files. The lead's read grant comes
# from the catalog's grants in resources.yml.
#
#   ./tools/govern_catalogs.ps1 -t dev
#   ./tools/govern_catalogs.ps1 -t dev -v
#   ./tools/govern_catalogs.ps1 -t dev -Schemas bronze,silver,gold
#   ./tools/govern_catalogs.ps1 -t prod -StagingWorkspace YOUR_WORKSPACE_ID

param([Parameter(Mandatory)][string]$Target, [string]$StagingWorkspace, [string[]]$Schemas = @('silver', 'gold'))

# -Verbose is built in, because Mandatory makes this an advanced script.
$verbose = $VerbosePreference -eq 'Continue'

# pwsh -File passes -Schemas a,b as one string.
$Schemas = @($Schemas -split ',')

# One step. -v prints its text. A step that changed or failed also adds a
# note to the catalog's line: pass the note, or $true to reuse the text.
function Step($text, $note) {
    if ($verbose) { Write-Host "   $text" }
    if ($note -eq $true) { $note = $text }
    if ($note) { $notes.Add($note) }
}

$config = databricks bundle validate -t $Target -o json | ConvertFrom-Json
$dbProfile = $config.workspace.profile
$ws = (databricks metastores current -p $dbProfile -o json | ConvertFrom-Json).workspace_id
$wsHost = (databricks auth describe -p $dbProfile -o json | ConvertFrom-Json).details.host -replace "^https://", ""
$bind = @{ add = @(@{ workspace_id = $ws; binding_type = "BINDING_TYPE_READ_WRITE" }) } | ConvertTo-Json -Depth 3 -Compress
$catalogs = $config.resources.catalogs.PSObject.Properties.Value.name

foreach ($c in $catalogs) {
    $notes = [Collections.Generic.List[string]]::new()
    if ($verbose) { Write-Host "== $c" }

    # Bind first, so isolating can't lock you out.
    $bound = @(databricks workspace-bindings get-bindings catalog $c -p $dbProfile -o json | ConvertFrom-Json).workspace_id
    if ($bound -contains $ws) {
        Step "already bound to workspace $ws ($wsHost)"
    } else {
        databricks workspace-bindings update-bindings catalog $c --json $bind -p $dbProfile | Out-Null
        Step "bound to workspace $ws ($wsHost)" "bound"
    }
    if ($StagingWorkspace) {
        if ($bound -contains $StagingWorkspace) {
            Step "already readable from staging workspace $StagingWorkspace"
        } else {
            $ro = @{ add = @(@{ workspace_id = [long]$StagingWorkspace; binding_type = "BINDING_TYPE_READ_ONLY" }) } | ConvertTo-Json -Depth 3 -Compress
            databricks workspace-bindings update-bindings catalog $c --json $ro -p $dbProfile | Out-Null
            Step "readable from staging workspace $StagingWorkspace" $true
        }
        $bound += [long]$StagingWorkspace
    }
    $others = $bound | ? { $_ -ne $ws }
    if ($others -and $verbose) { Write-Host "   also bound to $($others -join ', ')" }

    $mode = (databricks catalogs get $c -p $dbProfile -o json | ConvertFrom-Json).isolation_mode
    if ($mode -eq "ISOLATED") {
        Step "already isolated"
    } else {
        databricks catalogs update $c --isolation-mode ISOLATED -p $dbProfile | Out-Null
        Step "isolated" $true
    }

    databricks data-classification get-catalog-config "catalogs/$c/config" -p $dbProfile 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Step "classification already on"
    } else {
        databricks data-classification create-catalog-config "catalogs/$c" -p $dbProfile 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Step "classification on" $true }
        else { Step "classification failed, e.g. not supported on free" $true }
    }

    # Data quality monitoring watches the schemas for stale or odd data.
    foreach ($s in $Schemas) {
        $id = (databricks schemas get "$c.$s" -p $dbProfile -o json 2>$null | ConvertFrom-Json).schema_id
        if (-not $id) {
            if ($PSBoundParameters.ContainsKey('Schemas')) { Step "no schema $s" $true }
            continue
        }
        databricks data-quality get-monitor schema $id -p $dbProfile 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Step "$s monitoring already on"
        } else {
            $monitor = @{ object_type = "schema"; object_id = $id; anomaly_detection_config = @{} } | ConvertTo-Json -Compress
            databricks data-quality create-monitor --json $monitor -p $dbProfile 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Step "$s monitoring on" $true }
            else { Step "$s monitoring failed, e.g. off in the workspace's Previews" $true }
        }
    }

    if (-not $verbose) { Write-Host "${c}: $(if ($notes.Count) { $notes -join '; ' } else { 'ok' })" }
}
