#!/bin/sh
# -------------------------------------------------
# Add repos and install postgres15
# -------------------------------------------------
sudo apt -y install gnupg
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt update
sudo apt -y install postgresql-15
# -------------------------------------------------
# Add repos and install zabbix
# -------------------------------------------------
sudo wget https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian11_all.deb
sudo dpkg -i zabbix-release_6.4-1+debian11_all.deb
sudo apt update
sudo apt -y install zabbix-server-pgsql zabbix-frontend-php php7.4-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent
sudo -u postgres psql -c "CREATE USER zabbix WITH PASSWORD 'zabbixDBpassword';"
#sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix zabbix
sudo zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
# -------------------------------------------------
# Edit file /etc/zabbix/zabbix_server.conf DBPassword=password
# Edit file /etc/zabbix/nginx.conf uncomment and set 'listen' and 'server_name' directives.
# -------------------------------------------------
sudo sed -i 's/# DBPassword=/DBPassword=zabbixDBpassword/g' /etc/zabbix/zabbix_server.conf
sudo sed -i 's/#        listen          8080;/        listen          8080;/g' /etc/zabbix/nginx.conf
sudo sed -i 's/#        server_name     example.com;/        server_name     myzabbix.net;/g' /etc/zabbix/nginx.conf