#!/usr/bin/env pwsh
# Show what a bundle deploy would do, by real name.
#
# bundle plan lists resource keys (schemas.edsm_bronze); this prints the name
# each lands on (edsm.bronze), grouped by type, with the fields a change
# would touch. Catalogs, pipelines, jobs and Genie agents hang from their
# workspace, schemas from their catalog and volumes from their schema.
# -v adds the bundle keys. A Genie agent to create or change gets a warning
# for each table it names that doesn't exist yet.
# Read only: it runs bundle validate and plan, never deploy.
#
#   ./tools/bundle_plan.ps1 -t dev
#   ./tools/bundle_plan.ps1 -t dev -v

param([Parameter(Mandatory)][string]$Target)

# -Verbose is built in, because Mandatory makes this an advanced script.
$ShowKeys = $VerbosePreference -eq 'Continue'

# bundle plan's action names, shown as plainer words.
$Actions = @{ skip = 'unchanged'; update = 'change' }
$SummaryOrder = 'create', 'change', 'recreate', 'delete', 'unchanged'
# Schemas and volumes print in layer order: raw first, then the rest.
$Layers = @{ raw = 0; bronze = 1; silver = 2; gold = 3 }
$ActionWidth = 10

# Box lines and arrow on a console; plain ASCII when piped
$console = -not [Console]::IsOutputRedirected
if ($console) {
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
    $Mid, $Last, $Bar, $Arrow = '├──', '└──', '│  ', '→'
} else {
    $Mid, $Last, $Bar, $Arrow = '|--', '`--', '|  ', '->'
}

# Action colors on a console, unless NO_COLOR is set
$esc = [char]27
$red = "$esc[38;2;204;85;85m"
$Codes = @{
    delete = $red; recreate = $red
    create = "$esc[38;2;78;186;101m"
    change = "$esc[38;2;255;193;7m"
    unchanged = "$esc[2m"
}
$Color = $console -and -not $env:NO_COLOR

function Format-Paint($action, $text) {
    if ($Color -and $Codes[$action]) { "$($Codes[$action])$text$esc[0m" } else { $text }
}

function Get-First { $args | Where-Object { $_ } | Select-Object -First 1 }

# Sort by an ordinal string key, like Python's sorted().
function Sort-Ordinal($items, [scriptblock]$key = { $_ }) {
    $pairs = [Collections.Generic.List[object]]::new()
    foreach ($i in $items) { $pairs.Add([pscustomobject]@{ K = [string]($i | ForEach-Object $key); V = $i }) }
    $pairs.Sort([Comparison[object]]{ param($a, $b) [string]::CompareOrdinal($a.K, $b.K) })
    if ($pairs.Count) { $pairs.V }
}

function Get-Layer($name) {
    if ($Layers.ContainsKey($name)) { $Layers[$name] } else { $Layers.Count }
}

# Run a databricks bundle command and return its JSON output.
function Invoke-Bundle {
    $err = New-TemporaryFile
    $out = databricks bundle @args -o json 2>$err
    $msg = (Get-Content $err -Raw)
    Remove-Item $err
    if ($LASTEXITCODE) {
        [Console]::Error.WriteLine($(if ($msg) { $msg.Trim() } else { "$out" }))
        exit 1
    }
    ($out -join "`n") | ConvertFrom-Json -AsHashtable
}

# The resource as it will be (create, change) or as it is (delete, unchanged).
function Get-State($entry) {
    if ($null -ne $entry.new_state.value) { return $entry.new_state.value }
    if ($entry.remote_state) { $entry.remote_state } else { @{} }
}

function Get-Protected($config, $kind, $key) {
    if ($config.resources.$kind.$key.lifecycle.prevent_destroy) { 'prevent_destroy' } else { '' }
}

function ConvertTo-JsonText($value) { ConvertTo-Json -InputObject $value -Compress -Depth 20 }

# Fields a change would touch, skipping the ones plan marks unchanged.
function Get-Changes($entry) {
    if (-not $entry.changes) { return }
    foreach ($field in Sort-Ordinal @($entry.changes.Keys)) {
        $c = $entry.changes[$field]
        if ($c.action -eq 'skip') { continue }
        $old = if ($c.ContainsKey('old')) { $c.old } else { $c.remote }
        "${field}: $(ConvertTo-JsonText $old) $Arrow $(ConvertTo-JsonText $c.new)"
    }
}

# Tables a Genie agent names that don't exist yet. Genie refuses those, so
# the deploy would fail.
function Get-MissingTables($config, $space) {
    $raw = if ($space.serialized_space) { $space.serialized_space } else { '{}' }
    foreach ($t in ($raw | ConvertFrom-Json -AsHashtable).data_sources.tables) {
        $found = databricks tables exists $t.identifier -p $config.workspace.profile -o json 2>$null
        if ($LASTEXITCODE -or -not (($found -join "`n") | ConvertFrom-Json).table_exists) {
            Format-Paint 'delete' "missing table: $($t.identifier); run the pipeline first"
        }
    }
}

# One resource in the tree.
function New-Row($name, $action, $note, $key, $fields) {
    [pscustomobject]@{
        Name = $name; Action = $action; Note = $note; Key = $key
        Fields = [Collections.Generic.List[string]]::new([string[]]@($fields))
    }
}

# groups: {heading: rows}. Prints each heading, then its rows as branches.
# $width is the name column, the same for every section so the actions line up.
function Write-Tree($groups, $width) {
    foreach ($heading in $groups.Keys) {
        "  $heading"
        $rows = @($groups[$heading])
        for ($i = 0; $i -lt $rows.Count; $i++) {
            $row = $rows[$i]
            $isLast = $i -eq $rows.Count - 1
            $branch = if ($isLast) { $Last } else { $Mid }
            $flag = if ($row.Action -in 'delete', 'recreate') { '!' } else { ' ' }
            $action = Format-Paint $row.Action ($flag + $row.Action)
            $pad = ' ' * ($ActionWidth - $row.Action.Length)
            $key = if ($ShowKeys) { "   ($($row.Key))" } else { '' }
            "  $branch $($row.Name.PadRight($width)) $action$pad $($row.Note)$key".TrimEnd()
            $under = if ($isLast) { '   ' } else { $Bar }
            foreach ($f in $row.Fields) { "  $under     $f" }
        }
    }
}

if (-not (Get-Command databricks -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('databricks CLI not found on PATH')
    exit 1
}
$config = Invoke-Bundle validate -t $Target
$entries = (Invoke-Bundle plan -t $Target).plan

# Saved state but nothing in the bundle: the plan would delete it all.
if ($entries.Count -and -not $config.resources.Count) {
    [Console]::Error.WriteLine("No resources in this bundle, but the plan would delete $($entries.Count).`nWrong folder? Bundle $($config.bundle.name), target ${Target}.")
    exit 1
}

# Sort each resource into its section, and count the actions.
$counts = @{}
$workspaceRows = @{}
foreach ($kind in 'catalogs', 'pipelines', 'jobs', 'genie_spaces') {
    $workspaceRows[$kind] = [Collections.Generic.List[object]]::new()
}
$catalogs = @{}   # catalog name -> schema rows
$volumes = @{}    # /Volumes/<catalog>/<schema> -> volume rows
foreach ($fullKey in $entries.Keys) {
    $entry = $entries[$fullKey]
    $kind, $key = ($fullKey.Split('.', 3))[1, 2]   # resources.schemas.edsm_bronze
    $action = Get-First $Actions[$entry.action] $entry.action
    $counts[$action] = 1 + [int]$counts[$action]
    $s = Get-State $entry
    $note = Get-Protected $config $kind $key

    if ($workspaceRows.ContainsKey($kind)) {
        $row = New-Row (Get-First $s.name $s.title $key) $action $note $key @(Get-Changes $entry)
        if ($kind -eq 'genie_spaces' -and $action -in 'create', 'change', 'recreate') {
            foreach ($m in Get-MissingTables $config $s) { [void]$row.Fields.Add($m) }
        }
        $workspaceRows[$kind].Add($row)
    } else {
        $row = New-Row (Get-First $s.name $key) $action $note $key @(Get-Changes $entry)
        if ($kind -eq 'schemas') {
            $group, $groups = (Get-First $s.catalog_name '(unknown)'), $catalogs
        } else {
            $group, $groups = "/Volumes/$(Get-First $s.catalog_name '(unknown)')/$(Get-First $s.schema_name '(unknown)')", $volumes
        }
        if (-not $groups.ContainsKey($group)) { $groups[$group] = [Collections.Generic.List[object]]::new() }
        $groups[$group].Add($row)
    }
}

# Summary line: "Plan for dev: 2 create, 18 unchanged"
$order = $SummaryOrder + @(Sort-Ordinal @($counts.Keys | Where-Object { $_ -notin $SummaryOrder }))
$parts = foreach ($a in $order) { if ($counts.ContainsKey($a)) { Format-Paint $a "$($counts[$a]) $a" } }
"Plan for ${Target}: $(if ($parts) { $parts -join ', ' } else { 'nothing' })"

# Each section is {heading: rows}, headings and rows in print order.
$workspace = ('workspace ' + $config.workspace.profile).Trim()
function Get-WorkspaceGroup($kind) {
    $rows = $workspaceRows[$kind]
    if ($rows.Count) { @{ $workspace = @(Sort-Ordinal $rows { $_.Name }) } } else { @{} }
}

$schemaGroups = [ordered]@{}
foreach ($c in Sort-Ordinal @($catalogs.Keys)) {
    $schemaGroups[$c] = @(Sort-Ordinal $catalogs[$c] { '{0}{1}' -f (Get-Layer $_.Name), $_.Name })
}
$volumeGroups = [ordered]@{}
foreach ($p in Sort-Ordinal @($volumes.Keys) { '{0}{1}' -f (Get-Layer $_.Substring($_.LastIndexOf('/') + 1)), $_ }) {
    $volumeGroups[$p] = @(Sort-Ordinal $volumes[$p] { $_.Name })
}

$sections = [ordered]@{
    'Catalogs'     = Get-WorkspaceGroup 'catalogs'
    'Schemas'      = $schemaGroups
    'Volumes'      = $volumeGroups
    'Pipelines'    = Get-WorkspaceGroup 'pipelines'
    'Jobs'         = Get-WorkspaceGroup 'jobs'
    'Genie agents' = Get-WorkspaceGroup 'genie_spaces'
}

# The name column is as wide as the longest name in any section.
$width = 0
foreach ($section in $sections.Values) {
    foreach ($rows in $section.Values) {
        foreach ($r in $rows) { $width = [Math]::Max($width, $r.Name.Length) }
    }
}

foreach ($title in $sections.Keys) {
    if ($sections[$title].Count) {
        ''
        $title
        Write-Tree $sections[$title] $width
    }
}
