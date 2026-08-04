<#
.SYNOPSIS
  Verifies that every tool needed for the workshop is on PATH.
#>

$tools = @(
    @{ Cmd = "git";       Args = @("--version") },
    @{ Cmd = "code";      Args = @("--version") },
    @{ Cmd = "aws";       Args = @("--version") },
    @{ Cmd = "gcloud";    Args = @("--version") },
    @{ Cmd = "terraform"; Args = @("version") },
    @{ Cmd = "ssh";       Args = @("-V") }
)

$failed = 0
foreach ($t in $tools) {
    $name = $t.Cmd
    if (Get-Command $name -ErrorAction SilentlyContinue) {
        $first = (& $name @($t.Args) 2>&1 | Select-Object -First 1)
        Write-Host ("[ OK ] {0,-10} {1}" -f $name, $first) -ForegroundColor Green
    } else {
        Write-Host ("[FAIL] {0,-10} not found on PATH" -f $name) -ForegroundColor Red
        $failed++
    }
}

# --- connect.exe (SOCKS5 helper, ships with Git for Windows) ---
$connectPaths = @(
    "C:\Program Files\Git\mingw64\bin\connect.exe",
    "C:\Program Files\Git\mingw32\bin\connect.exe",
    "C:\Program Files (x86)\Git\mingw32\bin\connect.exe"
)
$connectFound = $connectPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($connectFound) {
    Write-Host ("[ OK ] {0,-10} {1}" -f "connect", $connectFound) -ForegroundColor Green
} else {
    Write-Host ("[FAIL] {0,-10} connect.exe not found (re-install Git for Windows)" -f "connect") -ForegroundColor Red
    $failed++
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All tools present. You are ready for the workshop." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed tool(s) missing. Re-open PowerShell (so PATH refreshes) and re-run. If still failing, raise your hand." -ForegroundColor Red
    exit 1
}
