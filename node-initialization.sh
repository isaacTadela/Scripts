#!/bin/bash

# System 
sudo apt update < "/dev/null"
sudo apt -y upgrade < "/dev/null"
sudo apt -y install unzip < "/dev/null"
sudo apt-get install tree=1.8.0-1 < "/dev/null"

# Git
sudo apt-get install git=1:2.25.1-1ubuntu3 -y

# ChefDK:
wget https://packages.chef.io/files/stable/chefdk/4.9.7/ubuntu/20.04/chefdk_4.9.7-1_amd64.deb
sudo dpkg -i chefdk_4.9.7-1_amd64.deb
rm chefdk_4.9.7-1_amd64.deb

# Check all installed: 
echo -en "### installed ###\n
$(git --version)
$(chef -v)
" > installed


