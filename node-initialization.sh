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
echo -en '### installed ###\n
$(git --version)
$(chef -v)' > installed

# Download the Chef cookbook
cd $HOME && git clone https://github.com/isaacTadela/Chef.git

# create the configuration file for consul-template
# to render the role with the override_attribute
echo "vault {
# This is the address of the Vault leader.
address      = \"http://$MASTER_IP:8200\"
# This value can also be specified via the environment variable VAULT_TOKEN.
token        = \"root\"
unwrap_token = false
renew_token  = false
}

consul {
 address = \"$MASTER_IP:8500\"

 auth {
   enabled = true
   username = \"test\"
   password = \"test\"
 }
}

log_level = \"warn\"

# render the role with the new value and re run chef-solo
template {
 source = \"$HOME/Chef/script/consul-mysql-npm-role.tpl\"
 destination = \"$HOME/Chef/roles/consul-mysql-npm.json\"
  exec {
    command = \"sudo chef-solo -c $HOME/Chef/solo.rb -j $HOME/Chef/runlist.json > $HOME/consul-template.log \"
  }
}" > $HOME/Chef/script/consul-configuration.hcl


# Run the cookbook
echo 'run: sudo chef-solo -c $HOME/Chef/solo.rb -j $HOME/Chef/runlist.json --chef-license accept'
# echo 'run: sudo chef-solo -c $HOME/Chef/solo.rb -j $HOME/Chef/runlist.json --chef-license accept'
