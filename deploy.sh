#!/bin/bash

=================================================================

Laravel Deployment Script (Ubuntu/Debian)

Installs Nginx, PHP (User Version), MySQL (User Version), and Git

=================================================================

Color variables for better output

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Welcome to the Laravel Auto-Deployment Script!${NC}"

Check for root privileges

if [[ $EUID -ne 0 ]]; then
echo -e "${RED}This script must be run as root (use sudo).${NC}"
exit 1
fi

1. Gather User Information

read -p "Enter your Git Repository URL: " GIT_REPO
read -p "Enter the Domain Name (e.g., example.com): " DOMAIN_NAME
read -p "Enter PHP version to install (e.g., 8.2, 8.3): " PHP_VERSION
read -p "Enter MySQL version to install (e.g., 8.0 or leave empty for default): " MYSQL_VERSION

Set default directory

PROJECT_DIR="/var/www/$DOMAIN_NAME"

2. Update System and Add Repositories

echo -e "${GREEN}Updating system and adding repositories...${NC}"
apt update && apt upgrade -y
apt install -y software-properties-common curl git zip unzip

Add PHP PPA (Ondrej) for specific versions

add-apt-repository -y ppa:ondrej/php
apt update

3. Install Nginx

echo -e "${GREEN}Installing Nginx...${NC}"
apt install -y nginx

4. Install PHP and Extensions

echo -e "${GREEN}Installing PHP $PHP_VERSION...${NC}"
apt install -y "php$PHP_VERSION-fpm" "php$PHP_VERSION-mysql" "php$PHP_VERSION-common" 

"php$PHP_VERSION-mbstring" "php$PHP_VERSION-xml" "php$PHP_VERSION-zip" \
"php$PHP_VERSION-bcmath" "php$PHP_VERSION-curl" "php$PHP_VERSION-gd" "php$PHP_VERSION-intl"

5. Install MySQL

if [ -n "$MYSQL_VERSION" ]; then
echo -e "${GREEN}Installing MySQL $MYSQL_VERSION...${NC}"
# This installs the default if a specific repo isn't pre-configured,
# but apt usually handles versioning via its own logic or specific keys.
apt install -y mysql-server
else
echo -e "${GREEN}Installing default MySQL server...${NC}"
apt install -y mysql-server
fi

6. Install Composer

echo -e "${GREEN}Installing Composer...${NC}"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

7. Clone Repository and Setup Laravel

echo -e "${GREEN}Cloning project into $PROJECT_DIR...${NC}"
mkdir -p "$PROJECT_DIR"
git clone "$GIT_REPO" "$PROJECT_DIR"

cd "$PROJECT_DIR"

Install dependencies

echo -e "${GREEN}Installing Composer dependencies...${NC}"
export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-interaction --prefer-dist --optimize-autoloader

Environment file setup

if [ -f ".env.example" ]; then
cp .env.example .env
echo -e "${GREEN}Created .env from .env.example. Please update your DB credentials manually.${NC}"
fi

Generate App Key

php artisan key:generate

8. Set Permissions

echo -e "${GREEN}Setting file permissions...${NC}"
chown -R www-data:www-data "$PROJECT_DIR"
find "$PROJECT_DIR" -type f -exec chmod 644 {} ;
find "$PROJECT_DIR" -type d -exec chmod 755 {} ;
chmod -R 775 "$PROJECT_DIR/storage"
chmod -R 775 "$PROJECT_DIR/bootstrap/cache"

9. Configure Nginx Server Block

echo -e "${GREEN}Configuring Nginx...${NC}"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN_NAME"

cat < "$NGINX_CONF"
server {
listen 80;
server_name $DOMAIN_NAME;
root $PROJECT_DIR/public;

add_header X-Frame-Options "SAMEORIGIN";
add_header X-XSS-Protection "1; mode=block";
add_header X-Content-Type-Options "nosniff";

index index.php index.html index.htm;

charset utf-8;

location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
}

location = /favicon.ico { access_log off; log_not_found off; }
location = /robots.txt  { access_log off; log_not_found off; }

error_page 444 /index.php;

location ~ \.php$ {
    fastcgi_pass unix:/var/run/php/php$PHP_VERSION-fpm.sock;
    fastcgi_index index.php;
    fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
    include fastcgi_params;
}

location ~ /\.(?!well-known).* {
    deny all;
}


}
EOF

Enable the site and restart Nginx

ln -s "$NGINX_CONF" "/etc/nginx/sites-enabled/" 2>/dev/null
nginx -t && systemctl restart nginx
systemctl restart "php$PHP_VERSION-fpm"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}Laravel Installation Complete!${NC}"
echo -e "Your project is located at: $PROJECT_DIR"
echo -e "Nginx is configured for: http://$DOMAIN_NAME"
echo -e "${RED}IMPORTANT: Don't forget to update your .env with your MySQL credentials!${NC}"
echo -e "${GREEN}====================================================${NC}"