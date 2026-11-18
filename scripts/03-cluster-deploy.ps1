Where to run: Stage A on both SinghVH1 and SinghVH2; Stage B on SinghVH1 only. Connects iSCSI storage, installs Hyper-V and Failover Clustering, validates the cluster, builds SinghCluster (192.168.10.40), and assigns the Quorum Witness and Cluster Shared Volume.

<#
.SYNOPSIS
    Connects iSCSI storage, installs cluster roles, and deploys SinghCluster.
#>

# ==============================================================================
# STAGE A: Run on BOTH SinghVH1 and SinghVH2
# ==============================================================================
Set-Service -Name MSiSCSI -StartupType Automatic
Start-Service -Name MSiSCSI
New-IscsiTargetPortal -TargetPortalAddress 192.168.10.20
Get-IscsiTarget | Connect-IscsiTarget -IsPersistent $true

Install-WindowsFeature -Name Hyper-V, Failover-Clustering -IncludeManagementTools -Restart

# ==============================================================================
# STAGE B: Run on SinghVH1 ONLY (after both nodes reboot)
# ==============================================================================
# 1. Initialize and format the 2 GB and 80 GB iSCSI disks
Get-Disk | Where-Object { $_.FriendlyName -like "*MSFT Virtual HD*" -and $_.OperationalStatus -eq "Offline" } | ForEach-Object {
    Set-Disk -Number $_.Number -IsOffline $false
    Set-Disk -Number $_.Number -IsReadOnly $false
    Initialize-Disk -Number $_.Number -PartitionStyle GPT -PassThru |
        New-Partition -UseMaximumSize |
        Format-Volume -FileSystem NTFS -Confirm:$false | Out-Null
}

# 2. Validate cluster readiness and create SinghCluster
Test-Cluster -Node "SinghVH1", "SinghVH2"
New-Cluster -Name "SinghCluster" -Node "SinghVH1", "SinghVH2" -StaticAddress 192.168.10.40

# 3. Assign the 2 GB disk as Quorum Witness and the 80 GB disk as CSV
$ClusterDisks = Get-ClusterResource | Where-Object ResourceType -eq "Physical Disk"
foreach ($Disk in $ClusterDisks) {
    $SizeGB = [Math]::Round((Get-Disk | Where-Object UniqueId -like "*$($Disk.Name)*").Size / 1GB, 0)
    # Alternatively verify sizes in Failover Cluster Manager before assigning:
    # Cluster Disk 2 (2 GB) -> Quorum Witness | Cluster Disk 1 (80 GB) -> CSV
}

Set-ClusterQuorum -DiskWitness "Cluster Disk 2"
Add-ClusterSharedVolume -Name "Cluster Disk 1"

Get-ClusterQuorum
Get-ClusterSharedVolume | Select-Object Name, State, OwnerNode
