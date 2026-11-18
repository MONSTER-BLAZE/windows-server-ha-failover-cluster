Where to run: SinghISCSI (192.168.10.20, PowerShell as Administrator). Initializes the 100 GB storage drive (S:), installs the iSCSI Target Server role, creates the 2 GB Quorum VHDX and 80 GB CSV VHDX, and maps both LUNs to SinghVH1 and SinghVH2.

<#
.SYNOPSIS
    Configures Windows iSCSI Target Server and shared VHDX LUNs on SinghISCSI.
#>

# 1. Initialize and format the 100 GB SAN disk as Drive S:
$SanDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq "RAW" -and $_.Size -gt 90GB }
if ($SanDisk) {
    Initialize-Disk -Number $SanDisk.Number -PartitionStyle GPT -PassThru |
        New-Partition -DriveLetter S -UseMaximumSize |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel "SAN-Storage" -Confirm:$false | Out-Null
}

# 2. Install iSCSI Target Server role
Install-WindowsFeature -Name FS-iSCSITarget-Server -IncludeManagementTools

# 3. Create iSCSI Target restricted to SinghVH1 (.31) and SinghVH2 (.32)
$TargetName = "SinghClusterTarget"
New-IscsiServerTarget -TargetName $TargetName -InitiatorIds @("IPAddress:192.168.10.31", "IPAddress:192.168.10.32")

# 4. Create Quorum (2 GB) and CSV (80 GB) virtual disks and map LUNs
$DiskDir = "S:\iSCSIVirtualDisks"
New-Item -Path $DiskDir -ItemType Directory -Force | Out-Null

New-IscsiVirtualDisk -Path "$DiskDir\Quorum.vhdx" -SizeBytes 2GB
New-IscsiVirtualDisk -Path "$DiskDir\ClusterCSV.vhdx" -SizeBytes 80GB

Add-IscsiVirtualDiskTargetMapping -TargetName $TargetName -Path "$DiskDir\Quorum.vhdx"
Add-IscsiVirtualDiskTargetMapping -TargetName $TargetName -Path "$DiskDir\ClusterCSV.vhdx"

Get-IscsiServerTarget -TargetName $TargetName | Select-Object TargetName, Status, LunMappings, InitiatorIds
