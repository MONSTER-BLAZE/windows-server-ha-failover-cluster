Where to run: Physical Windows 11 Host (PowerShell as Administrator). Provisions Lab-Internal, creates all 4 base VMs, attaches the Windows Server ISO, and enables nested virtualization on both cluster nodes.

PowerShell
<#
.SYNOPSIS
    Provisions the isolated Hyper-V lab switch and 4 core VMs on the physical Windows 11 host.
.DESCRIPTION
    Creates Lab-Internal (192.168.10.1/24), provisions SinghDC, SinghISCSI, SinghVH1, and SinghVH2
    with balanced memory sizing (5 GB per cluster node), and enables nested virtualization.
#>

$SwitchName = "Lab-Internal"
$LabRoot    = "C:\Lab\VMs"
$IsoPath    = "C:\Lab\ISO\SERVER_EVAL_x64FRE_en-us.iso"

# 1. Create isolated Internal Virtual Switch and assign host gateway IP
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
    $Adapter = Get-NetAdapter | Where-Object Name -like "*$SwitchName*"
    New-NetIPAddress -InterfaceIndex $Adapter.ifIndex -IPAddress 192.168.10.1 -PrefixLength 24 | Out-Null
}

# 2. Define VM inventory (balanced RAM for 32 GB physical host)
$VMs = @(
    @{ Name = "SinghDC";    Memory = 2GB; Disk = 40GB; Nested = $false },
    @{ Name = "SinghISCSI"; Memory = 2GB; Disk = 40GB; Nested = $false },
    @{ Name = "SinghVH1";   Memory = 5GB; Disk = 40GB; Nested = $true  },
    @{ Name = "SinghVH2";   Memory = 5GB; Disk = 40GB; Nested = $true  }
)

# 3. Provision VMs, attach ISO, and configure nested virtualization on Hyper-V nodes
foreach ($VM in $VMs) {
    $VmDir = Join-Path $LabRoot $VM.Name
    New-VM -Name $VM.Name -MemoryStartupBytes $VM.Memory -Generation 2 -Path $LabRoot `
           -NewVHDPath "$VmDir\$($VM.Name).vhdx" -NewVHDSizeBytes $VM.Disk -SwitchName $SwitchName | Out-Null
    
    Set-VMProcessor -VMName $VM.Name -Count 2
    Set-VMMemory -VMName $VM.Name -DynamicMemoryEnabled $false
    Add-VMDvdDrive -VMName $VM.Name -Path $IsoPath
    Set-VMFirmware -VMName $VM.Name -FirstBootDevice (Get-VMDvdDrive -VMName $VM.Name)

    if ($VM.Nested) {
        Set-VMProcessor -VMName $VM.Name -ExposeVirtualizationExtensions $true
        Get-VMNetworkAdapter -VMName $VM.Name | Set-VMNetworkAdapter -MacAddressSpoofing On
    }
}

# 4. Attach a dedicated 100 GB virtual SAN disk to SinghISCSI
New-VHD -Path "$LabRoot\SinghISCSI\SAN-Storage.vhdx" -SizeBytes 100GB -Dynamic | Out-Null
Add-VMHardDiskDrive -VMName "SinghISCSI" -Path "$LabRoot\SinghISCSI\SAN-Storage.vhdx"

Get-VM | Select-Object Name, State, ProcessorCount, @{Name="RAM(GB)";Expression={$_.MemoryStartup / 1GB}}
