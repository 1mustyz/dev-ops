#!/bin/bash

set -e

echo "Updating package metadata..."
sudo dnf clean all
sudo dnf makecache

echo "Installing MariaDB server..."
sudo dnf install -y mariadb-server

echo "Configuring MariaDB to listen on all interfaces..."

MYSQL_CONFIG="/etc/my.cnf.d/mariadb-server.cnf"

if grep -q "^bind-address" "$MYSQL_CONFIG"; then
    sudo sed -i 's/^bind-address.*/bind-address=0.0.0.0/' "$MYSQL_CONFIG"
else
    echo "bind-address=0.0.0.0" | sudo tee -a "$MYSQL_CONFIG"
fi

echo "Starting MariaDB service..."

sudo systemctl enable mariadb
sudo systemctl start mariadb

echo "Configuring MariaDB users..."

sudo mysql <<EOF

-- Remove root password and allow local root access
ALTER USER 'root'@'localhost' IDENTIFIED BY '';

-- Create application user
CREATE USER IF NOT EXISTS 'nodeuser'@'192.168.56.12' IDENTIFIED BY 'mypassword';

-- Grant privileges
GRANT ALL PRIVILEGES ON nodeuser.* TO 'nodeuser'@'192.168.56.12';

-- Apply changes
FLUSH PRIVILEGES;

EOF

echo "Restarting MariaDB..."

sudo systemctl restart mariadb

echo "MariaDB installation and configuration completed successfully."

echo "Testing connection:"
sudo mysql -e "SELECT VERSION();"