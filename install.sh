#!/bin/bash

# ubuntu-novnc-quickstart installer
# Installs TigerVNC and noVNC for web-based VNC access

set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Get the actual username (not root or sudo user)
if [ "$SUDO_USER" ]; then
  USERNAME="$SUDO_USER"
else
  USERNAME="$USER"
fi

HOME_DIR=$(eval echo ~$USERNAME)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Display header
echo "===================================================="
echo "  Ubuntu noVNC Quick Setup"
echo "===================================================="
echo ""

# Ask for display number
read -p "Enter VNC display number (default: 1): " DISPLAY_NUM
DISPLAY_NUM=${DISPLAY_NUM:-1}

# Ask for noVNC port
while true; do
  read -p "Enter noVNC web port (default: 6080): " NOVNC_PORT
  NOVNC_PORT=${NOVNC_PORT:-6080}
  if ! [[ "$NOVNC_PORT" =~ ^[0-9]+$ ]] || [ "$NOVNC_PORT" -lt 1 ] || [ "$NOVNC_PORT" -gt 65535 ]; then
    echo "Please enter a valid port between 1 and 65535."
    continue
  fi
  if command -v ss >/dev/null 2>&1; then
    if ss -ltn | awk '{print $4}' | grep -q ":$NOVNC_PORT$"; then
      echo "Port $NOVNC_PORT appears to be in use. Choose a different port."
      continue
    fi
  fi
  break
done

# Ask for geometry
read -p "Enter screen resolution (default: 1280x800): " GEOMETRY
GEOMETRY=${GEOMETRY:-1280x800}

# Ask for color depth
read -p "Enter color depth (default: 24): " DEPTH
DEPTH=${DEPTH:-24}

echo ""
echo "Installing required packages..."
apt update
apt install -y tigervnc-standalone-server tigervnc-xorg-extension \
  xfce4 xfce4-goodies git python3 python3-pip net-tools

# Set up TigerVNC
echo ""
echo "Setting up TigerVNC..."

# Create VNC user directory if it doesn't exist; ensure ownership
if [ ! -d "$HOME_DIR/.vnc" ]; then
  mkdir -p "$HOME_DIR/.vnc"
fi
chown $USERNAME:$USERNAME "$HOME_DIR/.vnc" || true

# Create or update xstartup file
cat > "$HOME_DIR/.vnc/xstartup" << EOL
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r "$HOME_DIR/.Xresources" ] && xrdb "$HOME_DIR/.Xresources"
# Disable screen blanking so the VNC session stays active
xset -dpms
xset s off
xset s noblank
# Launch XFCE4 session in foreground
dbus-launch --exit-with-session startxfce4
EOL

# Make xstartup executable
chmod +x "$HOME_DIR/.vnc/xstartup"
chown $USERNAME:$USERNAME "$HOME_DIR/.vnc/xstartup"

# Create a no-sleep helper that runs inside the XFCE session (autostart)
mkdir -p "$HOME_DIR/.config/autostart"
cat > "$HOME_DIR/.vnc/novnc-nosleep.sh" << 'EOL'
#!/bin/sh
# Defensive: keep X from blanking/DPMS in-session too
xset -dpms || true
xset s off || true
xset s noblank || true

# Disable XFCE power-manager display sleep/blank
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/dpms-enabled -s false 2>/dev/null || true
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/blank-on-ac -s 0 2>/dev/null || true
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/sleep-display-ac -s 0 2>/dev/null || true
  xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/sleep-display-battery -s 0 2>/dev/null || true
fi

# Disable idle-activated screensaver but keep manual lock working
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.xfce.screensaver idle-activation-enabled false 2>/dev/null || true
fi

exit 0
EOL

chmod +x "$HOME_DIR/.vnc/novnc-nosleep.sh"
chown $USERNAME:$USERNAME "$HOME_DIR/.vnc/novnc-nosleep.sh"

cat > "$HOME_DIR/.config/autostart/novnc-nosleep.desktop" << EOL
[Desktop Entry]
Type=Application
Name=Disable Sleep/Idle for VNC
Comment=Keep VNC session awake; manual lock still works
Exec=$HOME_DIR/.vnc/novnc-nosleep.sh
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOL

chown -R $USERNAME:$USERNAME "$HOME_DIR/.config"

# Set up VNC password if it doesn't exist
if [ ! -f "$HOME_DIR/.vnc/passwd" ]; then
  echo ""
  echo "Setting up VNC password..."
  su - $USERNAME -c "vncpasswd"
fi

# Ensure VNC password file has correct ownership and permissions
if [ -f "$HOME_DIR/.vnc/passwd" ]; then
  chown $USERNAME:$USERNAME "$HOME_DIR/.vnc/passwd" || true
  chmod 600 "$HOME_DIR/.vnc/passwd" || true
fi

# Install noVNC
echo ""
echo "Setting up noVNC..."

# Clone noVNC repository
if [ ! -d "$HOME_DIR/noVNC" ]; then
  su - $USERNAME -c "git clone https://github.com/novnc/noVNC.git"
fi

# Install websockify
pip3 install websockify

# Create noVNC startup script
cat > "$HOME_DIR/start-novnc.sh" << EOL
#!/bin/bash
cd \$HOME/noVNC
./utils/novnc_proxy --vnc localhost:\$((5900+$DISPLAY_NUM)) --listen $NOVNC_PORT
EOL

chmod +x "$HOME_DIR/start-novnc.sh"
chown $USERNAME:$USERNAME "$HOME_DIR/start-novnc.sh"

# Set up systemd services
echo ""
echo "Setting up systemd services..."

# Create VNC service file
VNC_SERVICE_TEMPLATE="/etc/systemd/system/vncserver-${USERNAME}@.service"
VNC_SERVICE="vncserver-${USERNAME}@${DISPLAY_NUM}.service"
NOVNC_SERVICE="/etc/systemd/system/novnc-${USERNAME}.service"
NOVNC_SERVICE_NAME="novnc-${USERNAME}.service"

cat > "$VNC_SERVICE_TEMPLATE" << EOL
[Unit]
Description=TigerVNC server at display %i
After=network.target syslog.target

[Service]
Type=simple
User=$USERNAME
Group=$USERNAME
WorkingDirectory=$HOME_DIR

# Clean up any stale sessions
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1

# Start VNC server with your settings
ExecStart=/usr/bin/vncserver :%i -geometry $GEOMETRY -depth $DEPTH -localhost no -fg

# Clean shutdown
ExecStop=/usr/bin/vncserver -kill :%i

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Create noVNC service file
cat > "$NOVNC_SERVICE" << EOL
[Unit]
Description=noVNC WebSocket VNC Proxy
After=network.target $VNC_SERVICE
Requires=$VNC_SERVICE

[Service]
Type=simple
User=$USERNAME
Group=$USERNAME
WorkingDirectory=$HOME_DIR
ExecStart=$HOME_DIR/start-novnc.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

# Enable and start services
systemctl daemon-reload
systemctl enable "$VNC_SERVICE"
systemctl start "$VNC_SERVICE"
systemctl enable "$NOVNC_SERVICE_NAME"
systemctl start "$NOVNC_SERVICE_NAME"

# Get IP address
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo ""
echo "===================================================="
echo "  Installation Complete!"
echo "===================================================="
echo ""
echo "Your noVNC server is running at:"
echo "http://$IP_ADDRESS:$NOVNC_PORT/vnc.html"
echo ""
echo "VNC server is running on display :$DISPLAY_NUM"
echo "VNC port: 590$DISPLAY_NUM"
echo "noVNC port: $NOVNC_PORT"
echo ""
echo "To manage services:"
echo "  sudo systemctl start|stop|restart vncserver-$USERNAME@$DISPLAY_NUM.service"
echo "  sudo systemctl start|stop|restart novnc-$USERNAME.service"
echo ""
echo "For security, consider setting up SSL or a reverse proxy."
echo "See scripts/setup-ssl.sh for SSL setup."
echo "===================================================="
