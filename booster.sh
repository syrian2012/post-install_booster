#!/bin/bash

trap 'echo "An error occurred in the script."' ERR

# Update & Upgrade the system
echo "Updating and upgrading the system..."
apt update && apt upgrade -y && apt dist-upgrade -y || echo "Failed to update and upgrade the system"

# Install basic tools including whiptail and iptables
echo "Installing basic tools..."
apt install -y nohang gnupg2 tuned python3 htop bpytop nload git lsb-release apt-transport-https ca-certificates curl gnupg wget net-tools dnsutils syslog-ng bash-completion software-properties-common neofetch whiptail iptables nano || echo "Failed to install some basic tools"

# Function to install a package
install_package() {
    package=$1
    if ! dpkg -l | grep -q "^ii  $package "; then
        echo "Installing $package..."
        apt install -y "$package" || { echo "Failed to install $package"; return 1; }
    else
        echo "$package is already installed."
    fi

    # Enable the service if it's available
    if systemctl list-unit-files | grep -q "${package}.service"; then
        systemctl enable --now "${package}.service" || echo "Failed to enable ${package} service"
    fi
}

# Function to install SSHD with Fail2Ban
install_sshd() {
    install_package ssh
    install_package fail2ban

    # Ask the user for the SSH port
    read -p "Enter the SSH port you want to use (default is 22): " ssh_port
    ssh_port=${ssh_port:-22}

    # Update /etc/ssh/sshd_config with the new port
    echo "Updating /etc/ssh/sshd_config with port $ssh_port..."
    sed -i "/^Port /d" /etc/ssh/sshd_config
    echo "Port $ssh_port" >> /etc/ssh/sshd_config

    # Update /etc/fail2ban/jail.local with the new port
    echo "[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 86400
findtime = 600
maxretry = 3
backend = auto
usedns = warn
protocol = tcp
chain = INPUT
[sshd]
enabled = true
port = $ssh_port
filter = sshd
logpath = /var/log/auth.log
maxretry = 3" > /etc/fail2ban/jail.local

    # Restart SSHD and Fail2Ban to apply changes
    systemctl restart ssh || echo "Failed to restart SSH"
    systemctl restart fail2ban || echo "Failed to restart Fail2Ban"

    echo "SSHD and Fail2Ban installed and configured with port $ssh_port."
}

# Function to install MongoDB
install_mongodb() {
    echo "Installing MongoDB..."
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor || echo "Failed to add MongoDB GPG key"
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list || echo "Failed to add MongoDB repository"
    apt update || echo "Failed to update package list for MongoDB"
    apt install -y mongodb-org || echo "Failed to install MongoDB"
    systemctl enable --now mongod || echo "Failed to enable MongoDB service"
}

# Function to install Composer
install_composer() {
    # Check if PHP is installed
    if ! command -v php &> /dev/null; then
        echo "PHP is not installed. Please install PHP before installing Composer."
        return 1
    fi

    # Install Composer
    echo "Installing Composer..."
    curl -sS https://getcomposer.org/installer -o composer-setup.php || { echo "Failed to download Composer installer."; return 1; }
    
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer || { echo "Composer installation failed."; return 1; }

    echo "Composer installed successfully."

    # Clean up
    rm composer-setup.php || echo "Failed to remove Composer setup script"
}

# Function to install Yarn
install_yarn() {

    # Function to check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    # Check if Node.js is installed
    if command_exists node; then
        echo "Installing Yarn..."
        
        # Update npm to ensure you have the latest version
        npm install -g npm || echo "Failed to update npm"

        # Install Yarn globally using npm
        npm install -g yarn || echo "Failed to install Yarn"
    else
        echo "Node.js is not installed. Installing Node.js first"
        return 1
    fi
}

# Function to install Node.js
install_nodejs() {
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_current.x | bash - || echo "Failed to add Node.js repository"
    apt update && apt install -y nodejs || echo "Failed to install Node.js"
}

# Function to install MSSQL Server
install_mssql_server() {
    echo "Installing MSSQL Server..."
    wget -q -O- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | tee /usr/share/keyrings/microsoft.gpg > /dev/null 2>&1
    echo "deb [signed-by=/usr/share/keyrings/microsoft.gpg arch=amd64,armhf,arm64] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main" | \
    tee /etc/apt/sources.list.d/mssql-server-2022.list
    apt update && apt install -y mssql-server
    systemctl enable mssql-server
    /opt/mssql/bin/mssql-conf setup
}

# Function to install WireGuard Server
install_wireguard_server() {
    echo "Installing WireGuard Server..."
    curl -O https://raw.githubusercontent.com/angristan/wireguard-install/master/wireguard-install.sh || echo "Failed to download WireGuard installation script"
    chmod +x wireguard-install.sh || echo "Failed to set execution permission on WireGuard script"
    ./wireguard-install.sh || echo "Failed to execute WireGuard installation script"
}

# Function to install OpenVPN Server
install_openvpn_server() {
    echo "Installing OpenVPN Server..."
    curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh || echo "Failed to download OpenVPN installation script"
    chmod +x openvpn-install.sh || echo "Failed to set execution permission on OpenVPN script"
    ./openvpn-install.sh || echo "Failed to execute OpenVPN installation script"
}

# Function to install PHP
install_php() {

    echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list && \
    wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg

    # Prompt the user for the PHP version
    read -p "Enter the PHP version you want to install (e.g., 8.1): " php_version

    # Validate the input
    if [[ -z "$php_version" ]]; then
        echo "You must enter a PHP version."
        exit 1
    fi

    # Install PHP and necessary extensions
    echo "Installing PHP $php_version..."
    apt-get update && apt-get install -y php$php_version php$php_version-fpm php$php_version-dev php$php_version-mysqlnd \
    php$php_version-bcmath php$php_version-enchant php$php_version-gmp php$php_version-igbinary php$php_version-imagick \
    php$php_version-intl php$php_version-mbstring php$php_version-mcrypt php$php_version-memcache php$php_version-memcached \
    php$php_version-mysql php$php_version-pdo-dblib php$php_version-redis php$php_version-snmp php$php_version-soap \
    php$php_version-tidy php$php_version-xml php$php_version-opcache php$php_version-curl php$php_version-bz2 \
    php$php_version-zip php$php_version-gd php$php_version-xmlrpc || echo "Failed to install PHP $php_version"

    # Verify installation
    echo "PHP $php_version and its extensions have been installed."
}

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt remove $pkg; done || echo "Failed to remove old Docker packages"

    # Create the directory for storing Docker's GPG key
    install -m 0755 -d /etc/apt/keyrings || echo "Failed to create directory for Docker GPG key"

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc || echo "Failed to add Docker GPG key"

    # Set appropriate permissions for the key
    chmod a+r /etc/apt/keyrings/docker.asc || echo "Failed to set permissions for Docker GPG key"

    # Add the Docker repository to Apt sources
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list || echo "Failed to add Docker repository"

    # Update the package list again to include Docker packages
    apt-get update || echo "Failed to update package list for Docker"

    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || echo "Failed to install Docker"
}

# Function to install MariaDB Server, Client, and Backup
install_mariadb() {
    echo "Installing MariaDB Server, Client, and Backup..."
    install_package mariadb-server
    install_package mariadb-client
    install_package mariadb-backup
}

# Define available apps
web_servers=("nginx" "apache2" "golang" "ruby" "rustc" "default-jdk")
programming_tools=("php" "nodejs")
development_tools=("composer" "yarn")
database_servers=("postgresql" "mariadb" "mssql-server" "mongodb" "redis")
vpn_tools=("wireguard-server" "openvpn-server")
container_tools=("sshd" "docker")

# Convert the list of apps into a format suitable for whiptail
choices=()
for app in "${container_tools[@]}" "${web_servers[@]}" "${programming_tools[@]}" "${development_tools[@]}" "${database_servers[@]}" "${vpn_tools[@]}"; do
    choices+=("$app" "" "OFF")
done

# Display the whiptail checklist dialog
selected_apps=$(whiptail --title "Select Applications to Install" --checklist \
"Use the spacebar to select/deselect options, and Tab to navigate. Press Enter to confirm your choices." 20 78 15 \
"${choices[@]}" 3>&1 1>&2 2>&3)

# Check if the user made any selection
if [ -z "$selected_apps" ]; then
    echo "No applications selected. Exiting."
    selected_apps=()
fi

# Convert the whiptail output into an array
selected_apps=($(echo "$selected_apps" | tr -d '\"'))

# Track if any packages were installed
sshd_selected=false

# Install selected apps
for app in "${selected_apps[@]}"; do
    if [ "$app" == "sshd" ]; then
        install_sshd || echo "Error installing SSHD"
        sshd_selected=true
    elif [[ "${web_servers[@]}" =~ "$app" ]]; then
        install_package "$app" || echo "Error installing $app"
    elif [[ "$app" == "mongodb" ]]; then
        install_mongodb || echo "Error installing MongoDB"
    elif [[ "$app" == "composer" ]]; then
        install_composer || echo "Error installing Composer"
    elif [[ "$app" == "yarn" ]]; then
        install_yarn || echo "Error installing Yarn"
    elif [[ "$app" == "nodejs" ]]; then
        install_nodejs || echo "Error installing Node.js"
    elif [[ "$app" == "mssql-server" ]]; then
        install_mssql_server || echo "Error installing MSSQL Server"
    elif [[ "$app" == "wireguard-server" ]]; then
        install_wireguard_server || echo "Error installing WireGuard Server"
    elif [[ "$app" == "openvpn-server" ]]; then
        install_openvpn_server || echo "Error installing OpenVPN Server"
    elif [[ "$app" == "php" ]]; then
        install_php || echo "Error installing PHP"
    elif [[ "$app" == "docker" ]]; then
        install_docker || echo "Error installing Docker"
    elif [[ "$app" == "mariadb" ]]; then
        install_mariadb || echo "Error installing MariaDB"
    else
        echo "No installation function defined for $app. Skipping."
    fi
done

# Report to the user
echo "Installation complete."

# Print SSH-specific advice only if SSHD was selected
if $sshd_selected; then
    echo "Consider changing the SSH port in /etc/ssh/sshd_config and /etc/fail2ban/jail.local."
fi

echo "Consider selecting a suitable profile for tuned based on server usage with the command 'tuned-adm profile'."

# Ask for reboot after the installation process
read -p "Do you want to reboot now? (Y/n): " reboot_choice
if [[ $reboot_choice =~ ^[Yy]$ ]] || [[ -z $reboot_choice ]]; then
    reboot
else
    echo "You must reboot your system ASAP."
fi
