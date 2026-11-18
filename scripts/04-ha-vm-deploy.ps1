Where to run: Stage A on both SinghVH1 and SinghVH2; Stage B on SinghVH1; Stage C inside SinghHRApp. Configures Cluster-Switch, deploys the clustered SinghHRApp VM on C:\ClusterStorage\Volume2, configures IIS, and opens ICMPv4 in Windows Firewall.

<#
.SYNOPSIS
    Deploys the Highly Available HR Portal VM (SinghHRApp) on the Cluster Shared Volume.
#>

# ==============================================================================
# STAGE A: Run on BOTH SinghVH1 and SinghVH2
# ==============================================================================
if (-not (Get-VMSwitch -Name "Cluster-Switch" -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name "Cluster-Switch" -NetAdapterName "Ethernet" -AllowManagementOS $true
}

# ==============================================================================
# STAGE B: Run on SinghVH1 ONLY
# ==============================================================================
$CsvPath = "C:\ClusterStorage\Volume2"
New-VM -Name "SinghHRApp" -MemoryStartupBytes 2GB -Generation 2 -Path $CsvPath `
       -NewVHDPath "$CsvPath\SinghHRApp\SinghHRApp.vhdx" -NewVHDSizeBytes 25GB -SwitchName "Cluster-Switch"
Set-VMProcessor -VMName "SinghHRApp" -Count 2
Set-VMMemory -VMName "SinghHRApp" -DynamicMemoryEnabled $false

Add-VMDvdDrive -VMName "SinghHRApp" -Path "$CsvPath\ISO\WindowsServer.iso"
Set-VMFirmware -VMName "SinghHRApp" -FirstBootDevice (Get-VMDvdDrive -VMName "SinghHRApp")

Add-ClusterVirtualMachineRole -VMName "SinghHRApp"
Start-ClusterGroup -Name "SinghHRApp"

# ==============================================================================
# STAGE C: Run INSIDE SinghHRApp (after Windows Server OS installation)
# ==============================================================================
# 1. Assign static IP 192.168.10.50 and join singh.local
$Adapter = (Get-NetAdapter | Where-Object Status -eq "Up").Name
Set-NetIPInterface -InterfaceAlias $Adapter -Dhcp Disabled
New-NetIPAddress -InterfaceAlias $Adapter -IPAddress 192.168.10.50 -PrefixLength 24 -DefaultGateway 192.168.10.1
Set-DnsClientServerAddress -InterfaceAlias $Adapter -ServerAddresses 192.168.10.10
Add-Computer -DomainName "singh.local" -NewName "SinghHRApp" -Credential (Get-Credential "SINGH\Administrator") -Restart -Force

# 2. Deploy IIS HR Application Portal & allow inbound ICMPv4 (after reboot)
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Action Allow

$Html = @"
<html>
<head><title>Singh Enterprise HR Portal</title></head>
<body style='font-family:Segoe UI; text-align:center; margin-top:50px;'>
<h1>Singh Enterprise - Highly Available HR Portal</h1>
<p>Hosted on Clustered VM: <b>SinghHRApp (192.168.10.50)</b></p>
<p>Status: <span style='color:green; font-weight:bold;'>ONLINE</span></p>
</body>
</html>
"@
Set-Content -Path "C:\inetpub\wwwroot\iisstart.htm" -Value $Html -Force
