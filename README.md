##Linux Post-Installation Booster

#Overview
The Linux Post-Installation Booster script simplifies and accelerates the setup of a new Linux installation. It automates the installation of essential packages, system configurations, and offers customizable options to tailor your environment to your needs.

#Features
System Update & Upgrade: Keeps your system packages up-to-date.
Basic Tools Installation: Installs a set of essential utilities and tools.
Customizable Package Selection: Allows users to choose from a list of software and services to install.
Service Configuration: Configures and enables services such as SSH, Fail2Ban, MongoDB, and more.
Development Environment Setup: Installs development tools like Composer, Yarn, and Node.js.
Database Servers: Provides options to install various database servers including MariaDB, MongoDB, and MSSQL.
VPN Tools: Options to set up WireGuard and OpenVPN servers.
Docker Installation: Installs Docker and related container tools.
PHP Version Selection: Prompts for and installs a specific version of PHP with extensions.

#Installation

Clone the repository:
```git clone https://github.com/syrian2012/post-install_booster.git```

```javascript
function test() {
    console.log("This code will have a copy button to the right of it");
}```

Navigate to the script directory:
```cd post-install_booster```

Make the script executable:
```chmod +x booster.sh```

Run the script:
```./booster.sh```

#Usage
The script will prompt you to select applications and services you want to install via a checklist dialog.
Follow the on-screen prompts to choose packages, configure settings, and complete the installation.
After installation, you will be asked whether to reboot your system immediately.
Available Options
Basic Tools: Includes utilities like nohang, gnupg2, tuned, python3, htop, and more.
Web Servers: Options for nginx, apache2.
Programming Tools: php, nodejs golang, ruby, rustc, default-jdk.
Development Tools: composer, yarn.
Database Servers: postgresql, mariadb, mssql-server, mongodb, redis.
VPN Tools: wireguard-server, openvpn-server.
Container Tools: docker.
SSH with fail2ban for security only Configure the SSH port during the installation process.

#Troubleshooting
Ensure you have an active internet connection for downloading packages.
Check for any error messages during installation and refer to the script's output for troubleshooting.

#Contributing
Contributions are welcome! Please fork the repository, make changes, and submit a pull request. For issues or feature requests, open a new issue on GitHub.

#License
This project is licensed under the MIT License. See the LICENSE file for details.

#enjoy with Love Mohammad Haidar.

