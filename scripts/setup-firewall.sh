#!/bin/bash

# ubuntu-novnc-quickstart firewall setup

set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Ask for display number
read -p "Enter VNC display number (default: 1): " DISPLAY_NUM
DISPLAY_NUM=${DISPLAY_NUM:-1}
VNC_PORT=$((5900 + $DISPLAY_NUM))

echo "Setting up firewall rules..."

# Check if ufw is installed
if ! command -v ufw &> /dev/null; then
  echo "Installing ufw..."
  apt update
  apt install -y ufw
fi

# Set up firewall rules
ufw allow 6080/tcp comment 'noVNC web access'
ufw allow $VNC_PORT/tcp comment 'VNC server'
ufw status

echo ""
echo "Firewall rules added for:"
echo "- noVNC web access (port 6080)"
echo "- VNC server (port $VNC_PORT)"
echo ""
echo "If ufw is not enabled, enable it with:"
echo "sudo ufw enable"