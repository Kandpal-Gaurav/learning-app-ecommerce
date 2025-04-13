#! /bin/bash

os=""
package_manager=""

function color_print(){
  GREEN="\033[1;32m"
  RED="\033[1;31m"
  YELLOW="\033[1;33m"
  NC="\033[0m"
  color=""

  if [ $1 = "green" ]
  then
    color=$GREEN  
  elif [ $1 = "red" ]
  then
    color=$RED
  elif [ $1 = "yellow" ]
  then
    color=$YELLOW
  else
    color=$NC
  fi

  echo -e "${color} $2 ${NC}"  
}

function start_enable_service(){
  service=$1
  sudo systemctl start $service
  sudo systemctl enable $service
  color_print green "[+] Success: ${service} enabled and started "
}

function check_package(){
  package_manager=$1
  if [ $package_manager = "yum" ]
  then
    yum list installed $2

  elif [ $package_manager = "apt" ]
  then
     dpkg-query -l $2
  fi

}
function install_softwares(){
  package_manager=""
  os=$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
  case $os in
    Ubuntu) package_manager="apt"
      ;;
    "CentOS Stream") package_manager="yum"
      ;;
    *) color_print red "[x] Error: Package Manager not set for $os"
      exit 1;;      
  esac
  if [ -e packages.txt ]
  then
    for package in $( cat packages.txt )
    do
      color_print green "[+] checking package ${package}"
      check_package $package_manager $package > /dev/null 2>&1
      if [ $? -eq 0 ]
      then
        color_print yellow "[-] Warning: already installed ${package}"
      else
        sudo $package_manager install -y ${package} > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
          color_print yellow "[+] Success: Installed successfully"
        fi
      fi
    done
  else
    color_print red "[x] Error: File not found packages.txt"
  fi

  # logic to start and enable services
  start_enable_service firewalld
  start_enable_service mariadb
  start_enable_service httpd
}

function config_fw_port(){
  port=$1
  sudo firewall-cmd --list-ports | grep $port > /dev/null 2>&1
  if [ $? = 1 ]
  then
    sudo firewall-cmd --permanent --zone=public --add-port=${port}/tcp
    sudo firewall-cmd --reload
    if [ $? -eq 0 ]
    then
      color_print green "[+] Success: Firewall rule successfully added for port ${port}"
    else
      color_print red "[x] Error: Firewall rule not created for port ${port}"
    fi
  else
    color_print yellow "[-] Warning: Already found port ${port}"
  fi
}

# 3. Configure Database
function configure_database(){
  cat > setup-db.sql <<-EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
EOF
  sudo mysql < setup-db.sql
  
  if [ $? -eq 0 ]
  then
    color_print green "[+] Success: Successfully configured database"
  fi

  # Create and run db-load-script.sql
  cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;
INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

  sudo mysql < db-load-script.sql
  if [ $? -eq 0 ]
  then
    color_print green "[+] Success: Successfully loaded data to database"
  fi
}

function check_database(){
    web_page=$(curl http://localhost)
    for item in Laptop Drone VR Watch Phone
    do
      check_item "$web_page" $item
    done
}
function check_item(){
  if [[ $1 = *$2* ]]
  then
    color_print "green" "Item $2 is present on the web page"
  else
    color_print "red" "Item $2 is not present on the web page"
  fi
}

function setup_app(){
  # sh cd /var/www/html/
  color_print green "[+] Cloning repository-----------------------------------------"
  git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/
  if [ -e /var/www/html/index.php ]
  then
    color_print green "[+] Successfully cloned to /var/www/html/"
    sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf
    sudo sed -i 's/$link = mysqli_connect($dbHost, $dbUser, $dbPassword, $dbName);/$link = mysqli_connect("localhost", "ecomuser", "ecompassword", "ecomdb");/g' /var/www/html/index.php
    # sudo sed -i s'/172.20.1.101/localhost/g' /var/www/html/index.php
  else
    color_print red "[x] Cloning failed"
  fi
}



function setup_env(){
  cat > /var/www/html/.env <<-EOF
DB_HOST=localhost
DB_USER=ecomuser
DB_PASSWORD=ecompassword
DB_NAME=ecomdb
EOF
  if [ $? -eq 0 ]
  then
    color_print green "[+] Success: Created .env file in /var/www/html/"
  else
    color_print red "[x] Error: Failed to create .env file in /var/www/html"
  fi
}

function main(){

  install_softwares
  configure_database
  setup_app
  setup_env
  check_database
  config_fw_port 80
  config_fw_port 3306
}

main
