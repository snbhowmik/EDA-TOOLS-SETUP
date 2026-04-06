#!/bin/bash
# =============================================================================
#  POST-INSTALL SCRIPT — CADENCE (Analog & Digital EDA Tools)
#  Purpose : Extract and configure Cadence tool tarballs after download.
#  Run as  : sysadmin, using sudo  →  sudo bash post-install-cadence.sh
#  Assumes : pre-install-config.sh was already run.
#            Tarballs are in sysadmin's ~/Downloads folder.
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION  ← edit to match your environment
# ─────────────────────────────────────────────────────────────────────────────
MACHINE_NUMBER="01"
SYSADMIN_USER="sysadmin309${MACHINE_NUMBER}"
STUDENT_USER="srmist309${MACHINE_NUMBER}"

# Tarball filenames (update if your filenames differ)
ANALOG_TARBALL="Analog_RHEL_8.tar.gz"
DIGITAL_TARBALL="Digital_RHEL_8.tar.gz"

# Installation target — all tools extracted here
INSTALL_DIR="/home/install"

# License server
LICENSE_SERVER_IP="14.139.1.126"
LICENSE_SERVER_HOSTNAME="c2s.cdacb.in"
LICENSE_PORT="5280"         # Default Cadence license port — adjust if different

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
DOWNLOADS_DIR="${SYSADMIN_HOME}/Downloads"
info "Running as: ${SUDO_USER} (via sudo) — Downloads: ${DOWNLOADS_DIR}"

STUDENT_HOME="/home/${STUDENT_USER}"
BASHRC="${STUDENT_HOME}/.bashrc"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 1 : Create Installation Directory
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 1: Preparing Installation Directory"

if [[ -d "$INSTALL_DIR" ]]; then
    warn "$INSTALL_DIR already exists — continuing."
else
    mkdir -p "$INSTALL_DIR"
    info "Created: $INSTALL_DIR"
fi

# Restrict access — only root and sysadmin group can enter
chmod 750 "$INSTALL_DIR"
chown root:wheel "$INSTALL_DIR"
info "Permissions on $INSTALL_DIR set to 750 (root:wheel)"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 : Extract Analog Tools
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 2: Extracting Analog Tools"

ANALOG_PATH="${DOWNLOADS_DIR}/${ANALOG_TARBALL}"

if [[ -f "$ANALOG_PATH" ]]; then
    info "Extracting $ANALOG_TARBALL → $INSTALL_DIR …"
    tar -xzvf "$ANALOG_PATH" -C "$INSTALL_DIR"
    info "Analog tools extracted successfully."
else
    warn "Analog tarball not found: $ANALOG_PATH"
    warn "Download it from the Cadence Analog Tools link and place it in:"
    warn "  $DOWNLOADS_DIR"
    warn "Then re-run this script, or extract manually:"
    warn "  sudo tar -xzvf <path>/${ANALOG_TARBALL} -C ${INSTALL_DIR}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 : Extract Digital Tools
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 3: Extracting Digital Tools"

DIGITAL_PATH="${DOWNLOADS_DIR}/${DIGITAL_TARBALL}"

if [[ -f "$DIGITAL_PATH" ]]; then
    info "Extracting $DIGITAL_TARBALL → $INSTALL_DIR …"
    tar -xzvf "$DIGITAL_PATH" -C "$INSTALL_DIR"
    info "Digital tools extracted successfully."
else
    warn "Digital tarball not found: $DIGITAL_PATH"
    warn "Download it from the Cadence Digital Tools link and place it in:"
    warn "  $DOWNLOADS_DIR"
    warn "Then re-run this script, or extract manually:"
    warn "  sudo tar -xzvf <path>/${DIGITAL_TARBALL} -C ${INSTALL_DIR}"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 : Discover Cadence install roots (auto-detect)
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 4: Detecting Cadence Tool Paths"

# Cadence tarballs usually unpack into a directory named after the product.
# We search for common Cadence tool roots inside INSTALL_DIR.
CADENCE_HOME=""
for candidate in "$INSTALL_DIR"/cadence* "$INSTALL_DIR"/Cadence* \
                 "$INSTALL_DIR"/CDS* "$INSTALL_DIR"/IC* \
                 "$INSTALL_DIR"/SPECTRE* "$INSTALL_DIR"/GENUS* \
                 "$INSTALL_DIR"/INNOVUS* "$INSTALL_DIR"/XCELIUM*; do
    [[ -d "$candidate" ]] && { CADENCE_HOME="$candidate"; break; }
done

if [[ -z "$CADENCE_HOME" ]]; then
    warn "Could not auto-detect Cadence tool root inside $INSTALL_DIR."
    warn "You will need to set CADENCE_HOME manually in the .bashrc block below."
    CADENCE_HOME="${INSTALL_DIR}/cadence   # ← UPDATE THIS PATH"
else
    info "Detected Cadence root: $CADENCE_HOME"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 : Write .bashrc entries for the student user
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 5: Configuring Student .bashrc"

[[ -f "$BASHRC" ]] || error ".bashrc not found for user $STUDENT_USER at $BASHRC"

MARKER="# ── CADENCE LICENSE AND ENVIRONMENT"

if grep -q "$MARKER" "$BASHRC"; then
    warn "Cadence block already present in $BASHRC — skipping."
else
    cat >> "$BASHRC" <<BASH_BLOCK

# ── CADENCE LICENSE AND ENVIRONMENT ───────────────────────────────────────
# Added by post-install-cadence.sh — do not edit manually
export CDS_INST_DIR=${INSTALL_DIR}
export CDS_LIC_FILE=${LICENSE_PORT}@${LICENSE_SERVER_IP}:${LICENSE_PORT}@${LICENSE_SERVER_HOSTNAME}
export LM_LICENSE_FILE=\${CDS_LIC_FILE}
export PATH=\${CDS_INST_DIR}/tools/bin:\$PATH
export PATH=\${CDS_INST_DIR}/tools/dfII/bin:\$PATH
# ──────────────────────────────────────────────────────────────────────────
BASH_BLOCK

    chown "${STUDENT_USER}:${STUDENT_USER}" "$BASHRC"
    info "Cadence environment block appended to $BASHRC"
    warn "Review the PATH entries above — adjust to match your actual tool subdirectories."
fi

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
section "CADENCE POST-INSTALL COMPLETE"
echo -e "  Install dir  : ${INSTALL_DIR}"
echo -e "  Student env  : ${BASHRC}"
echo ""
echo -e "  ${YELLOW}Manual steps still required:${NC}"
echo -e "    1. Verify the tool paths inside ${BASHRC} are correct."
echo -e "    2. Run the Cadence Installer (if one was included in the tarball)."
echo -e "    3. Confirm the license server is reachable:"
echo -e "       ping ${LICENSE_SERVER_IP}"
echo -e "       telnet ${LICENSE_SERVER_IP} ${LICENSE_PORT}"
echo ""
echo -e "  ${YELLOW}To activate the environment now, run as ${STUDENT_USER}:${NC}"
echo -e "    source ~/.bashrc"
echo ""
