#!/bin/bash

# Zabbix Agent Automated Installation Script
# This script must be run as root or with sudo

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (or use sudo)"
  exit 1
fi

ZABBIX_SERVER=""
HOSTNAME=$(hostname)
ZABBIX_VERSION="6.4"
AGENT_TYPE="1" # 1 for zabbix-agent, 2 for zabbix-agent2
HOST_METADATA=""
INTERACTIVE=1

usage() {
    echo "Usage: $0 -s <Zabbix_Server_IP> [Options]"
    echo "Options:"
    echo "  -s <IP>       Zabbix Server IP (Required)"
    echo "  -n <name>     Agent Hostname (Default: system hostname)"
    echo "  -v <version>  Zabbix Version (Default: 6.4)"
    echo "  -a <1|2>      Agent Type: 1 for zabbix-agent, 2 for zabbix-agent2 (Default: 1)"
    echo "  -m <metadata> HostMetadata for auto-registration (e.g., 'Linux')"
    echo "  -q            Quiet/Silent mode (No interactive prompts)"
    exit 1
}

# Parse command line arguments
while getopts "s:n:v:a:m:q" opt; do
  case $opt in
    s) ZABBIX_SERVER="$OPTARG" ;;
    n) HOSTNAME="$OPTARG" ;;
    v) ZABBIX_VERSION="$OPTARG" ;;
    a) AGENT_TYPE="$OPTARG" ;;
    m) HOST_METADATA="$OPTARG" ;;
    q) INTERACTIVE=0 ;;
    *) usage ;;
  esac
done

if [ -z "$ZABBIX_SERVER" ]; then
    echo "Error: Zabbix Server IP is required."
    usage
fi

if [ "$INTERACTIVE" -eq 1 ]; then
    read -p "Enter the Zabbix Version to install (e.g., 6.4, 7.0) [current: $ZABBIX_VERSION]: " user_version
    ZABBIX_VERSION=${user_version:-$ZABBIX_VERSION}
    
    read -p "Enter the Agent Hostname [current: $HOSTNAME]: " user_hostname
    HOSTNAME=${user_hostname:-$HOSTNAME}

    read -p "Install Zabbix Agent 1 or 2? (Enter 1 or 2) [current: $AGENT_TYPE]: " user_agent
    AGENT_TYPE=${user_agent:-$AGENT_TYPE}
    
    read -p "Enter HostMetadata for auto-registration (leave blank for none) [current: $HOST_METADATA]: " user_meta
    HOST_METADATA=${user_meta:-$HOST_METADATA}
fi

AGENT_PACKAGE="zabbix-agent"
CONF_FILE="/etc/zabbix/zabbix_agentd.conf"
SERVICE_NAME="zabbix-agent"

if [ "$AGENT_TYPE" == "2" ]; then
    AGENT_PACKAGE="zabbix-agent2"
    CONF_FILE="/etc/zabbix/zabbix_agent2.conf"
    SERVICE_NAME="zabbix-agent2"
fi

echo "=========================================================="
echo "Starting Zabbix $AGENT_PACKAGE installation..."
echo "Zabbix Server: $ZABBIX_SERVER"
echo "Agent Hostname: $HOSTNAME"
echo "Zabbix Version: $ZABBIX_VERSION"
if [ -n "$HOST_METADATA" ]; then
    echo "HostMetadata: $HOST_METADATA"
fi
echo "=========================================================="

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
    MAJOR_VER=${VER%%.*}
    
    URLS=(
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rhel/${MAJOR_VER}/noarch/zabbix-release-latest.el${MAJOR_VER}.noarch.rpm"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/${MAJOR_VER}/x86_64/zabbix-release-latest.el${MAJOR_VER}.noarch.rpm"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/${MAJOR_VER}/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el${MAJOR_VER}.noarch.rpm"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/rhel/${MAJOR_VER}/x86_64/zabbix-release-${ZABBIX_VERSION}-2.el${MAJOR_VER}.noarch.rpm"
    )

    REPO_INSTALLED=0
    for url in "${URLS[@]}"; do
        if curl --output /dev/null --silent --head --fail "$url"; then
            echo "Found Zabbix repository at: $url"
            rpm -Uvh "$url" || true
            REPO_INSTALLED=1
            break
        fi
    done

    if [ $REPO_INSTALLED -eq 0 ]; then
        echo "Error: Failed to find a valid Zabbix repository URL for version $ZABBIX_VERSION on RHEL $MAJOR_VER."
        echo "Please verify the version number."
        exit 1
    fi
    
    dnf clean all
    dnf install -y $AGENT_PACKAGE
}

install_debian() {
    echo "Detected Debian/Ubuntu based OS"
    if ! command -v wget >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
        apt update && apt install -y wget curl
    fi
    
    OS_NAME=$OS # ubuntu or debian
    
    URLS=(
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/${OS_NAME}/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+${OS_NAME}${VER}_all.deb"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/${OS_NAME}/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+${OS_NAME}${VER}_all.deb"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/${OS_NAME}/pool/main/z/zabbix-release/zabbix-release_latest+${OS_NAME}${VER}_all.deb"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/${OS_NAME}/pool/main/z/zabbix-release/zabbix-release_latest+${OS_NAME}${VER}_all.deb"
        "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/${OS_NAME}/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+${OS_NAME}${VER}_all.deb"
    )

    REPO_INSTALLED=0
    for url in "${URLS[@]}"; do
        if curl --output /dev/null --silent --head --fail "$url"; then
            echo "Found Zabbix repository at: $url"
            wget "$url" -O zabbix-release.deb
            dpkg -i zabbix-release.deb || true
            rm -f zabbix-release.deb
            REPO_INSTALLED=1
            break
        fi
    done

    if [ $REPO_INSTALLED -eq 0 ]; then
        echo "Error: Failed to find a valid Zabbix repository URL for version $ZABBIX_VERSION on $OS_NAME $VER."
        echo "Please verify the version number."
        exit 1
    fi
    
    apt update
    apt install -y $AGENT_PACKAGE
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
if [ -f "$CONF_FILE" ]; then
    echo "Configuring $CONF_FILE..."
    
    cp $CONF_FILE "${CONF_FILE}.bak"

    # Update Server and ServerActive
    sed -i "s/^Server=.*/Server=$ZABBIX_SERVER/" $CONF_FILE
    sed -i "s/^ServerActive=.*/ServerActive=$ZABBIX_SERVER/" $CONF_FILE
    
    # Update Hostname
    sed -i "s/^Hostname=.*/Hostname=$HOSTNAME/" $CONF_FILE
    sed -i "s/^HostnameItem=/# HostnameItem=/" $CONF_FILE
    
    # Configure HostMetadata for Auto-registration
    if [ -n "$HOST_METADATA" ]; then
        if grep -q "^HostMetadata=" $CONF_FILE; then
            sed -i "s/^HostMetadata=.*/HostMetadata=$HOST_METADATA/" $CONF_FILE
        else
            echo "HostMetadata=$HOST_METADATA" >> $CONF_FILE
        fi
    fi
else
    echo "Error: Configuration file not found at $CONF_FILE. Installation may have failed."
    exit 1
fi

# Start and enable service
echo "Starting and enabling $SERVICE_NAME service..."
systemctl restart $SERVICE_NAME
systemctl enable $SERVICE_NAME

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
echo "$SERVICE_NAME is running and configured to talk to $ZABBIX_SERVER."
if [ -n "$HOST_METADATA" ]; then
    echo "Auto-registration metadata set to: '$HOST_METADATA'."
    echo "If auto-registration actions are configured on the server, the host will be added automatically."
else
    echo "Don't forget to add the host '$HOSTNAME' in your Zabbix Server Web Interface."
fi
echo "=========================================================="