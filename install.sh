#!/bin/bash

mkdir 3x-ui
cd 3x-ui

# Define the database path and the SQL statements template (to be modified based on last ID)
DB_PATH="$PWD/db/x-ui.db"
SQL_INSERT_TEMPLATE="
INSERT INTO settings VALUES (%d, 'webCertFile', '/root/cert/3x-ui-public.key');
INSERT INTO settings VALUES (%d, 'webKeyFile', '/root/cert/3x-ui-private.key');
"

# Installing Docker
install_docker() {
    # Removing conficting packages
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

    # Installing Docker using the apt repository
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    # Install the Docker packages
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 
}

# Checking if OpenSSL is installed
check_openssl() {
    if ! command -v openssl &> /dev/null
    then
        echo "openssl could not be found, installing..."
        install_openssl
    else
        echo "openssl is already installed."
    fi
}

# Installing OpenSSL
install_openssl() {
    sudo apt-get update -y && sudo apt-get install -y openssl
}

# Function to check if sqlite3 is installed
check_sqlite3() {
    if ! command -v sqlite3 &> /dev/null
    then
        echo "sqlite3 could not be found, installing..."
        install_sqlite3
    else
        echo "sqlite3 is already installed."
    fi
}

# Function to install sqlite3
install_sqlite3() {
    # Detect the package manager and install sqlite3
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get update -y && sudo apt-get install -y sqlite3
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install -y sqlite
    elif [ -x "$(command -v dnf)" ]; then
        sudo dnf install -y sqlite
    elif [ -x "$(command -v pacman)" ]; then
        sudo pacman -S --noconfirm sqlite
    else
        echo "Package manager not found. Please install sqlite3 manually."
        exit 1
    fi
}

# Function to get the last ID in the settings table
get_last_id() {
    LAST_ID=$(sqlite3 "$DB_PATH" "SELECT IFNULL(MAX(id), 0) FROM settings;")
    echo "The last ID in the settings table is $LAST_ID"
}

# Function to execute SQL inserts
execute_sql_inserts() {
    local next_id=$((LAST_ID + 1))
    local second_id=$((next_id + 1))
    printf "$SQL_INSERT_TEMPLATE" "$next_id" "$second_id" | sqlite3 "$DB_PATH"
    echo "SQL inserts executed with IDs $next_id and $second_id."
}

# Generating SSL certificate
gen_ssl_cert() {
    openssl req -x509 -newkey rsa:4096 -nodes -sha256 -keyout $PWD/cert/3x-ui-private.key -out $PWD/cert/3x-ui-public.key -days 3650 -subj "/CN=APP"
}

# Main script
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y

install_docker
check_openssl
check_sqlite3

sudo docker run -itd \
   -e XRAY_VMESS_AEAD_FORCED=false \
   -v $PWD/db/:/etc/x-ui/ \
   -v $PWD/cert/:/root/cert/ \
   --network=host \
   --restart=unless-stopped \
   --name 3x-ui \
   ghcr.io/mhsanaei/3x-ui:latest

gen_ssl_cert

get_last_id
execute_sql_inserts

sudo docker restart 3x-ui

echo "Installation is successful."
echo "Access the panel at port 2053. Your browser might show a warning about insecure connection because the certificate is self-signed. You can safely ignore it."
echo "IMPORTANT: Please change panel port, web base path and admin credentials in web ui!"
echo "Default user credentials:"
echo "USERNAME: admin"
echo "PASSWORD: admin"
echo "Enjoy the free internet!"