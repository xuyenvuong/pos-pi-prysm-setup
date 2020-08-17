#!/bin/bash

echo "******** File setupMyEth2Node.sh - A script to quickly setup ETH2.0"
echo "************************* Author: MAX VUONG ***********************"

TITLE="System Information for $HOSTNAME"
RIGHT_NOW=$(date +"%x %r %Z")
TIME_STAMP="Updated on $RIGHT_NOW by $USER"

set -eu

# Predefine downloads endpoints
configURL="https://cdn.discordapp.com/attachments/726496972277809284/743626826252943400/configs.20200813.zip"
grafanaURL="https://dl.grafana.com/oss/release/grafana_7.0.3_arm64.deb"
cryptowatchURL="https://github.com/nbarrientos/cryptowat_exporter/archive/e4bcf6e16dd2e04c4edc699e795d9450dee486ab.zip"
gethURL="https://gethstore.blob.core.windows.net/builds/geth-linux-arm64-1.9.19-3e064192.tar.gz"
pythonURL="https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz"




##### Functions
function install_package() {
  local dpkg_name=$1

  if [ $(dpkg-query -W -f='${Status}' $dpkg_name 2>/dev/null | grep -c "ok installed") -eq 0 ]
  then
    echo "Installing... $dpkg_name"
    sudo apt install -y $dpkg_name
  fi
}

function create_dir() {
  local dir=$1

  if [ ! -d $dir ]
  then
    mkdir -p $dir
    echo "Create: $dir"
  fi
}

function install_docker() {
 sudo apt-get update
 sudo apt-get install docker-ce docker-ce-cli containerd.io

 sudo groupadd docker
 sudo usermod -aG docker $USER

 newgrp docker

 sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
 sudo chmod g+rwx "$HOME/.docker" -R


 sudo systemctl daemon-reload
 sudo systemctl enable docker
 sudo systemctl restart docker.service
}

function downloads() {
  # Download Pryms programs
  $HOME/prysm/prysm.sh beacon-chain --download-only
  $HOME/prysm/prysm.sh validator --download-only
  $HOME/prysm/prysm.sh slasher --download-only

  # Download Grafana
  if [! -e /tmp/grafana.deb]
  then
    wget -O /tmp/grafana.deb $grafanaURL
  fi

  # Download Python
  if [! -e /tmp/python.tgz]
  then
    wget -O /tmp/python.tgz $pythonURL
    mkdir -p /tmp/Python
    tar -C /tmp/Python --strip-components 1 -xvf /tmp/python.tgz
  fi

  # Download Eth2.0 Deposit CLI
  if [! -d $HOME/eth2.0-deposit-cli]
  then
    git clone https://github.com/ethereum/eth2.0-deposit-cli.git  $HOME/eth2.0-deposit-cli
  fi

  # Download GETH
  if [! -e /tmp/geth.tar.gz]
  then
    wget -O /tmp/geth.tar.gz $gethURL
    mkdir -p /tmp/Geth
    tar -C /tmp/Geth --strip-components 1 -xvf /tmp/geth.tar.gz
    sudo cp -a /tmp/Geth/geth /usr/local/bin
  fi

  # Download cryptowatch
  if [! -e /tmp/cryptowatch.zip]
  then
    wget -O /tmp/cryptowatch.zip $cryptowatchURL
    unzip -j /tmp/cryptowatch.zip -d $HOME/cryptowatch
  fi

}

function install() {
  echo "Install....."
  exit 0


  install_docker





  # Update & Upgrade to latest
  sudo apt-get update && sudo apt-get upgrade

  # Install independent packages
  install_package vim
  install_package git-all
  install_package prometheus
  install_package prometheus-node-exporter
  install_package golang
  install_package zip
  install_package unzip
  install_package build-essential
  install_package python3-venv
  install_package python3-pip

  # Define setup directories
  mkdir -p $HOME/{.eth2,.eth2stats,.eth2validators,.ethereum,.password,logs,prysm/configs}
  mkdir -p /etc/ethereum
  mkdir -p /home/prometheus/node-exporter

  # Create files
  touch $HOME/.password/password.txt
  touch $HOME/logs/{beacon,validator,slasher}.log

  # Clone configs repo
  if [! -d /tmp/configs ]
  then
    git clone https://github.com/xuyenvuong/pos-pi-prysm-setup.git /tmp/prysm_configs
  else
    cd /tmp/prysm_configs
    git pull origin master
    cd $HOME
  fi

  # Repace dirs
  find /tmp/prysm_configs -type f -exec sed -i -e "s:_HOME_:$HOME:g" {} \;
  # Replace user
  find /tmp/prysm_configs -type f -exec sed -i -e "s:_USER_:$USER:g" {} \;

  # Replace public ip
  #public_ip=$(curl v4.ident.me)
  find $TEMP_DIR/configs -type f -exec sed -i -e "s:_PUBLIC_IP_:$(curl -s v4.ident.me):g" {} \;

  echo "Please choose a graffiti:"
  read graffiti

  # Replace graffiti
  find /tmp/prysm_configs -type f -exec sed -i -e "s:_GRAFFITI_:$graffiti:g" {} \;

  # Move prysm.sh
  #cp -a /tmp/prysm_configs/prysm/prysm.sh $HOME/prysm/prysm.sh
  curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output $HOME/prysm/prysm.sh
  sudo chmod +x $HOME/prysm/prysm.sh

  # Move systemd config files
  cp -a /tmp/prysm_configs/systemd_services/*.service /etc/systemd/system

  # Move service config files
  cp -a /tmp/prysm_configs/services_conf/*.conf /etc/ethereum

  # Move logrotate config file
  cp -a /tmp/prysm_configs/logrotate_conf/prysm-logs /etc/logrotate.d

  # Move prometheus config
  sudo useradd -m prometheus
  sudo chown -R prometheus:prometheus /home/prometheus/
  #cp -a $TEMP_DIR/configs/prometheus_conf/prometheus.yml

  downloads



}

function uninstall() {
  echo "Uninstall....."
}

function help() {
  echo "Help..."
}

case $1 in
install)
    install
    ;;

uninstall)
    uninstall
    ;;

help)
    help
    ;;

*)
    echo "Task '$1' is not found!"
    echo "Please use 'setup.sh help' for more info."
    exit 1
    ;;
esac