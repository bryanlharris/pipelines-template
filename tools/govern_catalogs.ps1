#!/usr/bin/env pwsh
# Binds each of the bundle's catalogs to this workspace, isolates it, turns
# on data classification, and turns on data quality monitoring for silver
# and gold. The bundle can't do these yet.
# Safe to run again; it skips each step that is already done.
#
# It prints one row per catalog, with a column for each step: a check if it
# is on, a cross if it failed, a minus if there is no schema to watch. -v
# prints every step instead.
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

# One step. -v prints its text.
function Step($text) {
    if ($verbose) { Write-Host "   $text" }
}

$config = databricks bundle validate -t $Target -o json | ConvertFrom-Json
$dbProfile = $config.workspace.profile
$ws = (databricks metastores current -p $dbProfile -o json | ConvertFrom-Json).workspace_id
$wsHost = (databricks auth describe -p $dbProfile -o json | ConvertFrom-Json).details.host -replace "^https://", ""
$bind = @{ add = @(@{ workspace_id = $ws; binding_type = "BINDING_TYPE_READ_WRITE" }) } | ConvertTo-Json -Depth 3 -Compress
$catalogs = $config.resources.catalogs.PSObject.Properties.Value.name

# The table's marks. Built from code points, so the file's encoding doesn't
# matter. Each shows two characters wide, so a cell is padded to its header's
# width.
$on, $bad, $none = 0x2705, 0x274C, 0x2796 | % { [char]::ConvertFromUtf32($_) }
$cols = 'bound', 'isolated', 'classification', 'monitoring'
$w = [Math]::Max(7, ($catalogs | % Length | Measure-Object -Maximum).Maximum) + 7
if (-not $verbose) { Write-Host ("catalog".PadRight($w) + "   " + ($cols -join "   ")) }

foreach ($c in $catalogs) {
    $mark = @{ bound = $on; isolated = $on; classification = $on }
    $monitors = @()
    if ($verbose) { Write-Host "== $c" }

    # Bind first, so isolating can't lock you out.
    $bound = @(databricks workspace-bindings get-bindings catalog $c -p $dbProfile -o json | ConvertFrom-Json).workspace_id
    if ($bound -contains $ws) {
        Step "already bound to workspace $ws ($wsHost)"
    } else {
        databricks workspace-bindings update-bindings catalog $c --json $bind -p $dbProfile | Out-Null
        Step "bound to workspace $ws ($wsHost)"
    }
    if ($StagingWorkspace) {
        if ($bound -contains $StagingWorkspace) {
            Step "already readable from staging workspace $StagingWorkspace"
        } else {
            $ro = @{ add = @(@{ workspace_id = [long]$StagingWorkspace; binding_type = "BINDING_TYPE_READ_ONLY" }) } | ConvertTo-Json -Depth 3 -Compress
            databricks workspace-bindings update-bindings catalog $c --json $ro -p $dbProfile | Out-Null
            Step "readable from staging workspace $StagingWorkspace"
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
        Step "isolated"
    }

    databricks data-classification get-catalog-config "catalogs/$c/config" -p $dbProfile 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Step "classification already on"
    } else {
        databricks data-classification create-catalog-config "catalogs/$c" -p $dbProfile 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Step "classification on" }
        else { Step "classification failed, e.g. not supported on free"; $mark.classification = $bad }
    }

    # Data quality monitoring watches the schemas for stale or odd data.
    foreach ($s in $Schemas) {
        $id = (databricks schemas get "$c.$s" -p $dbProfile -o json 2>$null | ConvertFrom-Json).schema_id
        if (-not $id) {
            if ($PSBoundParameters.ContainsKey('Schemas')) { Step "no schema $s"; $monitors += $bad }
            continue
        }
        databricks data-quality get-monitor schema $id -p $dbProfile 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Step "$s monitoring already on"
            $monitors += $on
        } else {
            $monitor = @{ object_type = "schema"; object_id = $id; anomaly_detection_config = @{} } | ConvertTo-Json -Compress
            databricks data-quality create-monitor --json $monitor -p $dbProfile 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { Step "$s monitoring on"; $monitors += $on }
            else { Step "$s monitoring failed, e.g. off in the workspace's Previews"; $monitors += $bad }
        }
    }

    if (-not $verbose) {
        # No monitored schema exists: show the minus.
        $mark.monitoring = if ($monitors -contains $bad) { $bad } elseif ($monitors) { $on } else { $none }
        $line = $c.PadRight($w)
        foreach ($col in $cols) { $line += "   " + $mark[$col] + " " * ($col.Length - 2) }
        Write-Host $line
    }
}
if (-not $verbose) { Write-Host "`n$on on   $bad failed, -v says why   $none no schema" }
