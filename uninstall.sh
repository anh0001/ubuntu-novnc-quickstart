#!/bin/bash

# ubuntu-novnc-quickstart uninstaller
# Removes TigerVNC and noVNC services while preserving user data

set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Get username even when run with sudo
if [ "$SUDO_USER" ]; then
  USERNAME="$SUDO_USER"
else
  USERNAME="$USER"
fi

HOME_DIR=$(eval echo ~$USERNAME)

# Display header
echo "===================================================="
echo "  Ubuntu noVNC Quick Setup - Uninstaller"
echo "===================================================="
echo ""

# Confirm uninstallation
echo "This will remove all noVNC and VNC services and configuration."
echo "Your VNC password will be preserved."
echo ""
read -p "Continue with uninstallation? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
  echo "Uninstallation cancelled."
  exit 0
fi

# Find all running VNC services
echo "Finding and stopping VNC services..."
RUNNING_SERVICES=$(systemctl list-units --type=service --state=running | grep vncserver@ | awk '{print $1}')

# Stop and disable services
echo "Stopping and disabling services..."
systemctl stop novnc.service 2>/dev/null || true
systemctl disable novnc.service 2>/dev/null || true

for SERVICE in $RUNNING_SERVICES; do
  echo "Stopping $SERVICE"
  systemctl stop "$SERVICE" 2>/dev/null || true
  systemctl disable "$SERVICE" 2>/dev/null || true
done

# Stop any remaining VNC processes
echo "Stopping any remaining VNC processes..."
pkill Xtigervnc 2>/dev/null || true

# Remove service files
echo "Removing service files..."
rm -f /etc/systemd/system/novnc.service
rm -f /etc/systemd/system/vncserver@.service
systemctl daemon-reload

# Remove startup script
echo "Removing noVNC startup script..."
rm -f "$HOME_DIR/start-novnc.sh"

# Ask if user wants to remove noVNC repository
echo ""
read -p "Remove noVNC repository from $HOME_DIR/noVNC? (y/n): " REMOVE_NOVNC

if [ "$REMOVE_NOVNC" = "y" ]; then
  echo "Removing noVNC repository..."
  rm -rf "$HOME_DIR/noVNC"
fi

# Ask if user wants to remove VNC configuration
echo ""
read -p "Remove VNC configuration (except password)? (y/n): " REMOVE_VNC_CONFIG

if [ "$REMOVE_VNC_CONFIG" = "y" ]; then
  echo "Backing up VNC password..."
  if [ -f "$HOME_DIR/.vnc/passwd" ]; then
    # Preserve ownership and mode so restore doesn't change file owner to root
    cp -p "$HOME_DIR/.vnc/passwd" "$HOME_DIR/.vnc/passwd.backup"
  fi
  
  echo "Removing VNC configuration..."
  rm -f "$HOME_DIR/.vnc/xstartup"
  rm -f "$HOME_DIR/.vnc/*.log"
  rm -f "$HOME_DIR/.vnc/*.pid"
  
  echo "Restoring VNC password..."
  if [ -f "$HOME_DIR/.vnc/passwd.backup" ]; then
    mv "$HOME_DIR/.vnc/passwd.backup" "$HOME_DIR/.vnc/passwd"
    # Ensure correct ownership and permissions just in case filesystem semantics changed
    chown "$USERNAME:$USERNAME" "$HOME_DIR/.vnc/passwd" 2>/dev/null || true
    chmod 600 "$HOME_DIR/.vnc/passwd" 2>/dev/null || true
  fi
fi

# Ask if user wants to remove SSL certificates
if [ -d "$HOME_DIR/novnc-ssl" ]; then
  echo ""
  read -p "Remove SSL certificates? (y/n): " REMOVE_SSL

  if [ "$REMOVE_SSL" = "y" ]; then
    echo "Removing SSL certificates..."
    rm -rf "$HOME_DIR/novnc-ssl"
  fi
fi

echo ""
echo "===================================================="
echo "  Uninstallation Complete!"
echo "===================================================="
echo ""
echo "The following were not removed:"
echo "- Installed packages (TigerVNC, XFCE, etc.)"
echo "- VNC password"
echo ""
echo "To remove installed packages, run:"
echo "sudo apt remove tigervnc-standalone-server tigervnc-xorg-extension xfce4"
echo "===================================================="
