# Zabbix Agent Auto-Installer

This repository contains a robust Bash script to seamlessly install and configure the Zabbix Agent (or Zabbix Agent 2) on Linux servers. 

The script supports both RHEL/CentOS/AlmaLinux and Debian/Ubuntu based distributions. It automatically handles the installation of the Zabbix release repository, the agent package, configures the Zabbix server IP, sets up Auto-Registration, and updates local firewall rules to allow Zabbix Server communication (port 10050).

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

### Interactive Mode
By simply providing the server IP, the script will prompt you for the version, agent type, and auto-registration metadata:
```bash
sudo ./setup_zabbix_agent.sh -s <ZABBIX_SERVER_IP>
```

### Silent / Non-Interactive Mode
For mass deployments via SSH loops or tools like Ansible, you can use flags to pass all parameters silently.

```bash
sudo ./setup_zabbix_agent.sh -s 192.168.1.100 -a 2 -v 7.0 -m "Linux-WebServers" -q
```

**Options:**
- `-s <IP>`: **(Required)** Zabbix Server IP address.
- `-n <name>`: Agent Hostname (Defaults to the system's hostname).
- `-v <version>`: Zabbix Version (e.g., 6.4, 7.0) (Defaults to 6.4).
- `-a <1|2>`: Agent Type: `1` for standard zabbix-agent, `2` for zabbix-agent2 (Defaults to 1).
- `-m <metadata>`: HostMetadata for auto-registration (e.g., 'Linux', 'Database'). 
- `-q`: Quiet/Silent mode. Suppresses all interactive prompts.

## Features

1. **Agent 2 Support:** Choose between the standard C-based agent or the newer Go-based Zabbix Agent 2.
2. **Auto-Registration:** If you provide `HostMetadata` via `-m`, the agent will send this to the server. If configured on your Zabbix server, it will automatically add the host without manual intervention in the UI!
3. **Automated Repositories:** Detects your OS and installs the correct official Zabbix repository.
4. **Firewall Setup:** Automatically opens port `10050/tcp` in `firewalld` or `ufw` if present.