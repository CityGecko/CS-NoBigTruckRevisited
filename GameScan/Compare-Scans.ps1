<#
.SYNOPSIS
    Vergleicht zwei mit Scan-Game.ps1 erzeugte Scans (Baseline vor einem Spiel-Update gegen den Stand danach).

.DESCRIPTION
    Schreibt einen Bericht (Konsole + compare_report.txt im neuen Scan-Ordner) mit:
      - Zusammenfassung: FEHLT/PRUEFEN-Zeilen im neuen Stand (das sind die Stellen, an denen NBT brechen kann)
      - Zeilenunterschieden in den Inventardateien 00..05
      - geaenderten Typen im dekompilierten Quelltext und IL (src_changes.patch / il_changes.patch, benoetigt git)

.EXAMPLE
    .\Compare-Scans.ps1 -Old '..\GameBaseline\1.21.1-f9_2026-10-14\scan' -New '..\GameBaseline\1.22.0_2026-11-24\scan'
#>
param(
    [Parameter(Mandatory = $true)][string]$Old,
    [Parameter(Mandatory = $true)][string]$New,
    [string]$ReportFile
)

$ErrorActionPreference = 'Stop'
foreach ($d in $Old, $New) { if (-not (Test-Path (Join-Path $d '00_info.txt'))) { throw "Kein Scan-Ordner (00_info.txt fehlt): $d" } }
if (-not $ReportFile) { $ReportFile = Join-Path $New 'compare_report.txt' }

$summary = New-Object System.Collections.Generic.List[string]
$body = New-Object System.Collections.Generic.List[string]

function Get-LineDiff([string]$name, [string[]]$ignore) {
    $oldLines = @(); $newLines = @()
    if (Test-Path (Join-Path $Old $name)) { $oldLines = @(Get-Content (Join-Path $Old $name)) }
    if (Test-Path (Join-Path $New $name)) { $newLines = @(Get-Content (Join-Path $New $name)) }
    foreach ($p in $ignore) { $oldLines = @($oldLines | Where-Object { $_ -notmatch $p }); $newLines = @($newLines | Where-Object { $_ -notmatch $p }) }
    $oldSet = New-Object 'System.Collections.Generic.HashSet[string]'; foreach ($l in $oldLines) { [void]$oldSet.Add($l) }
    $newSet = New-Object 'System.Collections.Generic.HashSet[string]'; foreach ($l in $newLines) { [void]$newSet.Add($l) }
    return @{
        Removed = @($oldLines | Where-Object { -not $newSet.Contains($_) })
        Added   = @($newLines | Where-Object { -not $oldSet.Contains($_) })
    }
}

function Add-Section([string]$title, [string]$name, [string[]]$ignore = @()) {
    $body.Add(''); $body.Add("=== $title ($name) ===")
    $d = Get-LineDiff $name $ignore
    if ($d.Removed.Count -eq 0 -and $d.Added.Count -eq 0) { $body.Add('Keine Unterschiede.'); return $d }
    foreach ($l in $d.Removed) { $body.Add('- ' + $l) }
    foreach ($l in $d.Added) { $body.Add('+ ' + $l) }
    $body.Add(('({0} Zeilen entfernt/geaendert, {1} Zeilen neu/geaendert)' -f $d.Removed.Count, $d.Added.Count))
    return $d
}

$dInfo = Add-Section 'Spielversion / DLL-Hashes' '00_info.txt' @('^Scan-Zeitpunkt', '^AssemblyDir')
$dEnum = Add-Section 'Enums und Konstanten' '02_enums_consts.txt'
$dSig = Add-Section 'Member-Signaturen' '03_signatures.txt'
$dDep = Add-Section 'NBT-Abhaengigkeiten' '04_nbt_dependencies.txt'
$dPat = Add-Section 'Harmony-Ziele im IL' '05_patch_targets.txt'

# ---------------------------------------------------------------- Quelltext-/IL-Diff
$git = Get-Command git -ErrorAction SilentlyContinue
$changedCounts = @{}
foreach ($sub in @(@('src', '*.cs.txt', 'Dekompilierter Quelltext'), @('il', '*.il.txt', 'IL der gepatchten Methoden'))) {
    $dir = $sub[0]; $filter = $sub[1]
    $body.Add(''); $body.Add("=== $($sub[2]) ($dir) ===")
    $oldDir = Join-Path $Old $dir; $newDir = Join-Path $New $dir
    $oldFiles = @{}; $newFiles = @{}
    if (Test-Path $oldDir) { Get-ChildItem $oldDir -Filter $filter | ForEach-Object { $oldFiles[$_.Name] = $_.FullName } }
    if (Test-Path $newDir) { Get-ChildItem $newDir -Filter $filter | ForEach-Object { $newFiles[$_.Name] = $_.FullName } }
    $removed = @($oldFiles.Keys | Where-Object { -not $newFiles.ContainsKey($_) } | Sort-Object)
    $added = @($newFiles.Keys | Where-Object { -not $oldFiles.ContainsKey($_) } | Sort-Object)
    $changed = @($newFiles.Keys | Where-Object { $oldFiles.ContainsKey($_) -and ((Get-FileHash $oldFiles[$_]).Hash -ne (Get-FileHash $newFiles[$_]).Hash) } | Sort-Object)
    $changedCounts[$dir] = $changed.Count
    foreach ($f in $removed) { $body.Add('- entfernt: ' + $f) }
    foreach ($f in $added) { $body.Add('+ neu    : ' + $f) }
    foreach ($f in $changed) { $body.Add('~ geaendert: ' + $f) }
    if ($changed.Count -gt 0 -and $git) {
        $patch = Join-Path $New "$($dir)_changes.patch"
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { & $git.Source diff --no-index --no-color -U3 -- $oldDir $newDir 2>$null | Set-Content -Path $patch -Encoding UTF8 }
        finally { $ErrorActionPreference = $prev }
        $body.Add("Vollstaendiger Diff: $patch")
    }
    if ($removed.Count -eq 0 -and $added.Count -eq 0 -and $changed.Count -eq 0) { $body.Add('Keine Unterschiede.') }
}

# ---------------------------------------------------------------- Zusammenfassung
$newProblems = @()
foreach ($f in '04_nbt_dependencies.txt', '05_patch_targets.txt') {
    $p = Join-Path $New $f
    if (Test-Path $p) { $newProblems += @(Get-Content $p | Where-Object { $_ -match '^(FEHLT|PRUEFEN)' }) }
}
$newHints = @()
$p = Join-Path $New '04_nbt_dependencies.txt'
if (Test-Path $p) { $newHints = @(Get-Content $p | Where-Object { $_ -like 'HINWEIS*' }) }
$enumRelevant = @($dEnum.Added + $dEnum.Removed | Where-Object { $_ -match '^(ItemClass\.(Service|SubService|Level)|TransferManager\.TransferReason|DistrictPolicies\.(Specialization|Policies))\b' })

$summary.Add('ZUSAMMENFASSUNG')
$summary.Add('---------------')
$summary.Add('Alt : ' + (Get-Content (Join-Path $Old '00_info.txt') | Where-Object { $_ -like 'Spielversion*' } | Select-Object -First 1))
$summary.Add('Neu : ' + (Get-Content (Join-Path $New '00_info.txt') | Where-Object { $_ -like 'Spielversion*' } | Select-Object -First 1))
$summary.Add(('FEHLT/PRUEFEN im neuen Stand: {0}' -f $newProblems.Count))
foreach ($l in $newProblems) { $summary.Add('   ! ' + $l) }
$summary.Add(('Hinweise im neuen Stand: {0}' -f $newHints.Count))
foreach ($l in $newHints) { $summary.Add('   ' + $l) }
$summary.Add(('Geaenderte Zeilen bei Abhaengigkeiten: {0}, bei Harmony-Zielen: {1}' -f ($dDep.Removed.Count + $dDep.Added.Count), ($dPat.Removed.Count + $dPat.Added.Count)))
$summary.Add(('Enum-Aenderungen bei Service/SubService/Level/TransferReason/Bezirks-Spezialisierung: {0}' -f $enumRelevant.Count))
foreach ($l in $enumRelevant | Select-Object -First 30) { $summary.Add('   ' + $l) }
$summary.Add(('Geaenderte Dateien: src {0}, il {1}' -f $changedCounts['src'], $changedCounts['il']))
$summary.Add('')
$summary.Add('Reihenfolge fuer die Pruefung: 1) FEHLT/PRUEFEN (Mod bricht oder Transpiler ersetzt still nichts)')
$summary.Add('2) geaenderte IL der Harmony-Ziele (il_changes.patch: Argument-/Lokal-Indizes)  3) neue Gewerbe-SubServices/TransferReasons/Bezirks-Spezialisierungen (z. B. Wall-to-Wall)')
$summary.Add('4) danach im Spiel: output_log.txt auf "[NoBigTruck] ... Success patched!" und "Patch Success" pruefen')

$all = @($summary) + @($body)
$all | Set-Content -Path $ReportFile -Encoding UTF8
$all | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host "Bericht gespeichert: $ReportFile"
$global:LASTEXITCODE = 0   # git diff liefert bei Unterschieden Exit-Code 1 - das ist hier kein Fehler
