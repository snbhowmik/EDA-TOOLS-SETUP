# VLSI Lab — EDA Tool Setup Guide
### SRM Institute of Science and Technology — Trichy Campus

---

## Overview

This repo contains three shell scripts that automate the setup of RHEL 8 workstations for EDA tools (Xilinx Vivado/Vitis, Cadence, Synopsys, etc.).

```
pre-install-config.sh       ← Run ONCE on every machine, before any tool install
post-install-xilinx.sh      ← Run AFTER installing Xilinx Vivado/Vitis
post-install-cadence.sh     ← Run AFTER extracting Cadence tool tarballs
lockdown.sh                 ← Run LAST, only after all tools are verified working
```

---

## Quick-Start: Correct Order of Operations

```
1. Install RHEL 8
2. Register with Red Hat Subscription Manager (GUI)
3. sudo bash pre-install-config.sh        ← creates student user + all dependencies
4. Reboot
5a. Install Xilinx   → sudo bash post-install-xilinx.sh
5b. Install Cadence  → sudo bash post-install-cadence.sh
6. Verify all tools work as the student user
7. sudo bash lockdown.sh --dry-run        ← preview restrictions first
8. sudo bash lockdown.sh                  ← apply restrictions
```

If you are setting up **both** Xilinx and Cadence on the same machine, run both post-install scripts (steps 5a and 5b) — they are independent of each other.

---

## Before You Run Any Script

### Edit the machine number
Open each script and set `MACHINE_NUMBER` at the top (e.g. `"01"`, `"12"`, `"30"`).
This controls the username and hostname that are generated.

| Variable | Example value |
|---|---|
| `MACHINE_NUMBER` | `"09"` |
| Admin username | `sysadmin30909` |
| Student username | `srmist30909` |
| Hostname | `vlsilab09.ist.srmtrichy.edu.in` |

---

## Script Reference

---

### `pre-install-config.sh`
**When:** Immediately after a fresh RHEL 8 installation, before anything else.  
**Run as:** `sysadmin` (with sudo)

```bash
sudo bash pre-install-config.sh
```

> **Note:** The sysadmin account is assumed to already exist on every machine. This script only creates the student user. Always run as `sysadmin` using `sudo` — never log in as root directly.

**What it does:**

| Step | Action |
|---|---|
| 1 | Creates the **Student** user (`srmist309xx`) with no sudo access, removes from wheel |
| 2 | Sets the system hostname via `hostnamectl` |
| 3 | Adds the license server entry to `/etc/hosts` |
| 4 | Runs `dnf update`, installs EPEL, enables CodeReady Builder |
| 5 | Downloads and installs RPM Fusion (free + nonfree) |
| 6 | Installs all common EDA dependencies (openssl, libX, glibc, mesa, fonts…) |

**After it finishes:** Reboot the machine before installing any EDA tool.

---

### `post-install-xilinx.sh`
**When:** After the Xilinx Unified Installer has finished and tools are at `/opt/Xilinx`.  
**Run as:** `sysadmin` (with sudo)

```bash
sudo bash post-install-xilinx.sh
# or, if the installer bin is somewhere other than ~/Downloads:
sudo bash post-install-xilinx.sh /path/to/FPGAs_AdaptiveSoCs_....bin
```

**What it does:**

| Step | Action |
|---|---|
| 1 | Runs the Xilinx installer binary (interactive GUI — follow the wizard, install to `/opt/Xilinx`) |
| 2 | Patches `settings64.sh` files: replaces `/tools/Xilinx` → `/opt/Xilinx` in Vivado, Vitis, Model Composer, and PDM |
| 3 | Appends Xilinx environment variables to the student user's `.bashrc` (PATH, `LM_LICENSE_FILE`, `XILINXD_LICENSE_FILE`) |
| 4 | Copies any `.desktop` shortcut files to `/usr/share/applications/` |
| 5 | Installs Xilinx USB cable drivers |

**After it finishes:**
```bash
# Switch to the student user and verify:
su - srmist309xx
source ~/.bashrc
vivado -version
```

---

### `post-install-cadence.sh`
**When:** After downloading the Cadence Analog and Digital tool tarballs from the SharePoint links.  
**Run as:** `sysadmin` (with sudo)

```bash
sudo bash post-install-cadence.sh
```

**What it does:**

| Step | Action |
|---|---|
| 1 | Creates `/home/install` directory with restricted permissions (root:wheel, 750) |
| 2 | Extracts `Analog_RHEL_8.tar.gz` into `/home/install` |
| 3 | Extracts `Digital_RHEL_8.tar.gz` into `/home/install` |
| 4 | Auto-detects the Cadence tool root directory |
| 5 | Appends Cadence environment variables to the student user's `.bashrc` (`CDS_LIC_FILE`, `LM_LICENSE_FILE`, tool `PATH`) |

**Tarballs must be placed in:**
```
/home/sysadmin309xx/Downloads/Analog_RHEL_8.tar.gz
/home/sysadmin309xx/Downloads/Digital_RHEL_8.tar.gz
```
> Download links (SharePoint):  
> Analog Tools: `https://entupletech-my.sharepoint.com/:f:/g/personal/...`  
> Digital Tools: `https://entupletech-my.sharepoint.com/:f:/g/personal/...`

**After it finishes:** Review the PATH entries added to `~/.bashrc` — adjust them to match the actual subdirectory layout of your Cadence tarballs.

---

## User Accounts Summary

| Account | Username | Password | Sudo? | Created by |
|---|---|---|---|---|
| Admin (pre-existing) | `sysadmin309xx` | `Srmist@789` | ✅ Yes | Already on every machine |
| Student | `srmist309xx` | `Student@SRM` | ❌ No | `pre-install-config.sh` |

Replace `xx` with your machine number (e.g. `01`, `15`).

---

### `lockdown.sh`
**When:** LAST — only after every EDA tool is fully installed and verified working as the student user.  
**Run as:** `sysadmin` (with sudo)

```bash
# Always preview first
sudo bash lockdown.sh --dry-run

# Apply when satisfied
sudo bash lockdown.sh
```

**What it does:**

| Step | Action |
|---|---|
| 1 | Sets all home directories to `700` (users can't see each other's files) |
| 2 | Locks down `/media`, `/mnt`, `/srv` to `700` |
| 3 | *(Placeholder)* Student home directory folder-level restrictions |
| 4 | *(Placeholder)* EDA tool directory permissions (read/execute, no write) |
| 5 | Sanity-checks system directories for world-writable permissions |

> Steps 3 and 4 are intentionally left as commented placeholders. Edit the script to define exactly which folders the student should and shouldn't access — this depends on your lab's folder layout and which tools are installed.

**⚠️ Important:** Always verify the student account still works after running lockdown:
```bash
su - srmist309xx
vivado -version   # or whichever tool
```

---

| Detail | Value |
|---|---|
| License server IP | `14.139.1.126` |
| License server hostname | `c2s.cdacb.in` |
| Xilinx port | `2100` |
| Cadence port | `5280` |

To verify connectivity:
```bash
ping 14.139.1.126
telnet 14.139.1.126 2100   # Xilinx
telnet 14.139.1.126 5280   # Cadence
```

---

## Troubleshooting

**dnf update fails with subscription error**
→ Open the Red Hat Subscription Manager GUI and register the machine first.

**`codeready-builder` repo not found**
→ The machine may not be registered. Run `subscription-manager status` to check.

**Vivado/Vitis not found after source .bashrc**
→ Check that the `settings64.sh` path patch worked: `grep opt/Xilinx /opt/Xilinx/2025.1/Vivado/settings64.sh`

**Cadence tools not launching**
→ Check `CDS_LIC_FILE` in `.bashrc` and confirm the license server is reachable on port 5280.

**USB JTAG cable not detected (Xilinx)**
→ Re-run the cable driver installer as root:
```bash
sudo /opt/Xilinx/2025.1/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers
```

---

## For Synopsys (Future)

The `pre-install-config.sh` script already installs all dependencies that Synopsys tools require (openssl, libX, glibc, ksh, etc.). When a Synopsys installer becomes available:
1. Run the installer manually as `sysadmin`.
2. Create a `post-install-synopsys.sh` based on the same pattern as the Xilinx and Cadence scripts — add `.bashrc` environment variables and any path fixes.

---

*Last updated: 2025 | SRM IST Trichy — VLSI Lab Setup*
