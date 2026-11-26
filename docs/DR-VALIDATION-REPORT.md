# Hybrid Disaster Recovery Validation Report — Azure Site Recovery

**Environment:** `Singh-HyperV-Cluster` (`SinghVH1`, `SinghVH2`) → Azure (`RSV-Singh-Bunker` / `VNet-Singh-DR`)  
**Protected Workload:** `SinghHRApp` (Windows Server 2022 IIS HR Portal on `Cluster Disk 2` CSV)  
**Validation Date:** November 25, 2026  

---

## 1. Infrastructure & Prerequisites Validation
* **Outbound NAT & DNS Forwarding:** Configured `SinghLabNAT` (`192.168.10.0/24`) on the host `vEthernet (Lab-Internal)` adapter (`192.168.10.1`) and added external DNS forwarders (`8.8.8.8`, `1.1.1.1`) on `SinghDC` (`192.168.10.10`). Verified outbound `TCP 443` reachability to `login.microsoftonline.com`, `management.azure.com`, and `download.microsoft.com` from both cluster nodes.
* **Host Registration:** Installed the Azure Site Recovery Provider on `SinghVH1` and `SinghVH2` using shared `.VaultCredentials`; both nodes registered as **Connected** under site `Singh-HyperV-Cluster`.
* **Initial Replication Troubleshooting (Error 68503):** Resolved initial sync stall (`Error 68503`) by enabling **Allow storage account key access**, enforcing **TLS 1.2**, disabling **Blob/Container Soft Delete** on the replication storage account, and re-enabling protection—achieving **Protected / Healthy** status with a **5-second RPO**.

---

## 2. Drill A: Non-Disruptive Test Failover & Total Site Blackout
1. **Provisioning:** Triggered **Test Failover** using the *Latest processed* recovery point into `VNet-Singh-DR` (`Standard_B2s`), spawning `SinghHRApp-test` (`192.168.10.4`).
2. **Network & Guest Adaptation:** Attached temporary Public IP (`pip-singhhrapp-test`), allowed inbound `TCP 3389` and `TCP 80` on the Azure NSG, and used Azure **Run Command** to switch the guest NIC from static (`192.168.10.50`) to Azure DHCP and enable RDP on the Public firewall profile.
3. **Blackout Verification:** Powered off both `SinghVH1` and `SinghVH2` locally (`192.168.10.50` unreachable). Verified `SinghHRApp-test` remained reachable via RDP and served the IIS HR Portal independently from Azure.
4. **Teardown:** Powered local cluster nodes back on, disassociated and deleted `pip-singhhrapp-test`, and executed **Cleanup test failover** to return Azure compute spend to ₹0.

---

## 3. Drill B: Full Unplanned Failover, Commit, Reverse Replicate & Failback
1. **Unplanned Failover & Cutover:** Executed live **Failover** to `VNet-Singh-DR`, attached a Public IP (`172.128.32.200`), updated the IIS site binding from `192.168.10.50` to `*` (All Unassigned), and verified live external HTTP (`Port 80`) and RDP (`Port 3389`) access.
2. **Commit & Reverse Replication:** Ran **Commit** on the recovery point and initiated **Reverse replicate** (`Azure → Singh-HyperV-Cluster`), syncing disk changes back down to `Cluster Disk 2` (CSV).
3. **Planned Failback & Re-Protection:** Detached the temporary Public IP, executed **Planned Failover** back to `Singh-HyperV-Cluster` with pre-failover data synchronization, committed the failback, deleted the cloud VM and unattached Public IP, and re-enabled forward protection (`On-Premises → Azure`).
