# Ubuntu noVNC Quickstart

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange.svg)
![License](https://img.shields.io/github/license/yourusername/ubuntu-novnc-quickstart)

A streamlined, automated solution for setting up TigerVNC with noVNC web access on Ubuntu systems. Access your Ubuntu desktop remotely through any web browser, with proper systemd integration and security options.

## 🌟 Features

- **One-command installation** of TigerVNC and noVNC
- **Systemd integration** for automatic startup and proper service management
- **Web-based remote access** to your Ubuntu desktop from any browser
- **Customizable configuration** (resolution, color depth, display number, noVNC port)
- **Security options** including SSL/TLS encryption and firewall configuration
- **Clean uninstallation** option to revert all changes

## 📋 Requirements

- Ubuntu 18.04, 20.04, 22.04 or newer
- Sudo/root access
- Internet connection (for package installation)

## 🚀 Quick Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/anh0001/ubuntu-novnc-quickstart.git
   cd ubuntu-novnc-quickstart
   ```

2. Make the installer executable:
   ```bash
   chmod +x install.sh
   ```

3. **Before installation**, ensure no VNC password is set. If you have an existing VNC password, remove it:
   ```bash
   rm ~/.vnc/passwd
   ```

4. Run the installer:
   ```bash
   sudo ./install.sh
   ```

5. Follow the interactive prompts to configure your setup.

6. Access your desktop via web browser at:
   ```
   http://YOUR_SERVER_IP:<noVNC-port>/vnc.html
   ```
   (default noVNC port is 6080)

## ⚙️ Configuration Options

During installation, you'll be prompted for:

- VNC display number (default: 1)
- noVNC web port (default: 6080)
- Screen resolution (default: 1280x800)
- Color depth (default: 24)
- Optional Google Chrome install for the VNC desktop (amd64 only)
- VNC password for secure access

Note: On shared machines, each user should choose a unique noVNC port to avoid conflicts.

All configuration is stored in standard locations:

- VNC configuration: `~/.vnc/`
- System services: `/etc/systemd/system/`

## 🖥️ Usage Instructions

### Accessing Your Desktop

**Through web browser (preferred):**

- Navigate to: `http://YOUR_SERVER_IP:<noVNC-port>/vnc.html` (default 6080)
- Enter your VNC password when prompted

**Using a VNC client:**

- Connect to: `YOUR_SERVER_IP:5901` (if using display :1)
- Enter your VNC password when prompted

### Managing Services

**Start/stop/restart the VNC server:**
Replace `<user>` with the username that ran the installer.
```bash
sudo systemctl start vncserver-<user>@1.service
sudo systemctl stop vncserver-<user>@1.service
sudo systemctl restart vncserver-<user>@1.service
```

**Start/stop/restart the noVNC service:**
```bash
sudo systemctl start novnc-<user>.service
sudo systemctl stop novnc-<user>.service
sudo systemctl restart novnc-<user>.service
```

**Check service status:**
```bash
sudo systemctl status vncserver-<user>@1.service
sudo systemctl status novnc-<user>.service
```

### Keeping the Session Awake

The installer configures your VNC desktop to stay awake:

- Adds `xset -dpms`, `xset s off`, and `xset s noblank` in `~/.vnc/xstartup` to disable X blanking.
- Creates an autostart helper that disables XFCE power-manager display sleep and turns off idle-activated screensaver, while preserving manual lock.

Manual lock still works via the XFCE “Lock Screen” action or by running `xflock4` in a terminal. Only idle-activated blanking/locking is disabled.

To re-enable idle screensaver/blanking, either remove the autostart file `~/.config/autostart/novnc-nosleep.desktop` or run:
```bash
gsettings set org.xfce.screensaver idle-activation-enabled true
```

### Changing Configuration

To change resolution or other settings after installation:

1. Edit the VNC service file:
   ```bash
   sudo nano /etc/systemd/system/vncserver-<user>@.service
   ```

2. Modify the `-geometry` or other parameters

3. Restart the service:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart vncserver-<user>@1.service
   ```

## 🔒 Security Enhancements

For production use, consider these additional security measures:

### 1. SSL Encryption (Recommended)

Set up SSL for encrypted connections:
```bash
sudo ./scripts/setup-ssl.sh
```
Then access via: `https://YOUR_SERVER_IP:<noVNC-port>/vnc.html`

### 2. Firewall Configuration

Configure your firewall to only allow necessary ports:
```bash
sudo ./scripts/setup-firewall.sh
```

### 3. Authentication

Always use a strong VNC password. To change your password:
```bash
vncpasswd
sudo systemctl restart vncserver-<user>@1.service
```

### 4. Reverse Proxy (Advanced)

For advanced setups, consider using Nginx as a reverse proxy with Let's Encrypt certificates.

## ❌ Uninstallation

To completely remove the installation:
```bash
sudo ./uninstall.sh
```

This will:

- Stop and disable all services
- Remove service files
- Restore your system to its previous state

Installed packages are not removed automatically. If you opted into Google Chrome during install, remove it with:
```bash
sudo apt remove google-chrome-stable
```

## 🔍 Troubleshooting

### Service Not Starting

Check the service status and logs:
```bash
sudo systemctl status vncserver-<user>@1.service
sudo journalctl -u vncserver-<user>@1.service
```

Common issues:

- Display already in use: Another VNC server may be running
- Authentication failure: VNC password issues
- Port conflicts: Another service using port 5901 or your selected noVNC port

### Connection Issues

If you can't connect:

- Check if services are running
- Verify firewall settings: `sudo ufw status`
- Test with localhost first: `http://localhost:<noVNC-port>/vnc.html`

### Authentication failure: No password configured for VNC Auth

This usually means the VNC password file exists but is unreadable by the user running the service. A common cause is reinstalling after an uninstall that backed up/restored the password as `root`, changing ownership to `root`.

Fix ownership and permissions, then restart services:
```bash
sudo chown "$USER:$USER" ~/.vnc ~/.vnc/passwd 2>/dev/null || true
sudo chmod 600 ~/.vnc/passwd
sudo systemctl restart vncserver-<user>@1.service
sudo systemctl restart novnc-<user>.service
```

If the password file is missing or corrupted, recreate it:
```bash
vncpasswd
sudo systemctl restart vncserver-<user>@1.service
```
- Check network routes if connecting from outside

### Blank Screen After Login

If noVNC shows the login screen but displays a blank screen after entering the password:

```bash
sudo systemctl restart vncserver-<user>@77.service
```

Replace `77` with your actual display number (e.g., `1` if you used display `:1` during installation).

### Log Locations

- VNC server logs: `~/.vnc/YOUR_HOSTNAME:1.log`
- noVNC logs: `sudo journalctl -u novnc-<user>.service`
- System logs: `sudo journalctl -xef`

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## 🙏 Acknowledgments

- TigerVNC for the VNC server
- noVNC for the HTML5 VNC client
