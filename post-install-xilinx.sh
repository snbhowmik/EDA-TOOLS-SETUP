#!/bin/bash
# =============================================================================
#  PRE-INSTALL CONFIG SCRIPT
#  Purpose : Common system setup BEFORE installing any EDA tool
#            (Xilinx Vivado/Vitis, Cadence, Synopsys, or similar)
#  Run as  : sysadmin, using sudo  →  sudo bash pre-install-config.sh
#  Tested  : RHEL 8 / AlmaLinux 8 / Rocky Linux 8
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION  ← edit these before running
# ─────────────────────────────────────────────────────────────────────────────
MACHINE_NUMBER="01"                         # e.g. 01, 02 … 30
HOSTNAME="vlsilab${MACHINE_NUMBER}.ist.srmtrichy.edu.in"

# NOTE: The sysadmin user is assumed to already exist on every machine.
# Only the student user is created here.
SYSADMIN_USER="sysadmin309${MACHINE_NUMBER}"
STUDENT_USER="srmist309${MACHINE_NUMBER}"
STUDENT_DISPLAY="SRM-IST-309-${MACHINE_NUMBER}"
STUDENT_PASS="Student@SRM"

LICENSE_SERVER_IP="14.139.1.126"
LICENSE_SERVER_HOSTNAME="c2s.cdacb.in"

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

section "STEP 1: Creating Student User"

if id "$STUDENT_USER" &>/dev/null; then
    warn "User $STUDENT_USER already exists — skipping creation."
else
    useradd -m -c "$STUDENT_DISPLAY" -s /bin/bash "$STUDENT_USER"
    echo "$STUDENT_USER:$STUDENT_PASS" | chpasswd
    info "Student user '$STUDENT_USER' created."
fi

# Ensure student is NOT in the wheel group
if groups "$STUDENT_USER" | grep -q wheel; then
    gpasswd -d "$STUDENT_USER" wheel
    info "Removed $STUDENT_USER from wheel group."
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 2 : Set Hostname
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 2: Setting Hostname"

hostnamectl set-hostname "$HOSTNAME"
info "Hostname set to: $HOSTNAME"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 3 : Configure /etc/hosts
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 3: Configuring /etc/hosts"

HOSTS_ENTRY="${LICENSE_SERVER_IP} ${LICENSE_SERVER_HOSTNAME}"

if grep -q "$LICENSE_SERVER_HOSTNAME" /etc/hosts; then
    warn "License server already present in /etc/hosts — skipping."
else
    printf "\n# EDA License Server\n%s\n" "${HOSTS_ENTRY}" | tee -a /etc/hosts > /dev/null
    info "Added license server entry to /etc/hosts:"
    info "  $HOSTS_ENTRY"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STEP 4 : RHEL Subscription & Base Repos
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 4: Updating System & Enabling Repos"

info "Running initial dnf update …"
dnf update -y

info "Installing EPEL …"
dnf install -y epel-release || {
    warn "epel-release not found in base repos — trying manual install."
    dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
}

info "Enabling CodeReady Builder …"
subscription-manager repos --enable "codeready-builder-for-rhel-8-$(arch)-rpms" || \
    warn "subscription-manager failed — you may not be registered. Continuing."

dnf update -y

# ─────────────────────────────────────────────────────────────────────────────
# STEP 5 : Install RPM Fusion
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 5: Installing RPM Fusion"

RPMFUSION_FREE="https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm"
RPMFUSION_NONFREE="https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-8.noarch.rpm"

TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

info "Downloading RPM Fusion packages …"
curl -fLO "$RPMFUSION_FREE"
curl -fLO "$RPMFUSION_NONFREE"

dnf install -y ./*.rpm || warn "RPM Fusion install had warnings — continuing."
cd -
rm -rf "$TMP_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# STEP 6 : Install All Common EDA Dependencies
# ─────────────────────────────────────────────────────────────────────────────
section "STEP 6: Installing EDA Dependencies"

COMMON_PKGS=(
    # RHEL / compatibility
    compat-openssl10
    redhat-lsb-core
    csh ksh
    libnsl libnsl.i686
    fuse-exfat
    glibc glibc-devel
    glibc.i686
    libgcc.i686
    libstdc++.i686
    zlib.i686
    elfutils-libelf
    # Graphics / OpenGL
    mesa-libGL mesa-libGLU
    # Fonts (needed by many EDA GUIs)
    xorg-x11-fonts-75dpi
    xorg-x11-fonts-misc
    # X11 libraries — explicit list instead of wildcard to avoid conflicts
    libXtst libXrender libXi libXrandr
    libXcursor libXinerama libSM libICE libXft libXext libXau libXdmcp
    nano
    gdbm
    # ELRepo (kernel drivers)
    elrepo-release
)

dnf install -y "${COMMON_PKGS[@]}" --skip-broken

# Wildcard packages (openssl*, libX*, liba*) — install separately
info "Installing wildcard package groups …"
dnf install -y 'openssl*'  --skip-broken || warn "Some openssl* packages skipped."
dnf install -y 'liba*'     --skip-broken || warn "Some liba* packages skipped."

info "All dependencies installed."

# ─────────────────────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────────────────────
section "PRE-INSTALL CONFIG COMPLETE"
echo -e "  Student : ${STUDENT_USER} (no sudo)"
echo -e "  Hostname: ${HOSTNAME}"
echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "    • Reboot the system."
echo -e "    • Install your EDA tool (Xilinx / Cadence / Synopsys)."
echo -e "    • Run the matching post-install script as sysadmin."
echo -e "    • Run lockdown.sh when you are ready to restrict the student account."
echo ""
