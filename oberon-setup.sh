#!/bin/bash

set -euo pipefail

# Install binary if not present
echo "Downloading oberon-governor binary..."
curl -L -o /etc/oberon-governor https://github.com/buoyantbeaver/oberon-governor/releases/download/v1.0.2/oberon-governor
chmod +x /etc/oberon-governor
  
# Create config 
echo "Creating config file..."
tee /etc/oberon-config.yaml > /dev/null << 'EOF'
opps:
  - frequency:
    - min: 1000
    - max: 2000
  - voltage:
    - min: 700
    - max: 1000
EOF

# Create systemd service if not present
if [[ -f /etc/systemd/system/oberon-governor.service ]]; then
  echo "Systemd service already exists: /etc/systemd/system/oberon-governor.service"
else
  echo "Creating systemd service file..."
  tee /etc/systemd/system/oberon-governor.service > /dev/null << 'EOF'
[Unit]
Description=Oberon GPU Frequency Governor
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
