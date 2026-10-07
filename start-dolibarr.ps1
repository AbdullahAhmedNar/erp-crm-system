# start-dolibarr.ps1 - Start MariaDB and PHP development server for Dolibarr
$mariadbExe = "C:\Program Files\MariaDB 13.0\bin\mariadbd.exe"
$mariadbCfg = "C:\Program Files\MariaDB 13.0\data\my.ini"
$mysqlExe   = "C:\Program Files\MariaDB 13.0\bin\mysql.exe"
$dolibarrRoot = $PSScriptRoot
$errLog     = "$dolibarrRoot\mariadb.log"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dolibarr Development Environment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Cleaning up old processes..." -ForegroundColor Yellow
Get-Process -Name "mysqld","mariadbd" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name "php" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "[2/3] Starting MariaDB on port 3306..." -ForegroundColor Yellow
$dbProc = Start-Process -FilePath $mariadbExe `
    -ArgumentList "--defaults-file=`"$mariadbCfg`"","--standalone","--log-error=`"$errLog`"" `
    -WindowStyle Hidden -PassThru

$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    if (netstat -ano 2>$null | Select-String ":3306.*LISTENING") { $ready = $true; break }
}

if (!$ready) {
    Write-Host "ERROR: MariaDB failed to start! Check: $errLog" -ForegroundColor Red
    exit 1
}
Write-Host "  MariaDB running (PID: $($dbProc.Id))" -ForegroundColor Green

& $mysqlExe -u root -h 127.0.0.1 -P 3306 --connect-timeout=5 -e "CREATE DATABASE IF NOT EXISTS dolibarr CHARACTER SET utf8 COLLATE utf8_unicode_ci; CREATE USER IF NOT EXISTS 'dolibarr'@'%' IDENTIFIED BY 'dolibarr'; GRANT ALL PRIVILEGES ON dolibarr.* TO 'dolibarr'@'%'; FLUSH PRIVILEGES;" 2>$null
Write-Host "  Database ready" -ForegroundColor Green

Write-Host "[3/3] Starting PHP server on http://127.0.0.1:8000..." -ForegroundColor Yellow
$phpProc = Start-Process -FilePath "php" `
    -ArgumentList "-S","127.0.0.1:8000","-t","`"$dolibarrRoot\htdocs`"" `
    -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 2
Write-Host "  PHP server running (PID: $($phpProc.Id))" -ForegroundColor Green

Write-Host "`n Dolibarr is ready at: http://127.0.0.1:8000" -ForegroundColor Green
Write-Host " Press Ctrl+C to stop...`n" -ForegroundColor Yellow

try {
    while ($true) {
        Start-Sleep -Seconds 10
        if ($dbProc.HasExited) {
            Write-Host "MariaDB stopped! Restarting..." -ForegroundColor Red
            $dbProc = Start-Process -FilePath $mariadbExe -ArgumentList "--defaults-file=`"$mariadbCfg`"","--standalone","--log-error=`"$errLog`"" -WindowStyle Hidden -PassThru
        }
        if ($phpProc.HasExited) {
            Write-Host "PHP stopped! Restarting..." -ForegroundColor Red
            $phpProc = Start-Process -FilePath "php" -ArgumentList "-S","127.0.0.1:8000","-t","`"$dolibarrRoot\htdocs`"" -WindowStyle Hidden -PassThru
        }
    }
} finally {
    $dbProc | Stop-Process -Force -ErrorAction SilentlyContinue
    $phpProc | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "Servers stopped." -ForegroundColor Green
}
