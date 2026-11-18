# windows-server-ha-failover-cluster
# Windows Server High Availability (HA) Failover Cluster Lab

An end-to-end, PowerShell-automated Windows Server Failover Clustering (WSFC) architecture hosting a Highly Available HR Web Application (`SinghHRApp`) backed by centralized iSCSI shared storage and Cluster Shared Volumes (CSV).

## Architecture & Network Topology (`192.168.10.0/24`)

All virtual machines operate on an isolated Hyper-V Internal Virtual Switch (`Lab-Internal`), with nested virtualization enabled on the cluster nodes and a synchronized `Cluster-Switch` connecting the clustered workload.

| Hostname | Role | IPv4 Address | Specs |
| :--- | :--- | :--- | :--- |
| **SinghDC** | Active Directory DS & DNS (`singh.local`) | `192.168.10.10` | 2 vCPU, 2 GB RAM |
| **SinghISCSI** | Windows iSCSI Target Server (Shared SAN) | `192.168.10.20` | 2 vCPU, 2 GB RAM, 2 GB Quorum + 80 GB CSV |
| **SinghVH1** | Hyper-V & Failover Cluster Node 1 | `192.168.10.31` | 2 vCPU, 5 GB RAM (Nested Virtualization) |
| **SinghVH2** | Hyper-V & Failover Cluster Node 2 | `192.168.10.32` | 2 vCPU, 5 GB RAM (Nested Virtualization) |
| **SinghCluster** | Failover Cluster Administrative Access Point | `192.168.10.40` | Node + Disk Majority Quorum (`2 GB` Witness) |
| **SinghHRApp** | Clustered IIS HR Application VM (Gen 2) | `192.168.10.50` | 2 vCPU, 2 GB RAM, Stored on `C:\ClusterStorage\Volume2` |

## High Availability Validation Results

1. **Cluster Validation (`Test-Cluster`):** Passed all Storage, Network, Inventory, and System Configuration checks with zero errors (`evidence/cluster-validation-report.htm`).
2. **Planned Maintenance (Live Migration):** Migrated running `SinghHRApp` between `SinghVH1` and `SinghVH2` via `Move-ClusterVirtualMachineRole` with **zero HTTP downtime** and minimal packet loss (`evidence/03-live-migration-ping.png`).
3. **Unplanned Outage (Hard Node Crash Simulation):** Forced power-off of active owner node `SinghVH2` (`Stop-VM -TurnOff`). `SinghCluster` maintained Quorum via the iSCSI Disk Witness and automatically booted `SinghHRApp` on `SinghVH1`, restoring `HTTP 200` availability (`evidence/04-unplanned-failover-recovery.png`).

## Engineering Lessons & Troubleshooting Solved
* **CSV Redirected Access & Switch Binding:** Binding an external `Cluster-Switch` to a single-NIC nested node momentarily resets network state; re-verifying persistent iSCSI initiator sessions (`MSiSCSI`) ensures CSV direct I/O remains healthy before VM provisioning.
* **Nested VM Memory Sizing:** Balanced node RAM allocation (`5 GB` per nested Hyper-V host) prevents host memory commit exhaustion (`0x8007000E`) when recovering crashed cluster nodes alongside active workloads.
* **ICMP Firewall Auditing:** Windows Server drops inbound ICMPv4 echo requests by default; configured explicit firewall rules (`ICMPv4 Type 8`) on `SinghHRApp` to enable continuous packet-loss telemetry alongside HTTP health checks.
