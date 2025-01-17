#!/usr/bin/env bash
set -e
set -o pipefail

if [ ! -f "/etc/debian_version" ]; then
    echo "this install script only supports debian-based linux"
    exit 1
fi

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

PROJ_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_PATH="$PROJ_DIR/config/config.yml"
CONFIG_TEMPLATE_PATH="$PROJ_DIR/config/config.template.yml"
SERVICE_NAME="system-sensors"
SERVICE_DEF="/etc/systemd/system/$SERVICE_NAME.service"

if [ -e "$CONFIG_PATH" ]; then
    echo "Using existing configuration at $CONFIG_PATH"
else
    echo "Creating configuration for system-sensors..."
    TIMEZONE="$(timedatectl |grep "Time zone"|awk '{print $3}')"
    DEFAULT_SERVERNAME="$(hostname)"
    DEFAULT_MQTTHOST=localhost
    DEFAULT_MQTTPORT=1883
    DEFAULT_MQTTUSER=mqtt
    DEFAULT_MQTTPASS=

    read -p "Enter server name [$DEFAULT_SERVERNAME]:" SERVERNAME
    SERVERNAME=${SERVERNAME:-$DEFAULT_SERVERNAME}

    read -p "Enter mqtt server host [$DEFAULT_MQTTHOST]:" MQTTHOST
    MQTTHOST=${MQTTHOST:-$DEFAULT_MQTTHOST}

    read -p "Enter mqtt server port [$DEFAULT_MQTTPORT]:" MQTTPORT
    MQTTPORT=${MQTTPORT:-$DEFAULT_MQTTPORT}

    read -p "Enter mqtt user name [$DEFAULT_MQTTUSER]:" MQTTUSER
    MQTTUSER=${MQTTUSER:-$DEFAULT_MQTTUSER}

    read -p "Enter mqtt password [$DEFAULT_MQTTPASS]:" MQTTPASS
    MQTTPASS=${MQTTPASS:-$DEFAULT_MQTTPASS}

    echo "Saving configuration to $CONFIG_PATH"
    export TIMEZONE MQTTHOST MQTTPORT MQTTUSER MQTTPASS SERVERNAME
    export CLIENTID="$SERVERNAME-system-sensors-$RANDOM"
    cat "$CONFIG_TEMPLATE_PATH" | envsubst > "$CONFIG_PATH"
    chown $SUDO_USER "$CONFIG_PATH"
fi

echo "Installing dependencies..."
apt-get install -y gcc python3-dev python3.11-venv python3-pip
(cd "$PROJ_DIR" && sudo -u $SUDO_USER python3 -m venv venv)
(cd "$PROJ_DIR" && sudo -u $SUDO_USER venv/bin/pip install -r requirements.txt)

echo "Creating service: $SERVICE_NAME"
cat > $SERVICE_DEF << EOF
[Unit]
Description=Python based System Sensor Service for MQTT
After=multi-user.target

[Service]
User=$SUDO_USER
Type=idle
ExecStart=$PROJ_DIR/venv/bin/python3 $PROJ_DIR/src/system_sensors.py $PROJ_DIR/config/config.yml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable $SERVICE_NAME
systemctl start $SERVICE_NAME

systemctl is-active --quiet $SERVICE_NAME && echo "Install successful, $SERVICE_NAME is running" && exit 0
echo "Install failed"s