#!/bin/bash

# Install Zabbix Server on Ubuntu
# Based on: https://linuxtldr.com/install-zabbix-server-on-ubuntu/

# Set locale to en_US
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

# Exit on error
set -e

# Update system
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install required dependencies
echo "Installing dependencies..."
sudo apt install -y wget curl software-properties-common

# Add Zabbix repository
echo "Adding Zabbix repository..."
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu$(lsb_release -rs)_all.deb
sudo dpkg -i zabbix-release_6.4-1+ubuntu$(lsb_release -rs)_all.deb
sudo apt update

# Install Zabbix server, frontend and agent
echo "Installing Zabbix components..."
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Install MySQL server
echo "Installing MySQL server..."
sudo apt install -y mysql-server

# Secure MySQL installation
echo "Securing MySQL installation..."
sudo mysql_secure_installation

# Create Zabbix database
echo "Creating Zabbix database..."
read -s -p "Enter MySQL root password: " mysqlrootpass
echo
read -p "Enter Zabbix database name [zabbix]: " zbxdbname
zbxdbname=${zbxdbname:-zabbix}
read -p "Enter Zabbix database user [zabbix]: " zbxdbuser
zbxdbuser=${zbxdbuser:-zabbix}
read -s -p "Enter Zabbix database password: " zbxdbpass
echo

echo "Creating database and user..."
sudo mysql -uroot -p"$mysqlrootpass" <<EOF
create database $zbxdbname character set utf8mb4 collate utf8mb4_bin;
create user '$zbxdbuser'@'localhost' identified by '$zbxdbpass';
grant all privileges on $zbxdbname.* to '$zbxdbuser'@'localhost';
set global log_bin_trust_function_creators = 1;
EOF

# Import initial schema and data
echo "Importing Zabbix schema..."
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | sudo mysql -uroot -p"$mysqlrootpass" $zbxdbname

# Disable log_bin_trust_function_creators
sudo mysql -uroot -p"$mysqlrootpass" -e "set global log_bin_trust_function_creators = 0;"

# Configure Zabbix server
echo "Configuring Zabbix server..."
sudo sed -i "s/# DBPassword=/DBPassword=$zbxdbpass/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/DBName=zabbix/DBName=$zbxdbname/" /etc/zabbix/zabbix_server.conf
sudo sed -i "s/DBUser=zabbix/DBUser=$zbxdbuser/" /etc/zabbix/zabbix_server.conf

# Configure PHP for Zabbix frontend
echo "Configuring PHP settings..."
sudo sed -i 's/post_max_size = 8M/post_max_size = 16M/' /etc/php/*/apache2/php.ini
sudo sed -i 's/max_execution_time = 30/max_execution_time = 300/' /etc/php/*/apache2/php.ini
sudo sed -i 's/max_input_time = 60/max_input_time = 300/' /etc/php/*/apache2/php.ini

# Restart services
echo "Restarting services..."
sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2

# Get server IP address
ip_address=$(hostname -I | awk '{print $1}')

echo "Zabbix installation completed!"
echo "You can access the Zabbix web interface at: http://$ip_address/zabbix"
echo "Default credentials: Admin / zabbix"
