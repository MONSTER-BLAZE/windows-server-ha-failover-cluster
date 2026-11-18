Where to run: SinghDC (192.168.10.10, PowerShell as Administrator). Provides real-time ICMP and HTTP 200 telemetry during planned Live Migration and unplanned crash failover tests.

<#
.SYNOPSIS
    Continuous ICMP and HTTP availability monitor for SinghHRApp (192.168.10.50).
.DESCRIPTION
    Polls SinghHRApp every 2 seconds to measure packet loss and HTTP 200 recovery time
    during Live Migration and forced node crash simulations. Press Ctrl+C to stop.
#>

$TargetIP  = "192.168.10.50"
$TargetUrl = "http://$TargetIP"

Write-Host "Monitoring Highly Available HR Portal ($TargetUrl) - Press Ctrl+C to stop..." -ForegroundColor Cyan

while ($true) {
    $Timestamp = Get-Date -Format "HH:mm:ss"
    $PingOk    = Test-Connection -ComputerName $TargetIP -Count 1 -Quiet
    
    try {
        $Response = Invoke-WebRequest -Uri $TargetUrl -UseBasicParsing -TimeoutSec 2
        $HttpCode = $Response.StatusCode
        $Color    = "Green"
    }
    catch {
        $HttpCode = "DOWN"
        $Color    = "Red"
    }

    Write-Host "[$Timestamp] Ping: $PingOk | HTTP: $HttpCode" -ForegroundColor $Color
    Start-Sleep -Seconds 2
}
