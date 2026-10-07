#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/usr/bin"
CONFIG_DIR="/etc/antec-flux-pro-display"
UDEV_RULE="/etc/udev/rules.d/99-antec-flux-pro-display.rules"
SERVICE_FILE="/etc/systemd/system/antec-flux-pro-display.service"

echo "==> Installing Fedora dependencies..."
sudo dnf install -y \
    rust \
    cargo \
    lm_sensors \
    lm_sensors-devel \
    libusb1-devel \
    usbutils

echo "==> Building antec-flux-pro-display..."
cargo build --release

echo "==> Installing binary..."
sudo install -Dm755 \
    target/release/antec-flux-pro-display \
    "$INSTALL_DIR/antec-flux-pro-display"

echo "==> Creating configuration directory..."
sudo mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.conf" ]; then
    sudo tee "$CONFIG_DIR/config.conf" >/dev/null <<'EOF'
# CPU device for temperature monitoring
cpu_device=k10temp
cpu_temp_type=tctl

# GPU device for temperature monitoring
gpu_device=amdgpu
gpu_temp_type=edge

# Update interval in milliseconds
update_interval=1000
EOF
fi

echo "==> Installing udev rule..."
sudo tee "$UDEV_RULE" >/dev/null <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="2022", ATTR{idProduct}=="0522", MODE="0660", TAG+="uaccess"
EOF

echo "==> Installing systemd service..."
sudo tee "$SERVICE_FILE" >/dev/null <<'EOF'
[Unit]
Description=Antec Flux Pro Display Service
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/bin/antec-flux-pro-display
Restart=always
RestartSec=5
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading udev and systemd..."
sudo udevadm control --reload-rules
sudo udevadm trigger --action=change --subsystem-match=usb
sudo systemctl daemon-reload

echo "==> Enabling and starting service..."
sudo systemctl enable --now antec-flux-pro-display

echo
echo "Installation complete."
echo
echo "Binary:"
ldd "$INSTALL_DIR/antec-flux-pro-display" | grep sensors || true
echo
echo "Service status:"
systemctl --no-pager --full status antec-flux-pro-display
