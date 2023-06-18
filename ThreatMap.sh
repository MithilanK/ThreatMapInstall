#!/bin/bash


RECOMMENDED_CPU=2
RECOMMENDED_RAM=4G
RECOMMENDED_HDD_SPACE=10G

CPU=$(nproc)
RAM=$(free -m | awk '/^Mem:/{print $2}')
HDD_SPACE=$(df -P / | awk 'NR==2 {print $4}')
if [ "$CPU" -lt "$RECOMMENDED_CPU" ] || [ "$RAM" -lt "$RECOMMENDED_RAM" ] || [ "$HDD_SPACE" -lt "$RECOMMENDED_HDD_SPACE" ]; then
	echo "Insufficient system resources to run the threat map effectively."
	exit 1
fi

G_DIR="/opt/geolite"
if [ -d "$G_DIR" ]; then
	C_FILE="$G_DIR/GeoLite2-Country.mmdb"
	CI_FILE="$G_DIR/GeoLite2-City.mmdb"
	ASN_FILE="$GEOLITE_DIR/GeoLite2-ASN.mmdb"
	if [ ! -f "$C_FILE" ] || [ ! -f "$CI_FILE" ] || [ ! -f "$ASN_FILE" ]; then
		echo "GeoLite2 files not found. Please download them and place them in $G_DIR."
		exit 1
	fi
else
	echo "GeoLite2 directory not found. Please create the directory '/opt/geolite' and place the GeoLite2 files in it."
	exit 1
fi

apt update
apt install -y python3-pip python3-venv

VENV_DIR="/opt/threatmap_venv"
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

pip install flask

MAP_DIR="/opt/threatmap"
mkdir -p "$MAP_DIR"

INTERFACES_CONFIG="$MAP_DIR/interfaces.txt"
echo "Enter the interfaces (comma-separated) that the threat map will listen on:"
read -r INTERFACES
echo "$INTERFACES" > "$INTERFACES_CONFIG"


SERVICE_FILE="/etc/systemd/system/threatmap.service"
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Threat Map
After=network.target

[Service]
ExecStart=$VENV_DIR/bin/python $MAP_DIR/threat_map.py
WorkingDirectory=$MAP_DIR
User=nobody
Group=nogroup
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl enable threatmap.service
systemctl start threatmap.service

echo "Threat map installed and configured successfully."
