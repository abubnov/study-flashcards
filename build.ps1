<#
  build.ps1 - flashcards builder.

  What it does:
    For every *.csv in this folder it reads the data, injects it into template.html
    (in place of the markers /*CARDS_PLACEHOLDER*/, /*SET_ID*/, /*SET_NAME*/) and
    writes a self-contained <csv-name>.html. Open the built <name>.html.

  Multiple sets:
    One CSV = one set of cards = one HTML. Want another set? Copy cards.csv to,
    say, english.csv, edit it and run the build again.
    english.csv -> english.html. Each set keeps its own "learned" memory.

  Encoding (auto):
    Detected automatically - UTF-8 (with or without BOM) or the system ANSI code
    page (e.g. Windows-1251, what a localized Excel writes). No flags needed.
    Force it if you must: -Encoding UTF8 | ANSI | 1251 | Unicode.

  Run:
    double-click build.bat, or in PowerShell:
      powershell -ExecutionPolicy Bypass -File build.ps1
    examples with parameters (all optional):
      build.ps1                          # build ALL *.csv in the folder
      build.ps1 -Csv english.csv         # a single set -> english.html
      build.ps1 -Csv a.csv -Out b.html   # custom output file
      build.ps1 -Delimiter "," -Encoding ANSI

  CSV: first row is the header. Columns are matched by name
       (front/word/term and back/text/definition/translation/meaning),
       otherwise the first two columns are used.
       The delimiter (";" or ",") is auto-detected if not given.
       Card count = number of data rows (no fixed number).
#>
param(
  [string]$Csv       = "",       # empty = all *.csv in the folder
  [string]$Template  = "template.html",
  [string]$Out       = "",       # empty = <csv-name>.html; used only for a single CSV
  [string]$Delimiter = "",       # empty = auto (";" or ",")
  [string]$Encoding  = "Auto"    # Auto | UTF8 | ANSI | 1251 | Unicode
)

$ErrorActionPreference = "Stop"

# --- base path: the script folder (works from build.bat and from the console) ---
$base = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
function Resolve-In([string]$p){
  if ([System.IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $base $p }
}

# --- detect file encoding: explicit override -> BOM -> strict UTF-8 -> system ANSI ---
function Get-CsvEncoding([byte[]]$bytes, [string]$override){
  if ($override -and $override -ne 'Auto') {
    switch -Regex ($override) {
      '^(utf-?8|utf8bom)$'          { return New-Object System.Text.UTF8Encoding($false) }
      '^(ansi|default)$'            { return [System.Text.Encoding]::Default }
      '^((windows-|cp)?1251)$'      { return [System.Text.Encoding]::GetEncoding(1251) }
      '^(unicode|utf-?16(le)?)$'    { return [System.Text.Encoding]::Unicode }
      default {
        try { return [System.Text.Encoding]::GetEncoding($override) }
        catch { Write-Warning "Unknown encoding '$override' - falling back to auto." }
      }
    }
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { return New-Object System.Text.UTF8Encoding($false) }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { return [System.Text.Encoding]::Unicode }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { return [System.Text.Encoding]::BigEndianUnicode }
  # strict UTF-8: if the bytes are valid UTF-8, use it; otherwise treat as system ANSI
  try {
    $strict = New-Object System.Text.UTF8Encoding($false, $true)   # throwOnInvalidBytes = $true
    [void]$strict.GetString($bytes)
    return New-Object System.Text.UTF8Encoding($false)
  } catch {
    return [System.Text.Encoding]::Default
  }
}

# --- escape a value for a double-quoted JS string ---
function ConvertTo-JsString([object]$val){
  if ($null -eq $val) { return "" }
  return ([string]$val).Replace('\','\\').Replace('"','\"').Replace("`r"," ").Replace("`n"," ")
}
# --- escape a value for HTML text ---
function ConvertTo-HtmlText([object]$val){
  if ($null -eq $val) { return "" }
  return ([string]$val).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;')
}

# --- read the template once (it is always UTF-8) ---
$templatePath = Resolve-In $Template
if (-not (Test-Path $templatePath)) { Write-Error "Template not found: $templatePath"; exit 1 }
$templateHtml = Get-Content -Path $templatePath -Raw -Encoding UTF8
if ($templateHtml -notmatch [regex]::Escape('/*CARDS_PLACEHOLDER*/')) {
  Write-Error "Template has no /*CARDS_PLACEHOLDER*/ marker - nowhere to inject data."; exit 1
}

# --- CSV list: a specific one (-Csv) or all *.csv in the folder ---
if ($Csv) {
  $csvFiles = @(Resolve-In $Csv)
} else {
  $csvFiles = @(Get-ChildItem -Path $base -Filter *.csv -File | Sort-Object Name | ForEach-Object { $_.FullName })
}
if ($csvFiles.Count -eq 0) { Write-Error "No *.csv files found in $base"; exit 1 }
if ($Out -and $csvFiles.Count -gt 1) { Write-Warning "-Out ignored: building multiple sets."; $Out = "" }

# --- build each set ---
$built = 0
foreach ($csvPath in $csvFiles) {
  if (-not (Test-Path $csvPath)) { Write-Warning "Skipped (no file): $csvPath"; continue }
  $setName = [System.IO.Path]::GetFileNameWithoutExtension($csvPath)

  # read bytes and decode with the chosen encoding
  $bytes = [System.IO.File]::ReadAllBytes($csvPath)
  $enc   = Get-CsvEncoding $bytes $Encoding
  $text  = $enc.GetString($bytes).TrimStart([char]0xFEFF)          # drop the BOM char if one is left
  $lines = @($text -split "`r`n|`n|`r" | Where-Object { $_.Trim() -ne '' })
  if ($lines.Count -lt 1) { Write-Warning "Empty CSV: $csvPath"; continue }

  # delimiter
  $delim = $Delimiter
  if ([string]::IsNullOrEmpty($delim)) { if ($lines[0] -match ';') { $delim = ';' } else { $delim = ',' } }

  $rows = @($lines | ConvertFrom-Csv -Delimiter $delim)
  if ($rows.Count -eq 0) { Write-Warning "Set '$setName' has no data rows - 0 cards." }

  # front / back columns
  $cols     = if ($rows.Count) { @($rows[0].psobject.Properties.Name) } else { @() }
  $frontCol = $cols | Where-Object { $_ -match '^(front|word|term)$' }                        | Select-Object -First 1
  $backCol  = $cols | Where-Object { $_ -match '^(back|text|definition|translation|meaning)$' } | Select-Object -First 1
  if (-not $frontCol -and $cols.Count -ge 1) { $frontCol = $cols[0] }
  if (-not $backCol  -and $cols.Count -ge 2) { $backCol  = $cols[1] }

  # CARDS array lines
  $cardLines = foreach ($row in $rows) {
    '  {front:"' + (ConvertTo-JsString $row.$frontCol) + '", back:"' + (ConvertTo-JsString $row.$backCol) + '"},'
  }
  $cardsText = ($cardLines -join "`r`n")

  # inject the markers
  $html = $templateHtml.Replace('/*CARDS_PLACEHOLDER*/', $cardsText)
  $html = $html.Replace('/*SET_ID*/',   (ConvertTo-JsString  $setName))
  $html = $html.Replace('/*SET_NAME*/', (ConvertTo-HtmlText  $setName))

  $outFile = if ($Out) { Resolve-In $Out } else { Join-Path $base ($setName + ".html") }
  Set-Content -Path $outFile -Value $html -Encoding UTF8

  Write-Host ("[{0}]  cards: {1}  |  encoding: {2}  |  delimiter: '{3}'  ->  {4}" -f `
    $setName, $rows.Count, $enc.WebName, $delim, (Split-Path $outFile -Leaf)) -ForegroundColor Green
  $built++
}

Write-Host ("Done. Sets built: {0}." -f $built) -ForegroundColor Cyan
