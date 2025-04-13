#! /bin/bash


# Install Firewall
sudo yum install -y firewalld
sudo systemctl start firewalld
sudo systemctl enable firewalld
sudo systemctl status firewalld


# Deploy and Configure Database
# 1. Install MariaDB
sudo yum install -y mariadb-server
sudo systemctl start mariadb
sudo systemctl enable mariadb

# 2. Configure firewall for Database
sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload

# 3. Configure Database
# Create and run setup-db.sql
cat > setup-db.sql <<-EOF
  CREATE DATABASE ecomdb;
  CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
  GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
  FLUSH PRIVILEGES;
EOF
sudo mysql < setup-db.sql

# Create and run db-load-script.sql
cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

sudo mysql < db-load-script.sql


# 4. Deploy and configure WEB
sudo yum install -y httpd php php-mysqlnd
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload
# sudo sed -i 's#// \(.*mysqli_connect.*\)#\1#' /var/www/html/index.php
# sudo sed -i 's#// \(\$link = mysqli_connect(.*172\.20\.1\.101.*\)#\1#; s#^\(\s*\)\(\$link = mysqli_connect(\$dbHost, \$dbUser, \$dbPassword, \$dbName);\)#\1// \2#' /var/www/html/index.php
# sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

sudo yum install -y git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/
sudo sed -i 's#// \(.*mysqli_connect.*\)#\1#' /var/www/html/index.php
sudo sed -i 's#// \(\$link = mysqli_connect(.*172\.20\.1\.101.*\)#\1#; s#^\(\s*\)\(\$link = mysqli_connect(\$dbHost, \$dbUser, \$dbPassword, \$dbName);\)#\1// \2#' /var/www/html/index.php
sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

cat > /var/www/html/.env <<-EOF
DB_HOST=localhost
DB_USER=ecomuser
DB_PASSWORD=ecompassword
DB_NAME=ecomdb
EOF
