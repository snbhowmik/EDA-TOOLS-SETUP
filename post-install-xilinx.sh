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
#  Two supported installer types, checked in this order:
#   A) Explicit path argument    →  sudo bash post-install-xilinx.sh /path/to/file
#   B) Online/unified .bin       →  ~/Downloads/FPGAs_AdaptiveSoCs_...Lin64.bin
#   C) Offline installer xsetup  →  ~/Documents/FPGA.../xsetup
#
#  Both installer types must be launched as root (sudo already provides this).
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 1: Xilinx Installer"

if [[ "$ALREADY_INSTALLED" == true ]]; then
    info "Skipping installer — existing installation was detected in pre-check."
else
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

    # ── Launch ────────────────────────────────────────────────────────────────
    chmod 755 "${INSTALLER_TO_RUN}"

    if [[ "$INSTALLER_TYPE" == "xsetup" ]]; then
        info "Launching offline installer (xsetup) as root — installing to ${XILINX_ROOT}"
        info "(The installer GUI will open — follow the on-screen wizard.)"
        cd "$(dirname "${INSTALLER_TO_RUN}")"
        ./xsetup
        cd - > /dev/null
    else
        info "Launching .bin installer as root — installing to ${XILINX_ROOT}"
        info "(The installer GUI will open — follow the on-screen wizard.)"
        "${INSTALLER_TO_RUN}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 : Relocate install directories into /opt/Xilinx/ if needed
#
#  The Xilinx installer creates these under whatever root it ran as:
#    2025.2/       ← versioned dir (contains Vivado, Vitis, etc.)
#    DocNav/       ← documentation browser
#    xic/          ← Xilinx information centre
#    .xinstall/    ← installer metadata
#
#  All of these need to end up under /opt/Xilinx/.
#  OLD_INSTALL_PREFIX tracks where they came from, used in Step 3 to fix paths.
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 2: Relocating to /opt/Xilinx/"

OLD_INSTALL_PREFIX=""   # will be set below if a move is needed

if [[ -d "${XILINX_VER_ROOT}" ]]; then
    info "Version directory already at correct location: ${XILINX_VER_ROOT}"
    # Still move companion dirs if they're loose under /opt
    OLD_INSTALL_PREFIX="/opt"
else
    info "${XILINX_VER_ROOT} not present — checking /opt/ for installer output ..."

    if [[ -d "/opt/${XILINX_VERSION}" ]]; then
        OLD_INSTALL_PREFIX="/opt"
        mkdir -p "${XILINX_ROOT}"

        # Move the versioned dir (e.g. 2025.2 → /opt/Xilinx/2025.2)
        info "Moving /opt/${XILINX_VERSION} → ${XILINX_VER_ROOT}"
        mv "/opt/${XILINX_VERSION}" "${XILINX_VER_ROOT}"
    else
        error "Cannot find /opt/${XILINX_VERSION} or ${XILINX_VER_ROOT}.\n  Verify the installer completed successfully, then check /opt/ manually."
    fi
fi

# Move companion directories (DocNav, xic, .xinstall) if still under /opt/
mkdir -p "${XILINX_ROOT}"
for dir in "DocNav" "xic" ".xinstall"; do
    if [[ -d "/opt/${dir}" ]]; then
        info "Moving /opt/${dir} → ${XILINX_ROOT}/${dir}"
        mv "/opt/${dir}" "${XILINX_ROOT}/${dir}"
    elif [[ -d "${XILINX_ROOT}/${dir}" ]]; then
        info "${dir} already under ${XILINX_ROOT}/ — OK"
    else
        warn "${dir} not found under /opt/ or ${XILINX_ROOT}/ — skipping."
    fi
done

info "Final layout under ${XILINX_ROOT}/:"
ls "${XILINX_ROOT}/"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 : Patch settings64.sh — fix all hardcoded paths
#
#  After relocation, any path baked into settings64.sh that points to the
#  old install location is broken. We patch two possible wrong prefixes:
#
#   /opt/2025.2   → /opt/Xilinx/2025.2   (installer ran to /opt directly)
#   /tools/Xilinx → /opt/Xilinx          (Xilinx's default build-time path)
#
#  The file is shown before and after so you can verify the changes.
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 3: Patching settings64.sh Files"

SETTINGS_FILES=(
    "${XILINX_VER_ROOT}/Vivado/settings64.sh"
    "${XILINX_VER_ROOT}/Vitis/settings64.sh"
    "${XILINX_VER_ROOT}/Model_Composer/settings64.sh"
    "${XILINX_VER_ROOT}/PDM/settings64.sh"
)

for f in "${SETTINGS_FILES[@]}"; do
    if [[ ! -f "$f" ]]; then
        warn "Not found (tool may not be installed): $f — skipping."
        continue
    fi

    info "Patching: $f"
    CHANGED=false

    # ── Replace /opt/VERSION with /opt/Xilinx/VERSION ────────────────────────
    # This is the path baked in when the installer ran to /opt/ instead of /opt/Xilinx/
    if grep -q "/opt/${XILINX_VERSION}" "$f"; then
        sed -i "s|/opt/${XILINX_VERSION}|${XILINX_VER_ROOT}|g" "$f"
        info "  Replaced: /opt/${XILINX_VERSION} → ${XILINX_VER_ROOT}"
        CHANGED=true
    fi

    # ── Replace /tools/Xilinx with /opt/Xilinx ───────────────────────────────
    # This is Xilinx's own build-time default that sometimes survives into release
    if grep -q "/tools/Xilinx" "$f"; then
        sed -i 's|/tools/Xilinx|/opt/Xilinx|g' "$f"
        info "  Replaced: /tools/Xilinx → /opt/Xilinx"
        CHANGED=true
    fi

    # ── Any other non-/opt/Xilinx absolute path referencing the version ───────
    # Catches edge cases like /home/user/Xilinx/... or custom installer prefixes
    OTHER_WRONG=$(grep -oP '["\s]/[^"\s]*'"${XILINX_VERSION}"'[^"\s]*' "$f" \
        | grep -v "/opt/Xilinx" | head -n 3 || true)
    if [[ -n "$OTHER_WRONG" ]]; then
        warn "  Unexpected path references found in $f — review manually:"
        echo "$OTHER_WRONG" | while read -r line; do warn "    $line"; done
    fi

    if [[ "$CHANGED" == false ]]; then
        info "  No path changes needed — already correct or uses a different scheme."
    fi

    # ── Show current XILINX_DIR line so you can verify ───────────────────────
    XILINX_DIR_LINE=$(grep -m1 "XILINX" "$f" 2>/dev/null || echo "  (no XILINX variable found)")
    info "  Verify → ${XILINX_DIR_LINE}"
done

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 : Write .bashrc entries for the student user
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 4: Configuring Student .bashrc"

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
# STEP 5 : Copy .desktop shortcuts from root's Desktop → student's Desktop
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 5: Installing .desktop Shortcuts for Student"

ROOT_DESKTOP="/root/Desktop"
STUDENT_DESKTOP="${STUDENT_HOME}/Desktop"

# Ensure the student's Desktop directory exists
mkdir -p "$STUDENT_DESKTOP"
chown "${STUDENT_USER}:${STUDENT_USER}" "$STUDENT_DESKTOP"

if compgen -G "${ROOT_DESKTOP}/*.desktop" > /dev/null 2>&1; then
    cp "${ROOT_DESKTOP}"/*.desktop "$STUDENT_DESKTOP/"
    chown "${STUDENT_USER}:${STUDENT_USER}" "${STUDENT_DESKTOP}"/*.desktop
    chmod 755 "${STUDENT_DESKTOP}"/*.desktop
    DESKTOP_COUNT=$(ls "${ROOT_DESKTOP}"/*.desktop 2>/dev/null | wc -l)
    info "Copied ${DESKTOP_COUNT} .desktop file(s): /root/Desktop → ${STUDENT_DESKTOP}"
else
    warn "No .desktop files found in /root/Desktop — skipping."
    warn "If the installer created shortcuts elsewhere, copy them manually to:"
    warn "  ${STUDENT_DESKTOP}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 : Install USB Cable Drivers
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 6: Installing Xilinx USB Cable Drivers"

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
echo ""
echo -e "  ${YELLOW}To activate the environment now, run as ${STUDENT_USER}:${NC}"
echo -e "    source ~/.bashrc"
echo ""
echo -e "  ${YELLOW}Verify Vivado:${NC}"
echo -e "    vivado -version"
echo ""
