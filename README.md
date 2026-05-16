# 🔧 DVSwitch Database Update Source Fix

<div align="center">

![DVSwitch](https://img.shields.io/badge/DVSwitch-Database%20Fix-blue?style=for-the-badge)
![ASL3](https://img.shields.io/badge/ASL3-Compatible-success?style=for-the-badge)
![Debian 13](https://img.shields.io/badge/Debian-13-red?style=for-the-badge)
![Safe Patch](https://img.shields.io/badge/Patch-Surgical-orange?style=for-the-badge)
![Rollback](https://img.shields.io/badge/Rollback-Protected-important?style=for-the-badge)

### Repair outdated DVSwitch database update sources for YSF and TGIF

</div>

---

# 📌 What This Script Fixes

Modern DVSwitch installs using:

* `SCRIPT_VERSION="1.6.2"`
* `SCRIPT_VERSION="1.6.3"`

contain outdated database update source code inside:

```bash
/opt/MMDVM_Bridge/dvswitch.sh
```

This causes issues such as:

```text
Warning, download failure
Error, YSFHosts.txt file does not seem to be valid
Error, TGList_TGIF.txt file does not seem to exist
```

This script safely patches the outdated update logic while preserving the rest of the stock DVSwitch behavior.

---

# ✅ What Gets Fixed

## 🔹 YSF Database Update Fix

Repairs outdated Pi-Star download references:

### Old / Broken

```bash
YSFHosts.txt
http://www.pistar.uk/downloads/
```

### Updated / Working

```bash
YSF_Hosts.txt
https://www.pistar.uk/downloads/
```

---

## 🔹 TGIF Database Update Fix

Repairs the obsolete TGIF download logic.

### Old / Broken

```bash
TGList_TGIF.txt
```

### Updated / Working

Uses:

```text
https://api.tgif.network/dmr/talkgroups/csv
```

---

# 🛡️ Safety Features

✅ Protected original backup (never overwritten)

✅ Timestamped per-run backups

✅ Version checking before patching

✅ Patch verification before modification

✅ Refuses unsupported versions

✅ Bash syntax validation after patching

✅ Surgical modifications only

---

# ✅ Compatible Versions

| DVSwitch Script Version | Supported                |
| ----------------------- | ------------------------ |
| 1.6.2                   | ✅ Yes                    |
| 1.6.3                   | ✅ Yes                    |
| Other Versions          | ❌ Refused Until Verified |

---

# 🚀 Installation

## 1️⃣ Download the Repository

```bash
git clone https://github.com/ke2hni/dvswitch-db-update-fix.git
```

---

## 2️⃣ Enter the Folder

```bash
cd dvswitch-db-update-fix
```

---

## 3️⃣ Make the Script Executable

```bash
chmod +x dvswitch-db-update-fix.sh
```

---

## 4️⃣ Run the Script

```bash
sudo ./dvswitch-db-update-fix.sh
```

---

# 🖥️ Script Menu

```text
DVSwitch database update source fix

1 = Apply database update source fixes
2 = Restore protected original dvswitch.sh
3 = Show status
0 = Exit
```

---

# 🔍 What The Script Checks

Before patching, the script verifies:

* `SCRIPT_VERSION`
* stale YSF update logic
* stale TGIF update logic
* outdated HTTP download URLs
* existing backups
* patch status

If the issues are already fixed, the script safely exits without modifying the file.

---

# 📂 Backups

## Protected Original Backup

```bash
/opt/MMDVM_Bridge/dvswitch.sh.dvs-dbfix-original
```

This file is created once and never overwritten.

---

## Per-Run Backup

```bash
/opt/MMDVM_Bridge/dvswitch.sh.dvs-dbfix-backup-YYYYMMDD-HHMMSS
```

Created every time the patch is applied.

---

# 🧪 Verified Test Results

Verified on:

* ✅ ASL3
* ✅ Debian 13
* ✅ Raspberry Pi 5
* ✅ Fresh default DVSwitch install
* ✅ DVSwitch 1.6.2
* ✅ DVSwitch 1.6.3

Confirmed working:

```bash
sudo /opt/MMDVM_Bridge/dvswitch.sh update
```

No longer produces:

```text
Error, YSFHosts.txt file does not seem to be valid
Error, TGList_TGIF.txt file does not seem to exist
```

---

# ⚠️ Important Notes

This project intentionally:

* does NOT rewrite major DVSwitch logic
* does NOT alter Analog_Bridge behavior
* does NOT modify mode switching
* does NOT modify dashboard files
* does NOT modify tuning logic

This patch ONLY repairs outdated database update source handling.

---

# 📡 Related DVSwitch Components

This patch affects database downloads used by:

* YSFGateway
* TGIF talkgroup processing
* Mobile client node lists
* DVSwitch helper functions
* Database update routines

---

# 🔄 Restore Original File

To restore the untouched original:

```bash
sudo ./dvswitch-db-update-fix.sh
```

Choose:

```text
2 = Restore protected original dvswitch.sh
```

---

# 📜 License

This project modifies locally installed DVSwitch helper scripts for compatibility and maintenance purposes.

Use at your own risk.

Always keep backups.

---

<div align="center">

## 📻 DVSwitch • ASL3 • Debian 13 • Raspberry Pi

### Surgical Fixes • Safe Rollback • Minimal Changes

</div>
