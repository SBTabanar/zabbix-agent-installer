# Zabbix Agent Auto-Installer

This repository contains a simple, robust Bash script to seamlessly install and configure the Zabbix Agent on Linux servers. 

The script supports both RHEL/CentOS/AlmaLinux and Debian/Ubuntu based distributions. It automatically handles the installation of the Zabbix release repository, the agent package itself, configures the Zabbix server IP, and sets up local firewall rules to allow Zabbix Server communication (port 10050).

## Prerequisites

- Target server must be running a supported Linux distribution (AlmaLinux, CentOS, RHEL, Rocky Linux, Ubuntu, Debian).
- You must run the script with root privileges (`sudo`).
- You need the IP address of your Zabbix Server.

## Usage

1. Copy the script to your target VM/Server.
2. Make it executable:
   ```bash
   chmod +x setup_zabbix_agent.sh
   ```
3. Run the script, providing your Zabbix Server IP as the first argument:
   ```bash
   sudo ./setup_zabbix_agent.sh <ZABBIX_SERVER_IP>
   ```

### Specifying a Custom Hostname

By default, the script will configure the agent using the system's current hostname. If you want to configure a specific hostname that matches what you have set up in the Zabbix Server UI, pass it as the second argument:

```bash
sudo ./setup_zabbix_agent.sh <ZABBIX_SERVER_IP> <CUSTOM_HOSTNAME>
```

**Example:**
```bash
sudo ./setup_zabbix_agent.sh 192.168.1.100 my-database-vm
```

## What the script does:
1. Detects the operating system type.
2. Prompts you for the desired Zabbix version (defaults to 6.4) and installs the official Zabbix repository.
3. Installs the `zabbix-agent` package via `dnf` or `apt`.
4. Configures `/etc/zabbix/zabbix_agentd.conf` with your Zabbix Server IP (for both active and passive checks) and sets the Hostname.
5. Starts and enables the `zabbix-agent` service.
6. Automatically opens port `10050/tcp` in `firewalld` or `ufw` if present.

## After Installation

Go to your Zabbix Server Web Interface and add the Host, ensuring the `Host name` exactly matches the hostname configured by this script, and set the interface to the VM's IP address.
