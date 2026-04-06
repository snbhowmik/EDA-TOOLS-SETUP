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
XILINX_VERSION="2025.1"

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

# Installer binary: looks in sysadmin's Downloads, or accept a path argument
INSTALLER_BIN="${1:-${SYSADMIN_HOME}/Downloads/FPGAs_AdaptiveSoCs_Unified_SDI_${XILINX_VERSION}_0530_0145_Lin64.bin}"

XILINX_VER_ROOT="${XILINX_ROOT}/${XILINX_VERSION}"
STUDENT_HOME="/home/${STUDENT_USER}"
BASHRC="${STUDENT_HOME}/.bashrc"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 : Run Xilinx Installer  (interactive GUI)
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 1: Running Xilinx Installer"

if [[ -d "${XILINX_VER_ROOT}/Vivado" ]]; then
    warn "Vivado ${XILINX_VERSION} already found at ${XILINX_VER_ROOT} — skipping installer."
else
    if [[ ! -f "$INSTALLER_BIN" ]]; then
        error "Installer not found: $INSTALLER_BIN\n  Place the .bin file in ${SYSADMIN_HOME}/Downloads/ or pass its path:\n  sudo bash $0 /path/to/installer.bin"
    fi
    chmod 777 "$INSTALLER_BIN"
    info "Launching installer → install to: ${XILINX_ROOT}"
    info "(The installer GUI will open — follow the on-screen wizard.)"
    "$INSTALLER_BIN"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 : Fix settings64.sh paths  (/tools/Xilinx → /opt/Xilinx)
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 2: Fixing settings64.sh Paths"

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
# STEP 4 : Copy .desktop shortcuts to system applications
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 4: Installing .desktop Shortcuts"

DESKTOP_SRC_DIRS=(
    "${XILINX_VER_ROOT}/Vivado/bin"
    "${XILINX_VER_ROOT}/Vitis/bin"
    "${STUDENT_HOME}"
    "/root"
)

INSTALLED_COUNT=0
for dir in "${DESKTOP_SRC_DIRS[@]}"; do
    if compgen -G "${dir}/*.desktop" > /dev/null 2>&1; then
        cp "${dir}"/*.desktop /usr/share/applications/
        INSTALLED_COUNT=$(( INSTALLED_COUNT + $(ls "${dir}"/*.desktop 2>/dev/null | wc -l) ))
        info "Copied .desktop files from: $dir"
    fi
done

[[ $INSTALLED_COUNT -eq 0 ]] && warn "No .desktop files found — create them manually if needed."

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 : Install USB Cable Drivers
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
echo -e "  Install path : ${XILINX_VER_ROOT}"
echo -e "  Student env  : ${BASHRC}"
echo ""
echo -e "  ${YELLOW}To activate the environment now, run as ${STUDENT_USER}:${NC}"
echo -e "    source ~/.bashrc"
echo ""
echo -e "  ${YELLOW}Verify Vivado:${NC}"
echo -e "    vivado -version"
echo ""
