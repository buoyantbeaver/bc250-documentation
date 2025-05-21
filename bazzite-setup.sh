#!/bin/bash

set -euo pipefail

# Install binary if not present
if [[ -f /etc/oberon-governor ]]; then
  echo "Binary already exists: /etc/oberon-governor"
else
  echo "Downloading oberon-governor binary..."
  curl -L -o /etc/oberon-governor https://github.com/buoyantbeaver/oberon-governor/releases/download/v1.0.0/oberon-governor
  chmod +x /etc/oberon-governor
fi

# Create config if not present
if [[ -f /etc/oberon-config.yaml ]]; then
  echo "Config already exists: /etc/oberon-config.yaml"
else
  echo "Creating config file..."
  tee /etc/oberon-config.yaml > /dev/null << 'EOF'
opps:
  - frequency:
    - min: 1000
    - max: 2000
  - voltage:
    - min: 700
    - max: 950
EOF
fi

# Create systemd service if not present
if [[ -f /etc/systemd/system/oberon-governor.service ]]; then
  echo "Systemd service already exists: /etc/systemd/system/oberon-governor.service"
else
  echo "Creating systemd service file..."
  tee /etc/systemd/system/oberon-governor.service > /dev/null << 'EOF'
[Unit]
Description=Oberon CPU Frequency Governor
After=network.target

[Service]
ExecStart=/etc/oberon-governor
RestartSec=5
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  echo "Reloading systemd..."
  systemctl daemon-reexec
  systemctl daemon-reload

  echo "Enabling and starting oberon-governor service..."
  systemctl enable oberon-governor
  systemctl start oberon-governor
fi

echo "Oberon Governor setup complete."

REQUIRED="42.20250511"

# Extract OSTREE_VERSION without quotes from /etc/os-release
CURRENT=$(grep '^OSTREE_VERSION=' /etc/os-release | cut -d= -f2 | tr -d "'\"")

# Remove trailing ".0" if present to match format "42.20250513"
CURRENT=${CURRENT%.0}

if [[ -z "$CURRENT" ]]; then
  echo "Error: Could not determine current Bazzite OS version." >&2
  exit 2
fi

if [[ "$(printf '%s\n%s\n' "$REQUIRED" "$CURRENT" | sort -V | head -n1)" == "$REQUIRED" ]]; then
  echo "Bazzite OS $CURRENT detected."
else
  echo "Your version of Bazzite OS ($CURRENT) is not supported. Please upgrade to version $REQUIRED or newer."
  exit 1
fi

# Credit to https://redd.it/vbg0tw/
mkdir -p /etc/systemd/system/service.d/
sudo bash -c 'echo -e "[Service]\nEnvironment=FLATPAK_GL_DRIVERS=mesa-git" > /etc/systemd/system/service.d/99-flatpak-mesa-git.conf'

# Add the Flathub beta repository
flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo

# Install the Mesa Git OpenGL platform runtime (32-bit version 24.08) system-wide from the Flathub beta repo
flatpak install -y --system flathub-beta org.freedesktop.Platform.GL.mesa-git//24.08

# Install the 32-bit Mesa Git OpenGL platform runtime (version 24.08) system-wide from the Flathub beta repo
flatpak install -y --system flathub-beta org.freedesktop.Platform.GL32.mesa-git//24.08

# Final notification and system reboot
echo "Configuration complete. The system will reboot in 5 seconds. Press Ctrl+C to cancel."
sleep 5 && systemctl reboot
