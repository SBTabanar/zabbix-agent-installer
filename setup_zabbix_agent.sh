#!/bin/bash

# Zabbix Agent Automated Installation Script
# This script must be run as root or with sudo

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (or use sudo)"
  exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <Zabbix_Server_IP> [Hostname]"
    echo "Example: $0 192.168.1.100 web-server-01"
    echo "If [Hostname] is not provided, the system's hostname will be used."
    exit 1
fi

ZABBIX_SERVER=$1
HOSTNAME=${2:-$(hostname)}

read -p "Enter the Zabbix Version to install (e.g., 6.4, 7.0) [default: 6.4]: " user_version
ZABBIX_VERSION=${user_version:-6.4}

echo "Starting Zabbix Agent installation..."
echo "Zabbix Server: $ZABBIX_SERVER"
echo "Agent Hostname: $HOSTNAME"

# Detect Operating System
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "Cannot detect OS. /etc/os-release is missing. Exiting."
    exit 1
fi

install_rhel() {
    echo "Detected RHEL/CentOS/AlmaLinux/Rocky based OS"
    # Extract major version (e.g., 9 from 9.7)
    MAJOR_VER=${VER%%.*}
    rpm -Uvh "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/${MAJOR_VER}/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el${MAJOR_VER}.noarch.rpm" || true
    dnf clean all
    dnf install -y zabbix-agent
}

install_debian() {
    echo "Detected Debian/Ubuntu based OS"
    # Need wget for Debian based installs
    if ! command -v wget >/dev/null 2>&1; then
        apt update && apt install -y wget
    fi
    
    if [[ "$OS" == "ubuntu" ]]; then
        REPO_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+ubuntu${VER}_all.deb"
    else
        REPO_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+debian${VER}_all.deb"
    fi
    
    wget "$REPO_URL" -O zabbix-release.deb
    dpkg -i zabbix-release.deb || true
    apt update
    apt install -y zabbix-agent
    rm -f zabbix-release.deb
}

if [[ "$OS" == *"almalinux"* || "$OS" == *"rocky"* || "$OS" == *"centos"* || "$OS" == *"rhel"* || "$OS" == *"fedora"* ]]; then
    install_rhel
elif [[ "$OS" == *"ubuntu"* || "$OS" == *"debian"* ]]; then
    install_debian
else
    echo "Unsupported OS: $OS. You may need to install manually."
    exit 1
fi

# Configure Zabbix Agent
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"
if [ -f "$CONF_FILE" ]; then
    echo "Configuring $CONF_FILE..."
    
    # Backup original config just in case
    cp $CONF_FILE "${CONF_FILE}.bak"

    # Update Server (Passive checks)
    sed -i "s/^Server=.*/Server=$ZABBIX_SERVER/" $CONF_FILE
    
    # Update ServerActive (Active checks)
    sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER/" $CONF_FILE
    
    # Update Hostname
    sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $CONF_FILE
    
    # Comment out the default HostnameItem if it exists so our Hostname takes precedence
    sed -i "s/^HostnameItem=/# HostnameItem=/" $CONF_FILE
else
    echo "Error: Configuration file not found at $CONF_FILE. Installation may have failed."
    exit 1
fi

# Start and enable service
echo "Starting and enabling zabbix-agent service..."
systemctl restart zabbix-agent
systemctl enable zabbix-agent

# Firewall configuration
if command -v firewall-cmd >/dev/null 2>&1; then
    echo "Configuring firewalld..."
    firewall-cmd --permanent --add-port=10050/tcp
    firewall-cmd --reload
elif command -v ufw >/dev/null 2>&1; then
    echo "Configuring UFW..."
    ufw allow 10050/tcp
else
    echo "No standard firewall (firewalld/ufw) detected. Please ensure port 10050 is open."
fi

echo "=========================================================="
echo "Zabbix Agent setup complete!"
echo "Zabbix agent is running and configured to talk to $ZABBIX_SERVER."
echo "Don't forget to add the host '$HOSTNAME' in your Zabbix Server Web Interface."
echo "=========================================================="
