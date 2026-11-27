#!/usr/bin/env pwsh
# Downloads yieldCurve and uploads it to the treasury inbox. Runs on your PC.
# The ingest job moves it to raw files.
#
#   pwsh datasets/treasury/upload_treasury.ps1 -t free
#   pwsh datasets/treasury/upload_treasury.ps1 -t dev -Downgraded    # dev: the downgraded files in downgraded/

param(
    [Parameter(Mandatory)][string]$Target,
    [switch]$Downgraded
)

# The bundle names the profile and catalog, as it does for the tools. Run this
# from the repo's root folder.
$dataset = Split-Path $PSScriptRoot -Leaf
$config = databricks bundle validate -t $Target -o json | ConvertFrom-Json
$DatabricksProfile = $config.workspace.profile
$Catalog = $config.resources.catalogs.$dataset.name
if (-not $Catalog) { throw "No catalog for $dataset in target $Target" }

$table = "yieldCurve"
$ext   = "xml"
$url   = "https://home.treasury.gov/resource-center/data-chart-center/interest-rates/pages/xml?data=daily_treasury_yield_curve&field_tdr_date_value=$((Get-Date).Year)"
$inbox = "dbfs:/Volumes/$Catalog/raw/inbox"

# -Downgraded sends the downgraded files in downgraded/ instead, for dev. Each run gets a
# new inbox name, so the ingest job's file trigger sees a new file.
if ($Downgraded) {
    $run = Get-Date -Format HHmmss
    foreach ($f in Get-ChildItem "$PSScriptRoot/downgraded") {
        $name = "$($f.BaseName)_downgraded_$run$($f.Extension)"
        Write-Host "Uploading to $inbox/$name"
        databricks fs cp $f.FullName "$inbox/$name" --overwrite --profile $DatabricksProfile
        if ($LASTEXITCODE -ne 0) { throw "Upload failed: $name" }
    }
    Write-Host "Done."
    exit
}

$file  = Join-Path ([System.IO.Path]::GetTempPath()) "$table.$ext"

Write-Host "Downloading $table"
Invoke-WebRequest -Uri $url -OutFile $file

Write-Host "Uploading to $inbox/$table.$ext"
databricks fs cp $file "$inbox/$table.$ext" --overwrite --profile $DatabricksProfile
if ($LASTEXITCODE -ne 0) { throw "Upload failed: $table" }

Remove-Item $file
Write-Host "Done."
