# Stops node processes and deletes payment-related files/folders
$ErrorActionPreference = 'Continue'
$targets = @(
    'D:\Codepod\CodePod_Web\server',
    'D:\Codepod\CodePod_Web\cart.html',
    'D:\Codepod\CodePod_Web\receipt.html',
    'D:\Codepod\CodePod_Web\assets\js\cart.js',
    'D:\Codepod\CodePod_Web\patch_payments.md',
    'D:\Codepod\CodePod_Web\scripts'
)

# Stop node processes if any
$nodes = Get-Process -Name node -ErrorAction SilentlyContinue
if ($nodes) {
    foreach ($n in $nodes) {
        Write-Host "Stopping node PID $($n.Id)"
        Stop-Process -Id $n.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host 'No node process found'
}

# Delete targets
foreach ($t in $targets) {
    if (Test-Path $t) {
        try {
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted: $t"
        } catch {
            Write-Host "Failed to delete: $t - $($_.Exception.Message)"
        }
    } else {
        Write-Host "Not found: $t"
    }
}

# Verification
Write-Host '--- Verification ---'
foreach ($t in $targets) {
    Write-Host ($t + ' -> ' + (Test-Path $t))
}
