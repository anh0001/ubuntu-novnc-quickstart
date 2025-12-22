#!/bin/bash

# ubuntu-novnc-quickstart SSL setup

set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Get the actual username
if [ "$SUDO_USER" ]; then
  USERNAME="$SUDO_USER"
else
  USERNAME="$USER"
fi

HOME_DIR=$(eval echo ~$USERNAME)
NOVNC_SERVICE_NAME="novnc-${USERNAME}.service"
LEGACY_NOVNC_SERVICE="/etc/systemd/system/novnc.service"

echo "===================================================="
echo "  Setting up SSL for noVNC"
echo "===================================================="
echo ""

# Ask for display number
read -p "Enter VNC display number (default: 1): " DISPLAY_NUM
DISPLAY_NUM=${DISPLAY_NUM:-1}

# Ask for noVNC port
read -p "Enter noVNC web port (default: 6080): " NOVNC_PORT
NOVNC_PORT=${NOVNC_PORT:-6080}

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
  echo "Installing openssl..."
  apt update
  apt install -y openssl
fi

# Create SSL directory
mkdir -p "$HOME_DIR/novnc-ssl"
chown $USERNAME:$USERNAME "$HOME_DIR/novnc-ssl"

# Generate self-signed certificate
echo "Generating self-signed SSL certificate..."
openssl req -new -x509 -days 365 -nodes \
  -out "$HOME_DIR/novnc-ssl/novnc.pem" \
  -keyout "$HOME_DIR/novnc-ssl/novnc.key" \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

cat "$HOME_DIR/novnc-ssl/novnc.key" "$HOME_DIR/novnc-ssl/novnc.pem" > "$HOME_DIR/novnc-ssl/novnc.combined.pem"

chown $USERNAME:$USERNAME "$HOME_DIR/novnc-ssl/"*

# Update noVNC startup script
cat > "$HOME_DIR/start-novnc.sh" << EOL
#!/bin/bash
cd \$HOME/noVNC
./utils/novnc_proxy --vnc localhost:\$((5900+$DISPLAY_NUM)) --listen $NOVNC_PORT --cert=\$HOME/novnc-ssl/novnc.combined.pem
EOL

chmod +x "$HOME_DIR/start-novnc.sh"
chown $USERNAME:$USERNAME "$HOME_DIR/start-novnc.sh"

# Restart noVNC service
if systemctl list-unit-files | awk '{print $1}' | grep -q "^$NOVNC_SERVICE_NAME$"; then
  systemctl restart "$NOVNC_SERVICE_NAME"
elif [ -f "$LEGACY_NOVNC_SERVICE" ] && grep -q "ExecStart=$HOME_DIR/start-novnc.sh" "$LEGACY_NOVNC_SERVICE"; then
  systemctl restart novnc.service
fi

IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo ""
echo "SSL setup complete!"
echo ""
echo "Your secure noVNC server is now available at:"
echo "https://$IP_ADDRESS:$NOVNC_PORT/vnc.html"
echo ""
echo "Note: Since this is a self-signed certificate, your browser will show"
echo "a security warning. You'll need to accept the certificate to proceed."
echo ""
echo "For production use, consider obtaining a proper SSL certificate from"
echo "a certificate authority or using Let's Encrypt."
echo "===================================================="
