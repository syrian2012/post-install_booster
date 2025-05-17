#!/bin/bash

trap 'echo "An error occurred in the script."' ERR

# Update the system
echo "Updating the system..."
dnf update -y || echo "Failed to update the system"

if ! rpm -q "bat" &> /dev/null; then
# Install basic tools including whiptail and iptables
echo "Installing epel repo..."
dnf install epel-release -y && dnf update -y

# Install basic tools including whiptail and iptables
echo "Installing basic tools..."
dnf install -y gnupg2 newt make firewalld chrony tuned htop btop nload git ncdu dnf-plugins-core fzf curl gnupg wget net-tools dnsutils syslog-ng bash-completion neofetch nano bat || echo "Failed to install some basic tools"

systemctl enable --now chronyd

# install nohang
echo "installing nohang..."
git clone https://github.com/hakavlad/nohang.git
cd nohang
sudo make install || { echo "Failed to install nohang"; return 1; }
cd ..
rm -rf nohang
systemctl enable --now nohang || { echo "Failed to enable nohang service"; return 1; }

# install icp
echo "installing icp..."
wget https://github.com/syrian2012/icp/releases/download/V1.1/icp-1.1-1.el9.noarch.rpm
dnf install -y ./icp-1.1-1.el9.noarch.rpm
rm -rf icp-1.1-1.el9.noarch.rpm

# Update bashrc file
echo "alias ll='ls -l'

HISTTIMEFORMAT='[%d.%m.%y] %T   '

memtop() {
  ps -e -o rss=,args= |
    awk '{ print $1 " " $2 }' |
    awk '{
      tot[$2] += $1
      count[$2]++
    }
    END {
      for (i in tot)
        print tot[i], i, count[i]
    }' |
    sort -n |
    tail -n 15 |
    sort -nr |
    awk '{
      hr = $1/1024/1024
      printf("%13.2fG\t%s\n", hr, $2)
    }'
}

export PS1='[\A][\u@\H \W]\\$ '

export EDITOR=nano

export HISTSIZE=10000
export HISTTIMEFORMAT

" >> .bashrc

cat <<EOF >> ~/.bashrc

# FZF Configuration
source /usr/share/fzf/shell/key-bindings.bash
show_file_or_dir_preview="if [ -d {} ]; then ls {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '\$show_file_or_dir_preview'"
EOF
fi

# Function to install a package
install_package() {
    package=$1
    if ! rpm -q "$package" &>/dev/null; then
        echo "Installing $package..."
        dnf install -y "$package" || { echo "Failed to install $package"; return 1; }
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
    install_package openssh-server
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
logpath = /var/log/secure
maxretry = 3" > /etc/fail2ban/jail.local

    #enabe firewalld service
    systemctl enable --now firewalld || echo "Failed to enable firewalld"
    
    #enable ssh port on firewall
    firewall-cmd --add-port=$ssh_port/tcp --permanent 
    firewall-cmd --reload

    #disable selinux
    sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

    echo "SSHD and Fail2Ban installed and configured with port $ssh_port."

    echo "firewalld has been enabled and configured with port $ssh_port."

    echo "selinux has been disabled you must reboot now"

    echo "rebooting in 30 seconds"

    sleep 30 && reboot 
}

install_mongodb() {
    echo "Installing MongoDB..."

    # Add MongoDB repository
    cat > /etc/yum.repos.d/mongodb-org-7.0.repo <<EOF
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-7.0.asc
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to add MongoDB repository"
        return 1
    fi

    # Install MongoDB
    dnf install -y mongodb-org || { echo "Failed to install MongoDB"; return 1; }

    # Enable and start MongoDB service
    systemctl enable --now mongod || { echo "Failed to enable MongoDB service"; return 1; }

    echo "MongoDB installation completed successfully."
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
    curl -fsSL https://rpm.nodesource.com/setup_current.x | bash - || { echo "Failed to add Node.js repository"; return 1; }
    dnf install -y nodejs || { echo "Failed to install Node.js"; return 1; }
}

# Function to install MSSQL Server
install_mssql_server() {
    echo "Installing MSSQL Server..."
    
    # Add Microsoft repository
    curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2022.repo || { echo "Failed to add MSSQL repository"; return 1; }

    # Install MSSQL Server
    dnf install -y mssql-server || { echo "Failed to install MSSQL Server"; return 1; }

    # Enable and start MSSQL Server
    systemctl enable --now mssql-server || { echo "Failed to enable MSSQL Server"; return 1; }

    # Run MSSQL configuration setup
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

install_php() {
    # Enable EPEL and Remi repositories for PHP
    dnf install -y https://rpms.remirepo.net/enterprise/remi-release-8.rpm || { echo "Failed to add Remi repository"; return 1; }

    # Prompt the user for the PHP version
    read -p "Enter the PHP version you want to install (e.g., 8.1): " php_version

    # Validate the input
    if [[ -z "$php_version" ]]; then
        echo "You must enter a PHP version."
        exit 1
    fi

    # Enable the specific PHP module
    dnf module reset php -y
    dnf module enable php:remi-$php_version -y || { echo "Failed to enable PHP $php_version module"; return 1; }

    # Install PHP and necessary extensions
    echo "Installing PHP $php_version..."
    dnf install -y php php-fpm php-devel php-mysqlnd php-bcmath php-enchant php-gmp php-pecl-igbinary php-pecl-imagick \
    php-intl php-mbstring php-mcrypt php-pecl-memcache php-pecl-memcached php-pdo php-pecl-redis php-snmp php-soap \
    php-tidy php-xml php-opcache php-curl php-bz2 php-zip php-gd php-xmlrpc || { echo "Failed to install PHP $php_version"; return 1; }

    # Verify installation
    echo "PHP $php_version and its extensions have been installed."
}


# Function to install Docker
install_docker() {
    echo "Installing Docker..."

    # Add the Docker repository
    dnf config-manager -y --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  
    # installing docker packages
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    #installing ctop
    wget https://github.com/bcicen/ctop/releases/download/v0.7.1/ctop-0.7.1-linux-amd64  -O /usr/local/bin/ctop
    chmod +x /usr/local/bin/ctop

    #installing lazydocker
    curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

    # installing docker bash tools
    git clone https://github.com/syrian2012/docker_bash_tools.git

    cat docker_bash_tools/code_in_bashrc >> ~/.bashrc

    rm -rf docker_bash_tools/

    systemctl enable --now docker || { echo "Failed to enable docker service"; return 1; }
}

# Function to install MariaDB Server, Client, and Backup
install_mariadb() {
    echo "Installing MariaDB Server, Client, and Backup..."
    install_package mariadb-server
    install_package mariadb
    install_package mariadb-backup
}

# Define available apps
web_servers=("nginx" "httpd" "golang" "ruby" "rustc" "default-jdk")
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
