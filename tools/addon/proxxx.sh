#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Fabrizio Salmi (fabriziosalmi)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/fabriziosalmi/proxxx

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/core.func) 2>/dev/null || true
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/tools.func) 2>/dev/null || true

# ==============================================================================
# CONFIGURATION
# ==============================================================================
APP="proxxx"
APP_TYPE="addon"
INSTALL_PATH="/usr/local/bin/proxxx"
REPO="fabriziosalmi/proxxx"

# ==============================================================================
# HEADER
# ==============================================================================
function header_info {
  clear 2>/dev/null || true
  cat <<"EOF"
                                 _
   ____  _________  _  ____  ____| |___  __
  / __ \/ ___/ __ \| |/_/ /_/ /\ \/ /\ \/ /
 / /_/ / /  / /_/ />  </ __  /__> <  >  <
 \____/_/   \____/_/|_/_/ /_//_/\_\/_/\_\

EOF
}

# ==============================================================================
# COLORS & HELPERS
# ==============================================================================
YW=$(echo "\033[33m")
GN=$(echo "\033[1;92m")
RD=$(echo "\033[01;31m")
BL=$(echo "\033[36m")
CL=$(echo "\033[m")
CM="${GN}✔️${CL}"
CROSS="${RD}✖️${CL}"
INFO="${BL}ℹ️${CL}"

function msg_info() { echo -e "${INFO} ${YW}${1}...${CL}"; }
function msg_ok() { echo -e "${CM} ${GN}${1}${CL}"; }
function msg_error() { echo -e "${CROSS} ${RD}${1}${CL}"; }

# Telemetry (best-effort, never fatal)
declare -f init_tool_telemetry &>/dev/null && init_tool_telemetry "proxxx" "addon"

set -e

# ==============================================================================
# PRE-FLIGHT
# ==============================================================================
# proxxx is a single static binary that talks to the Proxmox VE / PBS REST API.
# It is meant to run on the host or a workstation, so — unlike a service addon —
# running it directly on the Proxmox host is fully supported.
if [[ ! -f "/etc/debian_version" ]]; then
  msg_error "Unsupported OS: proxxx addon supports Debian-based hosts (Proxmox VE)."
  exit 1
fi

case "$(dpkg --print-architecture)" in
  amd64) TRIPLE="x86_64-unknown-linux-musl" ;;
  arm64) TRIPLE="aarch64-unknown-linux-musl" ;;
  *)
    msg_error "Unsupported architecture: $(dpkg --print-architecture) (amd64/arm64 only)."
    exit 1
    ;;
esac

header_info

# ==============================================================================
# UNINSTALL / UPDATE (if already installed)
# ==============================================================================
if [[ -f "$INSTALL_PATH" ]]; then
  echo -e "${YW}⚠️ ${APP} is already installed ($("$INSTALL_PATH" --version 2>/dev/null || echo unknown)).${CL}"
  read -r -p "Uninstall ${APP}? (y/N): " uninstall_prompt
  if [[ "${uninstall_prompt,,}" =~ ^(y|yes)$ ]]; then
    msg_info "Uninstalling ${APP}"
    rm -f "$INSTALL_PATH"
    msg_ok "${APP} has been uninstalled."
    exit 0
  fi
  read -r -p "Update ${APP} to the latest release? (y/N): " update_prompt
  if [[ ! "${update_prompt,,}" =~ ^(y|yes)$ ]]; then
    echo -e "${YW}⚠️ Nothing to do. Exiting.${CL}"
    exit 0
  fi
fi

# ==============================================================================
# INSTALL / UPDATE
# ==============================================================================
$STD apt-get install -y curl tar coreutils

msg_info "Resolving latest ${APP} release"
TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
  sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
if [[ -z "$TAG" ]]; then
  msg_error "Could not resolve the latest release tag from GitHub."
  exit 1
fi
VER="${TAG#v}"
ASSET="proxxx-${VER}-${TRIPLE}.tar.gz"
BASE="https://github.com/${REPO}/releases/download/${TAG}"
msg_ok "Latest release is ${TAG}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

msg_info "Downloading ${ASSET} + checksum"
curl -fsSL "${BASE}/${ASSET}" -o "${TMP}/${ASSET}"
curl -fsSL "${BASE}/${ASSET}.sha256" -o "${TMP}/${ASSET}.sha256"
msg_ok "Downloaded ${ASSET}"

msg_info "Verifying SHA-256 checksum"
(cd "$TMP" && sha256sum -c "${ASSET}.sha256" >/dev/null 2>&1) || {
  msg_error "Checksum verification FAILED — refusing to install."
  exit 1
}
msg_ok "Checksum verified"

msg_info "Installing ${APP} to ${INSTALL_PATH}"
tar -xzf "${TMP}/${ASSET}" -C "$TMP"
install -m 0755 "$(find "$TMP" -type f -name proxxx | head -n1)" "$INSTALL_PATH"
msg_ok "Installed ${APP} $("$INSTALL_PATH" --version 2>/dev/null || echo "$VER")"

echo ""
echo -e "${INFO} Next step: run ${GN}proxxx init${CL} to point it at your Proxmox cluster."
echo -e "${INFO} Docs: ${BL}https://fabriziosalmi.github.io/proxxx${CL}"
