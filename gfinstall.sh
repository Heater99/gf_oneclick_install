#!/bin/bash

# define colors
RED='\e[0;31m'
GREEN='\e[1;32m'
RC='\e[0m'

# make sure lists are up to date
apt-get -qq update

# install sudo in case it is missing
apt-get -qq install sudo -y

# test for the main folder
if [ -d "/root/GF" ] ; then
	echo "The folder /root/GF already exists, please rename or delete it before running the script."
	echo "Delete existing folder? (y/n)"
	read INVAR
	if [ "$INVAR" != "y" ] && [ "$INVAR" != "Y" ] ; then
		exit
	fi
	rm -rf "/root/GF"
fi
mkdir "/root/GF" -m 777
cd "/root/GF"

# get ip info; select ip
IP=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
if [ "$IP" != "" ] ; then
	echo -e "Select your IP:\n1) IP: $IP\n2) Input other IP"
	read INVAR
else
	INVAR="2"
fi
if [ "$INVAR" = "2" ] ; then
	echo "Please enter IP:"
	read IP
fi

# select server version
echo -e "Select the version you want to install.\n1) blackrockshoote & eperty123 006.58.64.64 (recommended)"
read AKVERSION

# make sure start / stop commands are working
sudo apt-get -qq install psmisc -y

# install wget in case it is missing
sudo apt-get -qq install wget -y

# install unzip in case it is missing
sudo apt-get -qq install unzip -y

# install postgresql in case it is missing
sudo apt-get -qq install postgresql -y
POSTGRESQLVERSION=$(psql --version | cut -c 19-20)

# install pwgen in case it is missing
sudo apt-get -qq install pwgen -y

# generate database password
DBPASS=$(pwgen -s 32 1)

# setup postgresql
cd "/etc/postgresql/$POSTGRESQLVERSION/main"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" postgresql.conf
sed -i "s+host    all             all             127.0.0.1/32            md5+host    all             all             0.0.0.0/0            md5+g" pg_hba.conf

# change password for the postgres account
sudo -u postgres psql -c "ALTER user postgres WITH password '$DBPASS';"

# ready ip for hexpatch
PATCHIP=$(printf '\\x%02x\\x%02x\\x%02x\n' $(echo "$IP" | grep -o [0-9]* | head -n1) $(echo "$IP" | grep -o [0-9]* | head -n2 | tail -n1) $(echo "$IP" | grep -o [0-9]* | head -n3 | tail -n1))

# set version name
VERSIONNAME="NONE"

# set link to RaGEZONE thread
THREADLINK="NONE"

# make sure that vsyscall is emulate
if [ "$(cat /proc/cmdline | grep vsyscall=emulate)" == "" ] ; then
	sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"vsyscall=emulate /g" "/etc/default/grub"
	sudo update-grub
	VSYSCALLWARNING="You have to reboot your system before starting the server, please run ${RED}sudo reboot${RC}"
fi

# --------------------------------------------------
# Blackrockshoote & Eperty123 - 006.58.64.64
# --------------------------------------------------
if [ "$AKVERSION" = 1 ] ; then
	cd "/root/GF"
	wget --no-check-certificate "https://raw.githubusercontent.com/heater99/gf_oneclick_install/master/blackrockshoote_eperty123_006_58_64_64" -O "blackrockshoote_eperty123_006_58_64_64"
	chmod 777 blackrockshoote_eperty123_006_58_64_64
	. "/root/GF/blackrockshoote_eperty123_006_58_64_64"
	
	# config files
	wget --no-check-certificate "$MAINCONFIG" -O "config.zip"
	unzip "config.zip"
	rm -f "config.zip"
	sed -i "s/xxxxxxxx/$DBPASS/g" "setup.ini"
	sed -i "2i\\
	export LC_ALL=C\\
	" "start"
	
	# subservers
	wget --no-check-certificate "$SUBSERVERSID" "Server.zip"
	unzip "Server.zip"
	rm -f "Server.zip"
	sed -i "s/192.168.178.59/$IP/g" "GatewayServer/setup.ini"
	sed -i "s/xxxxxxxx/$DBPASS/g" "GatewayServer/setup.ini"
	sed -i "s/192.168.178.59/$IP/g" "TicketServer/setup.ini"
	sed -i "s/\xc0\xa8\xb2/$PATCHIP/g" "WorldServer/WorldServer"
	sed -i "s/\xc0\xa8\xb2/$PATCHIP/g" "ZoneServer/ZoneServer"
	
	# Data folder
	wget --no-check-certificate "$DATAFOLDER" -O "Data.zip"
	unzip "Data.zip" -d "Data"
	rm -f "Data.zip"
	
	# SQL files
	wget --no-check-certificate "$SQLFILES" -O "SQL.zip"
	unzip "SQL.zip" -d "SQL"
	rm -f "SQL.zip"
	
	# set permissions
	chmod 777 /root -R
	
	# install postgresql database
	service postgresql restart
	sudo -u postgres psql -c "create database gf_gs encoding 'UTF8' template template0;"
	sudo -u postgres psql -c "create database gf_ls encoding 'UTF8' template template0;"
	sudo -u postgres psql -c "create database gf_ms encoding 'UTF8' template template0;"
	sudo -u postgres psql -d gf_gs -c "\i '/root/GF/SQL/gf_gs.bak';"
	sudo -u postgres psql -d gf_ls -c "\i '/root/GF/SQL/gf_ls.bak';"
	sudo -u postgres psql -d gf_ms -c "\i '/root/GF/SQL/gf_ms.bak';"
	sudo -u postgres psql -d gf_ls -c "UPDATE worlds SET ip = '$IP' WHERE ip = '192.168.178.59';"
	sudo -u postgres psql -d gf_gs -c "UPDATE serverstatus SET ext_address = '$IP' WHERE ext_address = '192.168.178.59';"
	
	# remove server setup files
	rm -f blackrockshoote_eperty123_006_58_64_64
	
	#set the server date to 2013
	timedatectl set-ntp 0
	date -s "$(date +'2023%m%d %H:%M')"
	hwclock --systohc
	
	# setup info
	VERSIONNAME="Blackrockshoote & Eperty123 - 006.58.64.64"
	CREDITS="Blackrockshoote & Eperty123 Server and UseresU for OneClick Installer"
	THREADLINK="https://forum.ragezone.com/f857/grand-fantasia-server-files-1210135/"
fi

if [ "$VERSIONNAME" = "NONE" ] ; then
	# display error
	echo -e "${RED}--------------------------------------------------"
	echo -e "Installation failed!"
	echo -e "--------------------------------------------------"
	echo -e "The selected version could not be installed. Please try again and choose a different version.${RC}"
else
	# display info screen
	echo -e "${GREEN}--------------------------------------------------"
	echo -e "Installation complete!"
	echo -e "--------------------------------------------------"
	echo -e "Server version: $VERSIONNAME"
	echo -e "Server IP: $IP"
	echo -e "Postgresql version: $POSTGRESQLVERSION"
	echo -e "Database user: postgres"
	echo -e "Database password: $DBPASS"
	echo -e "Server path: /root/GF"
	echo -e "Postgresql configuration path: /etc/postgresql/$POSTGRESQLVERSION/main/"
	echo -e "Release info / Client download: $THREADLINK"
	echo -e "\nMake sure to thank $CREDITS!"
	echo -e "\nTo start the server, please run /root/GF/start"
	echo -e "To stop the server, please run /root/GF/stop${RC}"
	if [ "$VSYSCALLWARNING" != "" ] ; then
		echo -e "\n$VSYSCALLWARNING"
	fi
fi
