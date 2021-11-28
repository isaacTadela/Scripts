#!/bin/bash


# Update and Upgrade the system
sudo apt update < "/dev/null"
sudo apt -y upgrade < "/dev/null"

# Install Git, unzip, tree, AWScli, Java11
sudo apt install git=1:2.25.1-1ubuntu3 -y
sudo apt install unzip=6.0-25ubuntu1
sudo apt install tree=1.8.0-1
sudo apt -y install awscli=1.18.69-1ubuntu0.20.04.1
sudo apt install openjdk-11-jdk=11.0.11+9-0ubuntu2~20.04 -y < "/dev/null"

# Jenkines Long Term Support:
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install jenkins=2.303.3 -y < "/dev/null"

# Configure the servers to start at boot
sudo systemctl enable jenkins.service  
sudo systemctl start jenkins --no-pager
sudo systemctl status jenkins --no-pager

# Hashicorp Terraform:
wget https://releases.hashicorp.com/terraform/1.0.9/terraform_1.0.9_linux_amd64.zip
unzip terraform_1.0.9_linux_amd64.zip < "/dev/null"
rm terraform_1.0.9_linux_amd64.zip
# Move folder to use/bin and check installation
sudo mv terraform /usr/bin/

# Hashicorp Vault:
wget https://releases.hashicorp.com/vault/1.8.3/vault_1.8.3_linux_amd64.zip
unzip vault_1.8.3_linux_amd64.zip < "/dev/null"
rm vault_1.8.3_linux_amd64.zip 
sudo mv vault /usr/bin/

sudo mkdir /etc/vault
echo '
storage "consul" {
  address = "0.0.0.0:8500"
  path = "vault/"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = 1
  
  # tls_disable = 0 , in case you want to use the tls_cert_file and tls_key_file
  tls_cert_file = "/etc/letsencrypt/live/127.0.0.1/fullchain.pem"
  tls_key_file = "/etc/letsencrypt/live/127.0.0.1/privkey.pem"
}
ui = true' | sudo tee /etc/vault/config.hcl

echo '[Unit]
Description=Vault
Documentation=https://www.vault.io/
[Service]
ExecStart=/usr/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target' | sudo tee /etc/systemd/system/vault.service


sudo systemctl daemon-reload --no-pager 
# Configure the servers to start at boot
sudo systemctl enable vault.service  
sudo systemctl start vault --no-pager
sudo systemctl status vault --no-pager


# Hashicorp Consul: 
wget https://releases.hashicorp.com/consul/1.10.3/consul_1.10.3_linux_amd64.zip
unzip consul_1.10.3_linux_amd64.zip < "/dev/null"
rm consul_1.10.3_linux_amd64.zip
sudo mv consul /usr/bin/
 
# create a service file and move to /usr/bin/
sudo echo "[Unit]
Description=Consul
Documentation=https://www.consul.io/
[Service]
ExecStart=/usr/bin/consul agent -server -ui -data-dir=/temp/consul -bootstrap-expect=1 -node=vault -bind=0.0.0.0 -config-dir=/etc/consul.d/
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/consul.service

sudo mkdir /etc/consul.d

echo '{
  "addresses": {
    "http": "0.0.0.0"
  }
}' | sudo tee /etc/consul.d/consul.hcl
 
sudo systemctl daemon-reload
# Configure the servers to start at boot
sudo systemctl enable consul.service  
sudo systemctl start consul --no-pager
sudo systemctl status consul --no-pager

# Grafana the latest OSS edition
sudo apt install -y apt-transport-https < "/dev/null"
sudo apt install -y software-properties-common wget < "/dev/null"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt update
sudo apt install grafana < "/dev/null"

sudo systemctl daemon-reload --no-pager
# Configure the servers to start at boot
sudo systemctl enable grafana-server.service  
sudo systemctl start grafana-server --no-pager
sudo systemctl status grafana-server --no-pager
 
# Set AWS cli creds  
echo AWS_ACCESS_KEY_ID= | sudo tee -a /etc/environment 
echo AWS_SECRET_ACCESS_KEY= | sudo tee -a /etc/environment  
 
# Set jenkins password fo easier access   
export "JENKINS_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo "JENKINS_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)" | sudo tee -a /etc/environment

# save the password for other idea
sudo sh -c "echo 'JENKINS_PASS=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)' >> /var/lib/jenkins/pass"

# Set VAULT_ADDR for vault init 
export VAULT_ADDR='http://127.0.0.1:8200'
echo "VAULT_ADDR='http://127.0.0.1:8200'" | sudo tee -a /etc/environment

# Set env variables for Terraform 
export TF_VAR_VAULT_ADDR=$(curl ifconfig.me):8200
echo TF_VAR_VAULT_ADDR=$(curl ifconfig.me):8200 | sudo tee -a /etc/environment  

export TF_VAR_MASTER_IP=$(curl ifconfig.me)
echo TF_VAR_MASTER_IP=$(curl ifconfig.me) | sudo tee -a /etc/environment  


## Save the vault unseal keys and token, these are only generated *once* 
## and should be saved and moved to a safe place
# Output all tokens and keys to 'Tokens':
echo -en "### Tokens and Keys ###\n 
JENKINS_PASS=$JENKINS_PASS\n
$(vault operator init)
"> Tokens 

# Vault ENV variables
export VAULT_TOKEN=$(grep 'Initial Root Token:' Tokens | awk '{print $NF}')
echo VAULT_TOKEN=$VAULT_TOKEN | sudo tee -a /etc/environment  
export VAULT_ADDR='http://127.0.0.1:8200'
echo VAULT_ADDR=$VAULT_ADDR | sudo tee -a /etc/environment  

# Vault ENV variables for terraform
export TF_VAR_MASTER_IP=$(curl ifconfig.me)
export TF_VAR_VAULT_TOKEN=$VAULT_TOKEN
echo TF_VAR_MASTER_IP=$TF_VAR_MASTER_IP | sudo tee -a /etc/environment  
echo TF_VAR_VAULT_TOKEN=$TF_VAR_VAULT_TOKEN | sudo tee -a /etc/environment  

# Vault auto-unseal
export VAULT_KEY1=$(grep 'Unseal Key 1:' Tokens | awk '{print $NF}')
export VAULT_KEY2=$(grep 'Unseal Key 2:' Tokens | awk '{print $NF}')
export VAULT_KEY3=$(grep 'Unseal Key 3:' Tokens | awk '{print $NF}')

vault operator unseal $VAULT_KEY1
vault operator unseal $VAULT_KEY2
vault operator unseal $VAULT_KEY3
vault login $VAULT_TOKEN

export MY_PUBLIC_IP=$(curl ifconfig.me)

# Set VAULT_ADDR for vault init 
export VAULT_ADDR='http://127.0.0.1:8200'
echo "VAULT_ADDR='http://127.0.0.1:8200'" | sudo tee -a /etc/environment

# Set CONSUL_HTTP_ADDR for consul 
export CONSUL_HTTP_ADDR='http://127.0.0.1:8500'
echo CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR | sudo tee -a /etc/environment  
consul kv put version test

# Output all installed versions to 'installed' for tracking:
echo -en "### installed ###\n
$(git --version)
$(aws --version)
$(java --version)
jenkins  $(java -jar /usr/share/jenkins/jenkins.war --version)
$(terraform --version | head -n 1)
$(vault -v)
$(consul -v | head -n 1)
Grafana $(grafana-server -v)
\n### Links ###\n
Jenkines is on http://$MY_PUBLIC_IP:8080
Vault is on http://$MY_PUBLIC_IP:8200
Consul is on http://$MY_PUBLIC_IP:8500
Grafana is on http://$MY_PUBLIC_IP:3000
"> installed

clear;

echo '
# Add your AWS credentials as environment variables for all users and Terraform
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
echo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID | sudo tee -a /etc/environment  
echo AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY | sudo tee -a /etc/environment  
export TF_VAR_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export TF_VAR_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
echo TF_VAR_AWS_ACCESS_KEY_ID=$TF_VAR_AWS_ACCESS_KEY_ID | sudo tee -a /etc/environment  
echo TF_VAR_AWS_SECRET_ACCESS_KEY=$TF_VAR_AWS_SECRET_ACCESS_KEY | sudo tee -a /etc/environment  '


