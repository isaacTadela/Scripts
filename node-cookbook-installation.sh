#!/bin/bash


# This script creates a Chef cookbook and have the option to run it
#
# The script requires the exported environment variables:
# VAULT_ADDR        - The ip of vault, e.g. 'http://35.181.48.199:8200'
# VAULT_TOKEN       - The vault token use to access vault, e.g. 's.s.PKhDs2z6SGJBCcPC7wBXRqyk'
# CONSUL_HTTP_ADDR  - API address to the local Consul agent although i used it to remote Consul server, e.g. 'http://35.181.48.199:8500'
#
# If you run this cookbook it will install unzip, mysql-client, awscli, NodeJS, consul-template, download my node appliction and Finally run my app
#
# It will use consul-template to fetch temporary AWS credentials from Vault 
# and get from Consul the latest version tag of my app which reside in an S3 bucket
#
#
# In terms of Chef-solo the flow of things is:
# start a Chef node attached with a     *role* 
# runs the                              *recipe* 
# that generate a file by a             *template* 
# with dynamically injected             *attributes*
# witch get override_attributes by the  *role*


# System
sudo apt update < "/dev/null"
sudo apt -y upgrade < "/dev/null"

# install ChefDK for chef-solo:
wget https://packages.chef.io/files/stable/chefdk/4.9.7/ubuntu/20.04/chefdk_4.9.7-1_amd64.deb
sudo dpkg -i chefdk_4.9.7-1_amd64.deb
rm chefdk_4.9.7-1_amd64.deb


# Make the main directory and sub-directories
mkdir $HOME/Chef && mkdir $HOME/Chef/cookbooks && mkdir $HOME/Chef/script

# Create a script to download and install consul-template binary
echo '#!/bin/bash
wget https://releases.hashicorp.com/consul-template/0.27.0/consul-template_0.27.0_linux_amd64.zip
unzip consul-template_0.27.0_linux_amd64.zip
rm consul-template_0.27.0_linux_amd64.zip
sudo mv consul-template /usr/local/bin/' > $HOME/Chef/script/consul-installation.sh
 
# Create the configuration file for consul-template
echo 'vault {
# Specified via the environment variable VAULT_ADDR, This is the address of the Vault leader.
# address      = "http://$MASTER_IP:8200"

# Specified via the environment variable VAULT_TOKEN, This is the token of the Vault leader.
# token        = "s.root"

default_lease_duration = "60s"

unwrap_token = false
renew_token  = false
}

syslog {
  enabled  = true
  facility = "LOCAL5"
}

consul {
 # Specified via the environment variable CONSUL_HTTP_ADDR, This is the address of the Consul server.
 # address = "http://$MASTER_IP:8500"

 # auth {
 #   enabled = true
 #   username = "test"
 #   password = "test"
 # }
}
 
log_level = "warn"

# render the role with a new version value, temporary aws credentials and re-run Chef-solo
template {
 source = "/home/Chef/script/consul-mysql-npm-role.tpl"
 destination = "/home/Chef/roles/consul-mysql-npm.json"
  exec {
    command = "sudo chef-solo -c /home/Chef/solo.rb -j /home/Chef/runlist.json > /home/consul-template.log"
  }
}' > $HOME/Chef/script/consul-configuration.hcl

# Create the template for the Chef role with the values rendered from consul-template
echo '{
"name": "consul-mysql-npm",
"override_attributes": {
  "consul-mysql-npm": {
    "version": "Vers.erb",
    "attr1": {
      "name": "{{ key "/version" }}",
      "access_key": "{{ with secret "aws/creds/ec2-node-role" "ttl=30s" }}{{ .Data.access_key }}{{ end }}",
      "secret_key": "{{ with secret "aws/creds/ec2-node-role" "ttl=30s" }}{{ .Data.secret_key  }}{{ end }}"
    }
  }
},
"run_list": [
  "recipe[consul-mysql-npm]"
]
}' > $HOME/Chef/script/consul-mysql-npm-role.tpl

# to test run only consul-template to can run 
# consul-template -config $HOME/Chef/script/consul-configuration.hcl > $HOME/consul-template.log 2>&1 &

# Generate cookbook
chef generate cookbook $HOME/Chef/cookbooks/consul-mysql-npm --chef-license accept

# Create the runlist file for Chef
echo '{
 "run_list": [ "role[consul-mysql-npm]" ]
}' > $HOME/Chef/runlist.json

# Create the Chef role with the override_attributes
mkdir $HOME/Chef/roles
echo '{
"name": "consul-mysql-npm",
"override_attributes": {
  "consul-mysql-npm": {
    "version": "Vers.erb",
    "attr1": {
      "name": "Liozzz",
      "access_key": "AKIA2PN",
      "secret_key": "FiuyGnX"
    }
  }
},
"run_list": [
  "recipe[consul-mysql-npm]"
]
}' > $HOME/Chef/roles/consul-mysql-npm.json

# Create the Chef default recipe 
echo '
package "unzip" do
   action :install
 end

 package "mysql-client" do
   action :install
 end
 
 package "awscli" do
   action :install
 end
 
# for Debian and Ubuntu based Linux distributions the Node.js binary distributions are available from NodeSource
 execute "Node.js binary" do
   command "curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash - && sudo apt-get install -y nodejs"
 end

execute "install consul-temaplte" do
   command "sh /home/Chef/script/consul-installation.sh"
   not_if "ps -A | grep consul-template"
 end

execute "run consul-temaplte" do
   command "consul-template -config /home/Chef/script/consul-configuration.hcl > /home/consul-template.log 2>&1 &"
   not_if "ps -A | grep consul-template"
 end

# Create/Update myApp-installation.sh file using the tempalte file "Vers.erb" and the role override_attributes
 template "/home/Chef/script/myApp-installation.sh" do
   source node["consul-mysql-npm"]["version"]
   mode '0644'
 end
 
bash "run myApp-installation.sh, npm install and start" do
   cwd "/home/"
   code <<-EOH
     sh /home/Chef/script/myApp-installation.sh > /home/myApp.log
     cd /home/Unofficial-Chevrolet-Auto-shop && npm install >> /home/myApp.log
     cd /home/Unofficial-Chevrolet-Auto-shop && node server.js & >> /home/myApp.log
   EOH
 end
'> $HOME/Chef/cookbooks/consul-mysql-npm/recipes/default.rb
  
# Create the Chef templates directory
mkdir $HOME/Chef/cookbooks/consul-mysql-npm/templates && mkdir $HOME/Chef/cookbooks/consul-mysql-npm/templates/default

# Create the Chef template
echo '#!/bin/bash
if AWS_ACCESS_KEY_ID=<%=node["consul-mysql-npm"]["attr1"]["access_key"] %> AWS_SECRET_ACCESS_KEY=<%=node["consul-mysql-npm"]["attr1"]["secret_key"] %> aws s3api get-object --bucket unofficial-chevrolet-auto-shop-bucket --key Unofficial-Chevrolet-Auto-shop-<%=node["consul-mysql-npm"]["attr1"]["name"] %>.tar.gz Unofficial-Chevrolet-Auto-shop-<%=node["consul-mysql-npm"]["attr1"]["name"] %>.tar.gz ; then
 tar -xvzf Unofficial-Chevrolet-Auto-shop-<%=node["consul-mysql-npm"]["attr1"]["name"] %>.tar.gz -C /home
 rm -f Unofficial-Chevrolet-Auto-shop-<%=node["consul-mysql-npm"]["attr1"]["name"] %>.tar.gz
 sudo mysql --host=$DB_DNS --port=$DB_PORT --user=$DB_USER --password=$DB_PASS < /home/Unofficial-Chevrolet-Auto-shop/schema.sql
 echo "Downloaded file:  Unofficial-Chevrolet-Auto-shop-<%=node["consul-mysql-npm"]["attr1"]["name"] %>.tar.gz"
else
 echo "Failed to Download file:  Unofficial-Chevrolet-Auto-shop-<%=node["consul-mysql-npm"]["attr1"]["name"] %>.tar.gz"
fi '> Chef/cookbooks/consul-mysql-npm/templates/default/Vers.erb

# Create the attributes directory and the default file
mkdir $HOME/Chef/cookbooks/consul-mysql-npm/attributes
echo 'default["consul-mysql-npm"]["version"] = "Vers"' > $HOME/Chef/cookbooks/consul-mysql-npm/attributes/default.rb
 
# Generate Chef solo config files under the main Chef directory
echo 'current_dir             = File.expand_path(File.dirname(__FILE__))
file_cache_path         "#{current_dir}"
cookbook_path           "#{current_dir}/cookbooks"
role_path               "#{current_dir}/roles"
data_bag_path           "#{current_dir}/data_bags" ' > Chef/solo.rb


# To run this Chef cookbook run the command 
# sudo chef-solo -c $HOME/Chef/solo.rb -j $HOME/Chef/runlist.json --chef-license accept
