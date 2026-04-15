#!/bin/bash
# =============================================================================
#  POST-INSTALL SCRIPT — XILINX (Vivado / Vitis / Model Composer / PDM)
#  Purpose : Configure environment AFTER the Xilinx unified installer has run.
#  Run as  : sysadmin, using sudo  →  sudo bash post-install-xilinx.sh
#  Assumes : pre-install-config.sh was already run.
#            Xilinx suite was installed to /opt/Xilinx.
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION  ← edit to match your environment
# ─────────────────────────────────────────────────────────────────────────────
MACHINE_NUMBER="01"
SYSADMIN_USER="sysadmin309${MACHINE_NUMBER}"
STUDENT_USER="srmist309${MACHINE_NUMBER}"

XILINX_ROOT="/opt/Xilinx"
XILINX_VERSION="2025.2"

LICENSE_SERVER_IP="14.139.1.126"
LICENSE_SERVER_HOSTNAME="c2s.cdacb.in"
LICENSE_PORT="2100"

# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────
GREEN="\033[1;32m"; YELLOW="\033[1;33m"; RED="\033[1;31m"; NC="\033[0m"
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section() { echo -e "\n${GREEN}══════════════════════════════════════════${NC}"; \
            echo -e "${GREEN}  $*${NC}"; \
            echo -e "${GREEN}══════════════════════════════════════════${NC}\n"; }

# Must be run via sudo from the sysadmin account
[[ $EUID -ne 0 ]] && error "Run this script with sudo:\n  sudo bash $0"
[[ -z "${SUDO_USER:-}" ]] && error "Do not run as root directly. Log in as ${SYSADMIN_USER} and run:\n  sudo bash $0"
[[ "$SUDO_USER" != "$SYSADMIN_USER" ]] && \
    warn "Expected SUDO_USER=${SYSADMIN_USER} but got '${SUDO_USER}'. Continuing anyway."

SYSADMIN_HOME="/home/${SUDO_USER}"
info "Running as: ${SUDO_USER} (via sudo) — home: ${SYSADMIN_HOME}"

XILINX_VER_ROOT="${XILINX_ROOT}/${XILINX_VERSION}"
STUDENT_HOME="/home/${STUDENT_USER}"
BASHRC="${STUDENT_HOME}/.bashrc"

# Known .bin installer filename
INSTALLER_BIN_NAME="FPGAs_AdaptiveSoCs_Unified_SDI_${XILINX_VERSION}_1114_2157_Lin64.bin"
INSTALLER_BIN="${SYSADMIN_HOME}/Downloads/${INSTALLER_BIN_NAME}"

# Exact directory names Xilinx 2025.x creates directly under the install root
# (confirmed from actual installation output)
XILINX_INSTALLER_DIRS=("${XILINX_VERSION}" "DocNav" "xic" ".xinstall")

# ─────────────────────────────────────────────────────────────────────────────
# PRE-CHECK : Scan all possible locations for an existing installation
#
#  Checks (in order):
#   1. /opt/Xilinx/2025.2/   ← correct final location
#   2. /opt/2025.2/           ← installer dumped version dir directly under /opt
#   3. /opt/DocNav, /opt/xic  ← other installer-created dirs loose under /opt
#
#  If anything is found, skip the installer and go straight to path correction.
# ─────────────────────────────────────────────────────────────────────────────
section "PRE-CHECK: Scanning for Existing Xilinx Installation"

ALREADY_INSTALLED=false

if [[ -d "${XILINX_VER_ROOT}" ]]; then
    info "Found existing installation at: ${XILINX_VER_ROOT}"
    ALREADY_INSTALLED=true
elif [[ -d "/opt/${XILINX_VERSION}" ]]; then
    info "Found existing installation at: /opt/${XILINX_VERSION} (needs relocation)"
    ALREADY_INSTALLED=true
elif [[ -d "/opt/DocNav" ]] || [[ -d "/opt/xic" ]]; then
    info "Found Xilinx tool directories under /opt/ (needs relocation)"
    ALREADY_INSTALLED=true
fi

if [[ "$ALREADY_INSTALLED" == true ]]; then
    warn "Existing installation detected — skipping installer. Proceeding to path correction."
else
    info "No existing installation found — installer will be launched."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 : Run installer  (skipped if installation already exists)
#
#  ⚠️  CRITICAL — WHEN THE INSTALLER GUI OPENS:
#       Set the installation directory to exactly:
#
#            /opt/Xilinx
#
#       NOT /opt  (this causes internal classpath corruption)
#       NOT /home/...  (tools will not be accessible system-wide)
#
#  Vivado is NOT relocatable after install. Paths are baked into internal
#  JVM configs, JAR references, and TCL scripts. Installing to the wrong
#  location and moving afterwards will break the tool.
#
#  Two supported installer types (auto-detected in order):
#   A) Explicit path argument    →  sudo bash post-install-xilinx.sh /path/to/file
#   B) Online/unified .bin       →  ~/Downloads/FPGAs_AdaptiveSoCs_...Lin64.bin
#   C) Offline installer xsetup  →  ~/Documents/FPGA.../xsetup
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 1: Xilinx Installer"

if [[ "$ALREADY_INSTALLED" == true ]]; then
    info "Skipping installer — existing installation was detected in pre-check."
else
    echo -e "\n${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ⚠️  IMPORTANT — READ BEFORE CLICKING NEXT IN THE INSTALLER  ${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  When the installer asks for an installation directory, set it to:${NC}"
    echo -e ""
    echo -e "${GREEN}        /opt/Xilinx${NC}"
    echo -e ""
    echo -e "${YELLOW}  Do NOT use /opt  — this breaks internal JVM classpaths.${NC}"
    echo -e "${YELLOW}  Do NOT move the installation after it completes.${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}\n"

    read -rp "Press ENTER to open the installer when you are ready... "

    INSTALLER_TO_RUN=""
    INSTALLER_TYPE=""

    # ── A) Explicit path passed as argument ──────────────────────────────────
    if [[ -n "${1:-}" ]]; then
        [[ ! -f "$1" ]] && error "Specified installer not found: $1"
        INSTALLER_TO_RUN="$1"
        [[ "$1" == *xsetup* ]] && INSTALLER_TYPE="xsetup" || INSTALLER_TYPE="bin"
        info "Using explicitly specified installer: ${INSTALLER_TO_RUN}"

    # ── B) Auto-detect: .bin in sysadmin's Downloads ─────────────────────────
    elif [[ -f "${INSTALLER_BIN}" ]]; then
        INSTALLER_TO_RUN="${INSTALLER_BIN}"
        INSTALLER_TYPE="bin"
        info "Found .bin installer: ${INSTALLER_TO_RUN}"

    # ── C) Auto-detect: offline xsetup under ~/Documents/FPGA*/ ─────────────
    else
        info ".bin not found in Downloads — searching for offline xsetup in Documents ..."
        XSETUP_FOUND=$(find "${SYSADMIN_HOME}/Documents" -maxdepth 3 \
            -iname "xsetup" -type f 2>/dev/null | head -n 1)

        if [[ -n "$XSETUP_FOUND" ]]; then
            INSTALLER_TO_RUN="$XSETUP_FOUND"
            INSTALLER_TYPE="xsetup"
            info "Found offline installer: ${INSTALLER_TO_RUN}"
        else
            error "No installer found. Expected one of:\n\
  A) ${INSTALLER_BIN}\n\
  B) ${SYSADMIN_HOME}/Documents/FPGA.../xsetup\n\
\n\
  Or pass the path explicitly:\n\
     sudo bash $0 /path/to/installer"
        fi
    fi

    chmod 755 "${INSTALLER_TO_RUN}"

    if [[ "$INSTALLER_TYPE" == "xsetup" ]]; then
        info "Launching offline installer (xsetup) as root — install to: ${XILINX_ROOT}"
        cd "$(dirname "${INSTALLER_TO_RUN}")"
        ./xsetup
        cd - > /dev/null
    else
        info "Launching .bin installer as root — install to: ${XILINX_ROOT}"
        "${INSTALLER_TO_RUN}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 : Move companion directories into /opt/Xilinx/ if needed
#
#  If the installer was pointed at /opt/ instead of /opt/Xilinx/, the
#  companion directories (DocNav, xic, .xinstall) will land under /opt/.
#  We move ONLY these directories — no files inside them are touched.
#
#  ⚠️  The main version directory (2025.2/) is NOT moved here.
#      If it landed under /opt/2025.2 instead of /opt/Xilinx/2025.2,
#      you must REINSTALL — do not move it, as internal paths are baked in.
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 2: Checking Companion Directory Locations"

# Verify the main version directory is in the right place before continuing
if [[ ! -d "${XILINX_VER_ROOT}" ]]; then
    echo -e "\n${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ✗  Installation not found at: ${XILINX_VER_ROOT}${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  If the installer ran to /opt/ instead of /opt/Xilinx/:${NC}"
    echo -e "${YELLOW}  → You must reinstall. Moving Vivado after install breaks it.${NC}"
    echo -e ""
    echo -e "${YELLOW}  Clean up and reinstall:${NC}"
    echo -e "    sudo rm -rf /opt/${XILINX_VERSION} /opt/DocNav /opt/xic /opt/.xinstall"
    echo -e "    sudo rm -rf ${XILINX_ROOT}"
    echo -e "    sudo bash $0"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}\n"
    exit 1
fi

info "Main installation confirmed at: ${XILINX_VER_ROOT}"

# Move companion directories only — these are safe to relocate (no baked-in paths)
mkdir -p "${XILINX_ROOT}"
for dir in "DocNav" "xic" ".xinstall"; do
    if [[ -d "/opt/${dir}" ]]; then
        info "Moving companion dir: /opt/${dir} → ${XILINX_ROOT}/${dir}"
        mv "/opt/${dir}" "${XILINX_ROOT}/${dir}"
    elif [[ -d "${XILINX_ROOT}/${dir}" ]]; then
        info "${dir} already at ${XILINX_ROOT}/${dir} — OK"
    else
        warn "${dir} not found — may not have been installed."
    fi
done

info "Final layout under ${XILINX_ROOT}/:"
ls "${XILINX_ROOT}/"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 : Write .bashrc entries for the student user
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 3: Configuring Student .bashrc"

[[ -f "$BASHRC" ]] || error ".bashrc not found for user $STUDENT_USER at $BASHRC"

BASHRC_BLOCK="
# ── XILINX LICENSE AND ENVIRONMENT ────────────────────────────────────────
# Added by post-install-xilinx.sh — do not edit manually
"

add_source_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        BASHRC_BLOCK+="source ${file}\n"
    else
        warn "settings file not found, skipping source: $file"
    fi
}

add_source_if_exists "${XILINX_VER_ROOT}/Vitis/settings64.sh"
add_source_if_exists "${XILINX_VER_ROOT}/Vivado/settings64.sh"
add_source_if_exists "${XILINX_VER_ROOT}/Model_Composer/settings64.sh"
add_source_if_exists "${XILINX_VER_ROOT}/PDM/settings64.sh"

BASHRC_BLOCK+="
export LM_LICENSE_FILE=${LICENSE_PORT}@${LICENSE_SERVER_IP}
export XILINXD_LICENSE_FILE=${LICENSE_PORT}@${LICENSE_SERVER_IP}

# Fallback to hostname-based license server
export LM_LICENSE_FILE=\${LM_LICENSE_FILE}:${LICENSE_PORT}@${LICENSE_SERVER_HOSTNAME}
export XILINXD_LICENSE_FILE=\${XILINXD_LICENSE_FILE}:${LICENSE_PORT}@${LICENSE_SERVER_HOSTNAME}

export PATH=${XILINX_VER_ROOT}/Vitis/bin:\$PATH
export PATH=${XILINX_VER_ROOT}/Vivado/bin:\$PATH
# ──────────────────────────────────────────────────────────────────────────
"

MARKER="# ── XILINX LICENSE AND ENVIRONMENT"
if grep -q "$MARKER" "$BASHRC"; then
    warn "Xilinx block already present in $BASHRC — skipping."
else
    printf "%b" "$BASHRC_BLOCK" >> "$BASHRC"
    chown "${STUDENT_USER}:${STUDENT_USER}" "$BASHRC"
    info "Xilinx environment block appended to $BASHRC"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 : Install .desktop shortcuts
#
#  Two destinations are required on RHEL 8 / GNOME:
#   A) /usr/share/applications/   ← makes tools appear in the GNOME app menu
#   B) ~/Desktop/                 ← puts clickable icons on student's desktop
#
#  Source: /root/Desktop/*.desktop  (created by the Xilinx installer)
#
#  The .desktop files also contain hardcoded /opt/VERSION paths in their
#  Exec= and Icon= lines — those are patched here too.
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 4: Installing .desktop Shortcuts"

ROOT_DESKTOP="/root/Desktop"
STUDENT_DESKTOP="${STUDENT_HOME}/Desktop"
SYSTEM_APPS="/usr/share/applications"

mkdir -p "$STUDENT_DESKTOP"
chown "${STUDENT_USER}:${STUDENT_USER}" "$STUDENT_DESKTOP"

if ! compgen -G "${ROOT_DESKTOP}/*.desktop" > /dev/null 2>&1; then
    warn "No .desktop files found in /root/Desktop."
    warn "The installer may have placed them elsewhere. Check:"
    warn "  find /root -name '*.desktop' 2>/dev/null"
    warn "  find ${XILINX_VER_ROOT} -name '*.desktop' 2>/dev/null"
else
    DESKTOP_COUNT=0

    for src in "${ROOT_DESKTOP}"/*.desktop; do
        fname="$(basename "$src")"

        # ── Patch Exec= and Icon= paths in each .desktop file ────────────────
        # The installer bakes /opt/VERSION into these lines; fix them in place
        # before copying so both destinations get the corrected version.

        if grep -q "/opt/${XILINX_VERSION}" "$src"; then
            sed -i "s|/opt/${XILINX_VERSION}|${XILINX_VER_ROOT}|g" "$src"
            info "Patched Exec/Icon paths in: $fname"
        fi
        if grep -q "/opt/DocNav" "$src"; then
            sed -i "s|/opt/DocNav|${XILINX_ROOT}/DocNav|g" "$src"
        fi
        if grep -q "/opt/xic" "$src"; then
            sed -i "s|/opt/xic|${XILINX_ROOT}/xic|g" "$src"
        fi

        # ── A) Copy to /usr/share/applications/ (GNOME app menu) ─────────────
        cp "$src" "${SYSTEM_APPS}/${fname}"
        chmod 644 "${SYSTEM_APPS}/${fname}"
        info "Installed to app menu: ${SYSTEM_APPS}/${fname}"

        # ── B) Copy to student's Desktop ──────────────────────────────────────
        cp "$src" "${STUDENT_DESKTOP}/${fname}"
        chown "${STUDENT_USER}:${STUDENT_USER}" "${STUDENT_DESKTOP}/${fname}"
        # Mark as trusted so GNOME shows it as a launcher, not a text file
        chmod 755 "${STUDENT_DESKTOP}/${fname}"

        DESKTOP_COUNT=$(( DESKTOP_COUNT + 1 ))
    done

    info "Installed ${DESKTOP_COUNT} shortcut(s) to app menu and student Desktop."

    # ── Rebuild GNOME app menu database ───────────────────────────────────────
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "${SYSTEM_APPS}"
        info "GNOME app menu database updated."
    else
        warn "update-desktop-database not found — install desktop-file-utils if apps don't appear."
    fi

    # ── Mark student's desktop icons as trusted (RHEL 8 GNOME requirement) ───
    # Without this, GNOME shows a shield icon and won't launch the app on click.
    if command -v gio &>/dev/null; then
        for f in "${STUDENT_DESKTOP}"/*.desktop; do
            gio set "$f" metadata::trusted true 2>/dev/null && \
                info "Marked trusted: $(basename "$f")" || true
        done
    else
        warn "gio not available — desktop icons may show as untrusted."
        warn "Student can right-click each icon and choose 'Allow Launching'."
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 : Install USB Cable Drivers
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 5: Installing Xilinx USB Cable Drivers"

DRIVER_SCRIPT="${XILINX_VER_ROOT}/data/xicom/cable_drivers/lin64/install_script/install_drivers/install_drivers"

if [[ -f "$DRIVER_SCRIPT" ]]; then
    chmod 777 "$DRIVER_SCRIPT"
    "$DRIVER_SCRIPT"
    info "USB cable drivers installed."
else
    warn "Driver script not found: $DRIVER_SCRIPT"
    warn "Install drivers manually after verifying the Xilinx install path."
fi

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
section "XILINX POST-INSTALL COMPLETE"
echo -e "  Install path   : ${XILINX_VER_ROOT}"
echo -e "  Student env    : ${BASHRC}"
echo -e "  Student Desktop: ${STUDENT_DESKTOP}"
echo -e "  App menu       : ${SYSTEM_APPS}"
echo ""
echo -e "  ${YELLOW}To activate the environment now, run as ${STUDENT_USER}:${NC}"
echo -e "    source ~/.bashrc"
echo ""
echo -e "  ${YELLOW}Verify Vivado:${NC}"
echo -e "    vivado -version"
echo ""
echo -e "  ${YELLOW}If apps still don't appear in GNOME menu:${NC}"
echo -e "    sudo update-desktop-database /usr/share/applications"
echo -e "    Log out and back in as ${STUDENT_USER}"
echo ""
