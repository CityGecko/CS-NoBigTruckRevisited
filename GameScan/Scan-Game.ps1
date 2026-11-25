<#
.SYNOPSIS
    Scannt die Cities-Skylines-Assemblies und erzeugt ein diff-bares Inventar der Spiel-API, von der No Big Truck abhaengt.

.DESCRIPTION
    Aufgebaut wie GameScan\Scan-Game.ps1 von Advanced Vehicle Options, aber auf die NBT-Patchziele zugeschnitten.
    Dekompiliert einzelne Typen mit ilspycmd (nur lesend, das Spiel wird nicht veraendert) und schreibt nach -OutDir:
      00_info.txt              Spielversion, Save-Format, Hashes der DLLs
      02_enums_consts.txt      Enums aus ItemClass, TransferManager und DistrictPolicies (Service/SubService/Level/TransferReason/Spezialisierungen)
      03_signatures.txt        Member-Signaturen der fuer NBT relevanten Typen
      04_nbt_dependencies.txt  Checkliste: existieren die Spiel- und AVO-Member noch, auf die NBT per Reflection/Harmony zugreift?
      05_patch_targets.txt     IL-Pruefung der Harmony-Ziele: Signatur (Argument-Indizes!), lokale Variablen,
                               Anzahl der Aufrufe, die die Transpiler ersetzen. Wichtig: Findet ein Transpiler seinen
                               Aufruf nicht mehr, meldet Harmony trotzdem "Success patched!" - nur dieser Bericht zeigt das.
      il\*.il.txt              IL der gepatchten Methoden (fuer detaillierte Diffs)
      src\*.cs.txt             dekompilierter Quelltext der relevanten Typen

    Danach mit Compare-Scans.ps1 zwei Scans vergleichen (Baseline vor dem Spiel-Update gegen den Stand danach).

.PARAMETER OutDir
    Zielordner (wird angelegt, Inhalte werden ueberschrieben).

.PARAMETER AssemblyDir
    Ordner mit Assembly-CSharp.dll. Standard: Managed-Ordner der Steam-Installation.
    Kann auch auf ein archiviertes DLL-Set zeigen (z. B. GameBaseline\<Version>\dll), dann wird dieses gescannt.

.PARAMETER AvoDll
    AdvancedVehicleOptions.dll, gegen die die beiden AVO-Patches geprueft werden. Leer oder nicht vorhanden = AVO-Pruefung ueberspringen.

.EXAMPLE
    .\Scan-Game.ps1 -OutDir '..\GameBaseline\1.22.0_2026-11-24\scan'
#>
param(
    [Parameter(Mandatory = $true)][string]$OutDir,
    [string]$AssemblyDir = 'S:\Steam\steamapps\common\Cities_Skylines\Cities_Data\Managed',
    [string]$AvoDll = "$env:LOCALAPPDATA\Colossal Order\Cities_Skylines\Addons\Mods\AdvancedVehicleOptions\AdvancedVehicleOptions.dll"
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- Werkzeuge / Eingaben pruefen
$ilspy = $null
$cmd = Get-Command ilspycmd -ErrorAction SilentlyContinue
if ($cmd) { $ilspy = $cmd.Source }
else {
    foreach ($c in "$env:USERPROFILE\.dotnet\tools\ilspycmd.exe", "$env:USERPROFILE\.dotnet\tools\ilspycmd.cmd") {
        if (Test-Path $c) { $ilspy = $c; break }
    }
}
if (-not $ilspy) { throw 'ilspycmd nicht gefunden. Installieren mit: dotnet tool install -g ilspycmd' }

$acDll = Join-Path $AssemblyDir 'Assembly-CSharp.dll'
if (-not (Test-Path $acDll)) { throw "Nicht gefunden: $acDll" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$srcOut = Join-Path $OutDir 'src'
$ilOut = Join-Path $OutDir 'il'
foreach ($d in $srcOut, $ilOut) {
    if (Test-Path $d) { Remove-Item -Recurse -Force $d }
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

$tmp = Join-Path $env:TEMP ('nbt-scan-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

# Ein Typ -> Textdatei. $il = $true liefert IL statt C#.
function Invoke-DecompileType([string]$dll, [string]$type, [string]$out, [bool]$il) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # ilspycmd schreibt Hinweise nach stderr - das darf nicht abbrechen
    try {
        $refDir = Split-Path -Parent $dll
        $ilArgs = @('-t', $type, $dll, '-r', $refDir, '-r', $AssemblyDir)
        if ($il) { $ilArgs = @('-il') + $ilArgs }
        $text = & $ilspy @ilArgs 2>$null
    }
    finally { $ErrorActionPreference = $prev }
    $text = @($text)
    if ($text.Count -lt 3) { return $false }
    Set-Content -Path $out -Value $text -Encoding UTF8
    return $true
}

function Write-Lines([string]$name, $lines) {
    Set-Content -Path (Join-Path $OutDir $name) -Value $lines -Encoding UTF8
}

try {
    # ------------------------------------------------------------ Dekompilieren (nur die benoetigten Typen)
    $csTypes = 'BuildConfig', 'VehicleManager', 'CargoTruckAI', 'IndustrialBuildingAI', 'IndustrialExtractorAI', 'OutsideConnectionAI', 'WarehouseAI',
        'Vehicle', 'VehicleInfo', 'Building', 'BuildingInfo', 'BuildingManager', 'TransferManager', 'ItemClass', 'DistrictPolicies'
    $ilTypes = 'VehicleManager', 'CargoTruckAI', 'IndustrialBuildingAI', 'IndustrialExtractorAI', 'OutsideConnectionAI', 'WarehouseAI'
    $cs = @{}; $ilFiles = @{}
    foreach ($t in $csTypes) {
        Write-Host "Dekompiliere $t ..."
        $f = Join-Path $tmp "$t.cs"
        if (Invoke-DecompileType $acDll $t $f $false) { $cs[$t] = $f }
    }
    foreach ($t in $ilTypes) {
        Write-Host "IL $t ..."
        $f = Join-Path $tmp "$t.il"
        if (Invoke-DecompileType $acDll $t $f $true) { $ilFiles[$t] = $f }
    }
    if (-not $cs.ContainsKey('BuildConfig')) { throw 'Dekompilieren fehlgeschlagen (BuildConfig nicht lesbar).' }

    # ------------------------------------------------------------ 00_info
    $bc = [IO.File]::ReadAllText($cs['BuildConfig'])
    function Get-Const([string]$text, [string]$name) {
        if ($text -match ("(?:const|static)[^=;]*\b" + [regex]::Escape($name) + "\s*(?:=>|=)\s*([^;]+);")) { return ($Matches[1].Trim() -replace '(?<=\d)u$', '') }
        return '?'
    }
    $info = @()
    $info += "Scan-Zeitpunkt      : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $info += "AssemblyDir         : $AssemblyDir"
    $info += ('Spielversion       : {0}.{1}.{2}-f{3}  (Release-Typ {4})' -f (Get-Const $bc 'APPLICATION_VERSION_A'), (Get-Const $bc 'APPLICATION_VERSION_B'), (Get-Const $bc 'APPLICATION_VERSION_C'), (Get-Const $bc 'APPLICATION_BUILD_NUMBER'), (Get-Const $bc 'APPLICATION_RELEASE_TYPE'))
    $info += 'DATA_FORMAT_VERSION  : ' + (Get-Const $bc 'DATA_FORMAT_VERSION')
    $info += 'SAVE_DATA_FORMAT    : ' + (Get-Const $bc 'SAVE_DATA_FORMAT_VERSION')
    foreach ($dll in 'Assembly-CSharp.dll', 'ColossalManaged.dll', 'ICities.dll') {
        $f = Join-Path $AssemblyDir $dll
        if (Test-Path $f) {
            $i = Get-Item $f
            $info += ('{0,-22}: {1} Bytes, {2:yyyy-MM-dd}, SHA256 {3}' -f $dll, $i.Length, $i.LastWriteTime, (Get-FileHash $f -Algorithm SHA256).Hash)
        }
    }
    if ($AvoDll -and (Test-Path $AvoDll)) {
        $i = Get-Item $AvoDll
        $info += ('{0,-22}: {1} Bytes, {2:yyyy-MM-dd}, SHA256 {3}' -f 'AVO (gepruefte DLL)', $i.Length, $i.LastWriteTime, (Get-FileHash $AvoDll -Algorithm SHA256).Hash)
    }
    Write-Lines '00_info.txt' $info

    # ------------------------------------------------------------ 02 Enums
    function Get-EnumLines([string]$label, [string]$file) {
        $text = [IO.File]::ReadAllText($file)
        foreach ($em in [regex]::Matches($text, '(?ms)enum\s+(\w+)\s*(?::\s*\w+)?\s*\r?\n\s*\{(.*?)\r?\n\s*\}')) {
            $enumName = $em.Groups[1].Value
            $ordinal = 0L
            # Attribute wie [EnumPosition("A", "B", 12)] enthalten Kommas -> vor dem Trennen entfernen
            $enumBody = $em.Groups[2].Value -replace '\[[^\]]*\]', '' -replace '//[^\r\n]*', ''
            foreach ($raw in ($enumBody -split ',')) {
                $member = ($raw -replace '\s+', ' ').Trim()
                if (-not $member) { continue }
                if ($member -match '^(\w+)\s*=\s*(.+)$') {
                    $mName = $Matches[1]; $expr = $Matches[2].Trim()
                    if ($expr -match '^(0x[0-9a-fA-F]+|\d+)[uUlL]*$') { $ordinal = [Convert]::ToInt64($Matches[1].TrimEnd('u', 'U', 'l', 'L'), $(if ($Matches[1] -like '0x*') { 16 } else { 10 })); '{0}.{1}: {2} = {3}' -f $label, $enumName, $mName, $ordinal }
                    else { '{0}.{1}: {2} = {3}' -f $label, $enumName, $mName, $expr }
                }
                else { '{0}.{1}: {2} = {3}' -f $label, $enumName, $member, $ordinal }
                $ordinal++
            }
        }
    }
    $enumOut = @()
    foreach ($t in 'ItemClass', 'TransferManager', 'DistrictPolicies') {
        if ($cs.ContainsKey($t)) { $enumOut += @(Get-EnumLines $t $cs[$t]) } else { $enumOut += "FEHLT: Typ $t nicht gefunden" }
    }
    foreach ($n in 'APPLICATION_VERSION_A', 'APPLICATION_VERSION_B', 'APPLICATION_VERSION_C', 'APPLICATION_BUILD_NUMBER', 'DATA_FORMAT_VERSION') { $enumOut += ('CONST BuildConfig.{0} = {1}' -f $n, (Get-Const $bc $n)) }
    Write-Lines '02_enums_consts.txt' $enumOut

    # ------------------------------------------------------------ 03 Signaturen (inkl. verschachtelter Typen wie TransferManager.TransferOffer)
    function Get-Signatures([string]$file) {
        [IO.File]::ReadAllLines($file) |
            Where-Object { $_ -match '^\t\t?(?:public|protected|internal)\s' } |
            ForEach-Object { (($_ -replace '\s+', ' ').Trim() -replace '\s*\{\s*$', '') } |
            Sort-Object -Unique -CaseSensitive
    }
    $sigOut = @()
    foreach ($t in ($csTypes | Where-Object { $_ -ne 'BuildConfig' } | Sort-Object)) {
        if ($cs.ContainsKey($t)) { foreach ($s in (Get-Signatures $cs[$t])) { $sigOut += "[$t] $s" } }
        else { $sigOut += "[$t] FEHLT: Typ nicht gefunden" }
    }
    Write-Lines '03_signatures.txt' $sigOut

    # ------------------------------------------------------------ 04 NBT-Abhaengigkeiten
    # Hier eintragen, wenn NBT neue Spiel-Member per Reflection/direkt nutzt oder neue Harmony-Ziele bekommt.
    # Spalten: Typ, Member, Regex fuer die Deklarationszeile (leer = Member-Name als Wort), Verwendung in NBT
    $deps = @(
        @('VehicleManager', 'GetRandomVehicleInfo', 'VehicleInfo GetRandomVehicleInfo\(ref Randomizer \w+, ItemClass\.Service \w+, ItemClass\.SubService \w+, ItemClass\.Level \w+\)', 'Patcher.ReplaceMethod (4-Parameter-Overload) und Manager.GetRandomVehicleInfo'),
        @('VehicleManager', 'GetTransferIndex', 'static int GetTransferIndex\(ItemClass\.Service \w+, ItemClass\.SubService \w+, ItemClass\.Level \w+\)', 'Reflection-Delegate in Manager.cs (privat, statisch)'),
        @('VehicleManager', 'm_transferVehicles', 'FastList<ushort>\[\] m_transferVehicles', 'DynamicMethod ldfld in Manager.cs (privat)'),
        @('VehicleManager', 'RefreshTransferVehicles', 'void RefreshTransferVehicles\(\)', 'Harmony-Postfix VehicleManager_RefreshTransferVehicles_Patch'),
        @('WarehouseAI', 'GetTransferVehicleService', 'static VehicleInfo GetTransferVehicleService\(TransferManager\.TransferReason \w+, ItemClass\.Level \w+, ref Randomizer \w+\)', 'WarehouseAI_StartTransfer_Transpiler + Manager.GetTransferVehicleService'),
        @('TransferManager', 'TransferOffer.Building', 'ushort Building', 'Transpiler: offer.Building als Zielgebaeude'),
        @('Vehicle', 'm_transferType', 'byte m_transferType', 'CargoTruckAI_ChangeVehicleType_Transpiler (ldfld)'),
        @('Building', 'Info', 'BuildingInfo Info\s*$','Manager.GetBuildingInfo'),
        @('BuildingManager', 'm_buildings', 'Array16<Building> m_buildings', 'Manager.GetBuildingInfo'),
        @('BuildingInfo', 'm_cellLength', 'int m_cellLength', 'Regel "Max building''s length"'),
        @('BuildingInfo', 'm_cellWidth', 'int m_cellWidth', 'Regel "Max building''s width"'),
        @('BuildingInfo', 'm_class', 'ItemClass m_class', 'Gebaeudetyp-Erkennung'),
        @('ItemClass', 'm_service', 'Service m_service', 'Gebaeudetyp-Erkennung'),
        @('ItemClass', 'm_subService', 'SubService m_subService', 'Gebaeudetyp-Erkennung'),
        @('VehicleInfo', 'm_isLargeVehicle', 'bool m_isLargeVehicle', 'Kern der Mod: Filter auf kleine Fahrzeuge (Manager.GetVehicle)')
    )
    $depOut = @()
    foreach ($d in $deps) {
        $type = $d[0]; $member = $d[1]; $rx = $d[2]; $note = $d[3]
        $label = '{0}.{1}' -f $type, $member
        if (-not $cs.ContainsKey($type)) { $depOut += "HINWEIS $label  (Typ hier nicht dekompiliert)  <- $note"; continue }
        if (-not $rx) { $rx = '\b' + [regex]::Escape(($member -split '\.')[-1]) + '\b' }
        $hits = @([IO.File]::ReadAllLines($cs[$type]) | Where-Object { $_ -match '^\t+(?:public|protected|private|internal)\b' -and $_ -cmatch $rx } | ForEach-Object { ($_ -replace '\s+', ' ').Trim() })
        if ($hits.Count -eq 0) { $depOut += "FEHLT   $label  <- $note" }
        else { foreach ($h in $hits | Select-Object -First 3) { $depOut += "OK      $label : $h" } }
    }
    # Enum-Werte, die NBT im Code nennt (Manager.GetSourceBuildings / GetTargetBuildings, Goods-Filter)
    $enumNeed = @('ItemClass.Service: Road', 'ItemClass.Service: PublicTransport', 'ItemClass.Service: PlayerIndustry', 'ItemClass.Service: Industrial', 'ItemClass.Service: Disaster',
        'ItemClass.SubService: CommercialLow', 'ItemClass.SubService: CommercialHigh', 'ItemClass.SubService: CommercialEco', 'ItemClass.SubService: CommercialLeisure', 'ItemClass.SubService: CommercialTourist', 'ItemClass.SubService: CommercialWallToWall',
        'TransferManager.TransferReason: Goods')
    foreach ($e in $enumNeed) {
        $line = $enumOut | Where-Object { $_.StartsWith($e + ' = ') } | Select-Object -First 1
        if ($line) { $depOut += "OK      Enum $line" } else { $depOut += "FEHLT   Enum $e" }
    }
    # Hinweis, falls Gewerbe neue SubServices bekommt (NBT kennt dann den Zieltyp nicht -> Regel greift dort nicht)
    foreach ($l in ($enumOut | Where-Object { $_ -match '^ItemClass\.SubService: Commercial(\w+) = ' })) {
        $n = ($l -replace '^ItemClass\.SubService: (\w+) = .*$', '$1')
        if (@('CommercialLow', 'CommercialHigh', 'CommercialEco', 'CommercialLeisure', 'CommercialTourist', 'CommercialWallToWall') -notcontains $n) { $depOut += "HINWEIS Neuer Gewerbe-SubService $n ist NBT unbekannt (TargetBuildingTypes erweitern?)" }
    }

    # AVO-Seite: die beiden Harmony-Ziele in AdvancedVehicleOptions.dll
    if ($AvoDll -and (Test-Path $AvoDll)) {
        $avoPanel = Join-Path $tmp 'AVO.UIOptionPanel.cs'
        $avoCompat = Join-Path $tmp 'AVO.NoBigTruckCompatibilityPatch.cs'
        $okPanel = Invoke-DecompileType $AvoDll 'AdvancedVehicleOptionsUID.GUI.UIOptionPanel' $avoPanel $false
        $okCompat = Invoke-DecompileType $AvoDll 'AdvancedVehicleOptionsUID.Compatibility.NoBigTruckCompatibilityPatch' $avoCompat $false
        $avoChecks = @(
            @($okPanel, $avoPanel, 'AVO UIOptionPanel.m_isLargeVehicle', 'UICheckBox m_isLargeVehicle\b', 'Postfix-Parameter ___m_isLargeVehicle (Typ UICheckBox, Name muss gleich bleiben)'),
            @($okPanel, $avoPanel, 'AVO UIOptionPanel.OnCheckChanged', 'void OnCheckChanged\(UIComponent component, bool \w+\)', 'Postfix Manager.AVOCheckChanged (Parametername "component" muss gleich bleiben)'),
            @($okCompat, $avoCompat, 'AVO NoBigTruckCompatibilityPatch.IsNBTActive', 'static bool IsNBTActive\(\)', 'Prefix Patcher.NBTCheckPrefix')
        )
        foreach ($c in $avoChecks) {
            if (-not $c[0]) { $depOut += "FEHLT   $($c[2])  (Typ in AVO nicht gefunden)  <- $($c[4])"; continue }
            $hit = @([IO.File]::ReadAllLines($c[1]) | Where-Object { $_ -match $c[3] } | Select-Object -First 1)
            if ($hit.Count -eq 0) { $depOut += "FEHLT   $($c[2])  <- $($c[4])" } else { $depOut += "OK      $($c[2]) : $(($hit[0] -replace '\s+', ' ').Trim())" }
        }
        if ($okPanel) { Copy-Item $avoPanel (Join-Path $srcOut 'AVO.UIOptionPanel.cs.txt') }
        if ($okCompat) { Copy-Item $avoCompat (Join-Path $srcOut 'AVO.NoBigTruckCompatibilityPatch.cs.txt') }
    }
    else { $depOut += "HINWEIS AVO-DLL nicht gefunden ($AvoDll) - AVO-Ziele nicht geprueft" }
    Write-Lines '04_nbt_dependencies.txt' $depOut

    # ------------------------------------------------------------ 05 Harmony-Ziele im IL
    # IL-Methoden eines Typs einlesen: Name, normalisierter Kopf (Signatur), Rumpf-Zeilen
    function Get-IlMethods([string]$file) {
        $lines = [IO.File]::ReadAllLines($file)
        $list = @()
        $i = 0
        while ($i -lt $lines.Length) {
            if ($lines[$i] -match '^\s*\.method\b') {
                $head = @()
                while ($i -lt $lines.Length -and $lines[$i] -notmatch '^\s*\{\s*$') { $head += $lines[$i].Trim(); $i++ }
                $body = @()
                $i++
                while ($i -lt $lines.Length -and $lines[$i] -notmatch '^\s*\} // end of method ') { $body += $lines[$i]; $i++ }
                $h = (($head -join ' ') -replace '\s+', ' ' -replace '\( ', '(' -replace ' \)', ')')
                $name = '?'
                if ($h -match ' ([\w\.<>]+) \(') { $name = $Matches[1] }
                $list += New-Object psobject -Property @{ Name = $name; Head = $h; Body = $body }
            }
            $i++
        }
        return $list
    }
    $grvi = 'callvirt instance class VehicleInfo VehicleManager::GetRandomVehicleInfo(valuetype [ColossalManaged]ColossalFramework.Math.Randomizer&, valuetype ItemClass/Service, valuetype ItemClass/SubService, valuetype ItemClass/Level)'
    $gtvs = 'call class VehicleInfo WarehouseAI::GetTransferVehicleService(valuetype TransferManager/TransferReason, valuetype ItemClass/Level, valuetype [ColossalManaged]ColossalFramework.Math.Randomizer&)'
    $startParams = 'uint16 buildingID, valuetype Building& data, valuetype TransferManager/TransferReason material, valuetype TransferManager/TransferOffer offer'
    # Spalten: Typ, Methode, Signatur-Regex (Kopf), statisch?, ersetzter Aufruf (leer = keiner), Hinweis
    $targets = @(
        @('IndustrialBuildingAI', 'StartTransfer', [regex]::Escape("($startParams)"), $false, $grvi, 'StartTransfer_Transpiler: arg1=Quelle, arg4=offer, arg3=material'),
        @('IndustrialExtractorAI', 'StartTransfer', [regex]::Escape("($startParams)"), $false, $grvi, 'StartTransfer_Transpiler: arg1=Quelle, arg4=offer, arg3=material'),
        @('OutsideConnectionAI', 'StartConnectionTransferImpl', [regex]::Escape("($startParams,"), $true, $grvi, 'StartTransfer_Transpiler (statisch): arg0=Quelle, arg3=offer, arg2=material'),
        @('WarehouseAI', 'StartTransfer', [regex]::Escape("($startParams)"), $false, $gtvs, 'WarehouseAI_StartTransfer_Transpiler: arg1=Lager, arg4=offer'),
        @('CargoTruckAI', 'ChangeVehicleType', [regex]::Escape('(class VehicleInfo vehicleInfo, uint16 vehicleID, valuetype Vehicle& vehicleData, valuetype PathUnit/Position pathPos, uint32 laneID)'), $true, $grvi, 'CargoTruckAI_ChangeVehicleType_Transpiler: AccessTools mit 5 Parametertypen, ldloc.s 6/7, arg2=vehicleData'),
        @('VehicleManager', 'RefreshTransferVehicles', [regex]::Escape('()'), $false, '', 'Postfix Manager.RefreshTransferVehicles'),
        @('CargoTruckAI', 'StartTransfer', [regex]::Escape('(uint16 vehicleID, valuetype Vehicle& data, valuetype TransferManager/TransferReason material, valuetype TransferManager/TransferOffer offer)'), $false, 'callvirt instance void VehicleAI::SetTarget(uint16, valuetype Vehicle&, uint16)', 'Prefix Patcher.CargoTruckAI_StartTransfer_Prefix (neues Ziel fuer wartenden LKW; Parameternamen vehicleID/data/material/offer muessen gleich bleiben)')
    )
    $patOut = @()
    foreach ($t in $targets) {
        $type = $t[0]; $mName = $t[1]; $sigRx = $t[2]; $isStatic = $t[3]; $call = $t[4]; $note = $t[5]
        $label = "$type.$mName"
        if (-not $ilFiles.ContainsKey($type)) { $patOut += "FEHLT   $label  (Typ nicht gefunden)  <- $note"; continue }
        $methods = @(Get-IlMethods $ilFiles[$type] | Where-Object { $_.Name -eq $mName })
        if ($methods.Count -eq 0) { $patOut += "FEHLT   $label  (Methode nicht gefunden)  <- $note"; continue }
        foreach ($m in $methods) { $patOut += "INFO    $label Kopf: $($m.Head)" }
        $m = @($methods | Where-Object { $_.Head -match $sigRx } | Select-Object -First 1)
        if ($m.Count -eq 0) { $patOut += "PRUEFEN $label  Signatur geaendert (erwartet $($t[2] -replace '\\', ''))  <- $note"; continue }
        $m = $m[0]
        $static = $m.Head -match '\bstatic\b'
        if ($static -ne $isStatic) { $patOut += "PRUEFEN $label  statisch=$static, erwartet $isStatic (Argument-Indizes verschieben sich!)  <- $note" }
        else { $patOut += "OK      $label  Signatur + statisch=$static" }
        Set-Content -Path (Join-Path $ilOut "$type.$mName.il.txt") -Value (@($m.Head) + $m.Body) -Encoding UTF8
        if ($call) {
            $calls = @($m.Body | Where-Object { $_.Contains($call) }).Count
            $short = ($call -replace '^.*::(\w+)\(.*$', '$1')
            if ($calls -eq 0) { $patOut += "PRUEFEN $label  Aufruf $short nicht mehr vorhanden -> Transpiler ersetzt NICHTS (Harmony meldet trotzdem Erfolg)" }
            elseif ($mName -eq 'StartTransfer' -and $type -eq 'CargoTruckAI') { $patOut += "OK      $label  $calls x $short (neues Ziel, das der NBT-Prefix vorher prueft)" }
            else { $patOut += "OK      $label  $calls x $short (ersetzt der Transpiler)" }
            # andere Overloads desselben Aufrufs, die NBT NICHT ersetzt
            $other = @($m.Body | Where-Object { $_ -match "::$short\(" -and -not $_.Contains($call) }).Count
            if ($other -gt 0) { $patOut += "HINWEIS $label  $other x anderer Overload von $short (wird von NBT nicht ersetzt)" }
        }
        if ($type -eq 'CargoTruckAI' -and $mName -eq 'StartTransfer') {
            # Vanilla prueft Vehicle.Flags.WaitingTarget (0x80000 = 524288); NBT hat denselben Wert einkompiliert
            if (($m.Body -join "`n") -match 'ldc\.i4 524288\b') { $patOut += "OK      $label  prueft Vehicle.Flags.WaitingTarget (524288)" }
            else { $patOut += "PRUEFEN $label  WaitingTarget-Pruefung (ldc.i4 524288) nicht gefunden - Flag-Wert oder Logik geaendert?" }
        }
        if ($type -eq 'CargoTruckAI' -and $mName -eq 'ChangeVehicleType') {
            $locals = ($m.Body -join "`n")
            foreach ($idx in 6, 7) {
                if ($locals -match "\[$idx\] uint16\b") { $patOut += "OK      $label  lokale Variable [$idx] ist uint16" }
                else { $patOut += "PRUEFEN $label  lokale Variable [$idx] ist nicht mehr uint16 (ldloc.s $idx im Transpiler!)" }
            }
            $seq = @()
            for ($k = 0; $k -lt $m.Body.Length - 1; $k++) {
                if ($m.Body[$k] -match 'CargoTruckAI::FindCargoStation\(' -and $m.Body[$k + 1] -match 'stloc\.s (\d+)') { $seq += $Matches[1] }
            }
            if (($seq -join ',') -eq '6,7') { $patOut += "OK      $label  FindCargoStation -> stloc.s 6 (Start), stloc.s 7 (Ziel)" }
            else { $patOut += "PRUEFEN $label  FindCargoStation-Ergebnisse landen in [$($seq -join ',')], erwartet [6,7]" }
        }
    }
    Write-Lines '05_patch_targets.txt' $patOut

    # ------------------------------------------------------------ src\
    foreach ($kv in $cs.GetEnumerator()) { Copy-Item $kv.Value (Join-Path $srcOut "$($kv.Key).cs.txt") }

    Write-Host ''
    Write-Host "Fertig: $OutDir"
    Write-Host ('  Spiel: {0}' -f ($info | Where-Object { $_ -like 'Spielversion*' }))
    Write-Host ('  Abhaengigkeiten: {0} OK, {1} FEHLT' -f @($depOut | Where-Object { $_ -like 'OK*' }).Count, @($depOut | Where-Object { $_ -like 'FEHLT*' }).Count)
    Write-Host ('  Patch-Ziele    : {0} OK, {1} PRUEFEN, {2} FEHLT' -f @($patOut | Where-Object { $_ -like 'OK*' }).Count, @($patOut | Where-Object { $_ -like 'PRUEFEN*' }).Count, @($patOut | Where-Object { $_ -like 'FEHLT*' }).Count)
}
finally {
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
    $global:LASTEXITCODE = 0
}
