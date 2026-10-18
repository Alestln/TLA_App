param (
    [string]$Spec = "GatewayRateLimiter_Buggy",
    [switch]$Full          # -Full : show the raw, unfiltered TLC output
)

$jarPath = Join-Path $PSScriptRoot "tla2tools.jar"

if (-not (Test-Path $jarPath)) {
    Write-Host "[*] tla2tools.jar not found. Downloading official release..." -ForegroundColor Cyan
    $url = "https://github.com/tlaplus/tlaplus/releases/download/v1.8.0/tla2tools.jar"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $jarPath -UseBasicParsing
        Write-Host "[+] Downloaded successfully: $jarPath" -ForegroundColor Green
    } catch {
        Write-Host "[-] Download failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

$tlaFile = Join-Path $PSScriptRoot "$Spec.tla"
$cfgFile = Join-Path $PSScriptRoot "$Spec.cfg"

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  TLC Model Checker: $Spec" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# -XX:+UseParallelGC  : removes the GC warning
# -nowarning          : suppresses linter warnings
# -noGenerateSpecTE   : do not create *_TTrace_*.tla / .bin files next to the spec
# -cleanup            : delete the 'states' working directory after the run
$tlcArgs = @("-XX:+UseParallelGC", "-cp", $jarPath, "tlc2.TLC",
             "-nowarning", "-noGenerateSpecTE", "-cleanup",
             "-config", $cfgFile, $tlaFile)

Push-Location $PSScriptRoot
try {
    if ($Full) {
        & java @tlcArgs
        return
    }

    # Technical noise that is not useful for students
    $noise = '^(TLC2 Version|Running |Parsing file|Semantic processing|Linting of module|Starting\.\.\.|Computing initial states|Finished computing initial|  Estimates of the probability|  because two distinct|  calculated \(optimistic\)|The average outdegree|Finished in|Warning:|\(Use the -nowarning)'

    & java @tlcArgs 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch $noise -and $_.Trim() -ne "" } | ForEach-Object {
        if     ($_ -match 'violated|^Error|Deadlock')      { Write-Host $_ -ForegroundColor Red }
        elseif ($_ -match 'No error has been found')       { Write-Host $_ -ForegroundColor Green }
        elseif ($_ -match '^State \d+:')                   { Write-Host ""; Write-Host $_ -ForegroundColor Yellow }
        else                                               { Write-Host $_ }
    }
}
finally {
    Pop-Location
}
