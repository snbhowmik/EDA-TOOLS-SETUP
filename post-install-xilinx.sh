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

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 : Detect and run the Xilinx installer
#
#  Two supported installer types, checked in this order:
#
#  A) Online/unified .bin  →  ~/Downloads/FPGAs_AdaptiveSoCs_...Lin64.bin
#  B) Offline installer    →  ~/Documents/FPGA.../xsetup
#
#  Both must be launched as root (which sudo already provides).
#  Pass an explicit path as the first argument to override auto-detection:
#    sudo bash post-install-xilinx.sh /path/to/installer.bin
#    sudo bash post-install-xilinx.sh /path/to/xsetup
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 1: Detecting and Running Xilinx Installer"

if [[ -d "${XILINX_VER_ROOT}/Vivado" ]]; then
    warn "Vivado ${XILINX_VERSION} already found at ${XILINX_VER_ROOT} — skipping installer."
else
    INSTALLER_TO_RUN=""
    INSTALLER_TYPE=""

    # ── If an explicit path was passed as argument, use it directly ──────────
    if [[ -n "${1:-}" ]]; then
        if [[ ! -f "$1" ]]; then
            error "Specified installer not found: $1"
        fi
        INSTALLER_TO_RUN="$1"
        [[ "$1" == *xsetup* ]] && INSTALLER_TYPE="xsetup" || INSTALLER_TYPE="bin"
        info "Using explicitly specified installer: ${INSTALLER_TO_RUN}"

    # ── Auto-detect: try .bin in Downloads first ─────────────────────────────
    elif [[ -f "${INSTALLER_BIN}" ]]; then
        INSTALLER_TO_RUN="${INSTALLER_BIN}"
        INSTALLER_TYPE="bin"
        info "Found .bin installer: ${INSTALLER_TO_RUN}"

    # ── Auto-detect: search for xsetup under ~/Documents/FPGA*/ ─────────────
    else
        info ".bin installer not found in Downloads — searching for offline xsetup in Documents ..."
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

    # ── Launch the installer ──────────────────────────────────────────────────
    chmod 755 "${INSTALLER_TO_RUN}"

    if [[ "$INSTALLER_TYPE" == "xsetup" ]]; then
        info "Launching offline installer (xsetup) — running as root for /opt write access."
        info "Install to: ${XILINX_ROOT}"
        info "(The installer GUI will open — follow the on-screen wizard.)"
        # xsetup must be run from its own directory
        cd "$(dirname "${INSTALLER_TO_RUN}")"
        ./xsetup
        cd - > /dev/null
    else
        info "Launching .bin installer — running as root for /opt write access."
        info "Install to: ${XILINX_ROOT}"
        info "(The installer GUI will open — follow the on-screen wizard.)"
        "${INSTALLER_TO_RUN}"
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 : Verify install path — move to /opt/Xilinx if needed
#
#  The Xilinx installer sometimes places tool folders directly under /opt/
#  instead of /opt/Xilinx/. This step detects that and corrects it.
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 2: Verifying Installation Path"

# Known top-level directory names the Xilinx installer creates
XILINX_TOOL_DIRS=("Vivado" "Vitis" "Model_Composer" "PDM" "Vitis_HLS" "DocNav")

if [[ -d "${XILINX_VER_ROOT}" ]]; then
    info "Install already at correct location: ${XILINX_VER_ROOT}"
else
    info "Expected path ${XILINX_VER_ROOT} not found — checking if tools landed directly under /opt/ ..."

    # Look for a versioned directory directly under /opt (e.g. /opt/2025.2)
    if [[ -d "/opt/${XILINX_VERSION}" ]]; then
        info "Found /opt/${XILINX_VERSION} — moving into ${XILINX_ROOT}/"
        mkdir -p "${XILINX_ROOT}"
        mv "/opt/${XILINX_VERSION}" "${XILINX_VER_ROOT}"
        info "Moved: /opt/${XILINX_VERSION} → ${XILINX_VER_ROOT}"

    else
        # Tools may be scattered as /opt/Vivado, /opt/Vitis, etc.
        FOUND_ANY=false
        for tool in "${XILINX_TOOL_DIRS[@]}"; do
            if [[ -d "/opt/${tool}" ]]; then
                FOUND_ANY=true
                info "Found /opt/${tool} — moving into ${XILINX_VER_ROOT}/"
                mkdir -p "${XILINX_VER_ROOT}"
                mv "/opt/${tool}" "${XILINX_VER_ROOT}/${tool}"
                info "Moved: /opt/${tool} → ${XILINX_VER_ROOT}/${tool}"
            fi
        done

        if [[ "$FOUND_ANY" == false ]]; then
            error "Cannot find Xilinx tools under /opt/ or /opt/Xilinx/.\n  Please verify the installer ran successfully and check /opt/ manually."
        fi
    fi

    info "Final install location: ${XILINX_VER_ROOT}"
    ls "${XILINX_VER_ROOT}/"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 : Fix settings64.sh paths  (/tools/Xilinx → /opt/Xilinx)
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 3: Fixing settings64.sh Paths"

SETTINGS_FILES=(
    "${XILINX_VER_ROOT}/Vivado/settings64.sh"
    "${XILINX_VER_ROOT}/Vitis/settings64.sh"
    "${XILINX_VER_ROOT}/Model_Composer/settings64.sh"
    "${XILINX_VER_ROOT}/PDM/settings64.sh"
)

for f in "${SETTINGS_FILES[@]}"; do
    if [[ -f "$f" ]]; then
        if grep -q "/tools/Xilinx" "$f"; then
            sed -i 's|/tools/Xilinx|/opt/Xilinx|g' "$f"
            info "Patched: $f"
        else
            warn "No /tools/Xilinx reference in $f — already correct or different path."
        fi
    else
        warn "File not found (tool may not be installed): $f"
    fi
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
