#!/bin/bash

echo "************************* Author: MAX VUONG ***********************"
echo "****** File setupMyEth2Node.sh - A script to quickly setup ETH2.0"

# Predefine downloads endpoints
configURL="https://cdn.discordapp.com/attachments/726496972277809284/743626826252943400/configs.20200813.zip"
grafanaURL="https://dl.grafana.com/oss/release/grafana_7.0.3_arm64.deb"
cryptowatchURL="https://github.com/nbarrientos/cryptowat_exporter/archive/e4bcf6e16dd2e04c4edc699e795d9450dee486ab.zip"
gethURL="https://gethstore.blob.core.windows.net/builds/geth-linux-arm64-1.9.19-3e064192.tar.gz"
pythonURL="https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tgz"

##### Functions
function install_package() {
  local package_name=$1

  if [$(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed") -eq 0]
  then
    echo "Installing... $1"
    sudo apt install -y $1
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

# Install independent packages

sudo apt-get update && sudo apt-get upgrade

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

#--------------------------------------------------------------------------------#

TITLE="System Information for $HOSTNAME"
RIGHT_NOW=$(date +"%x %r %Z")
TIME_STAMP="Updated on $RIGHT_NOW by $USER"


# Define temp location
START_DIR="/tmp/test"

while getopts m:h option
do
  case ${option} in
    m) MODE=${OPTARG};;
    h) HELP=${OPTARG};;
  esac
done

echo $MODE

if [ "$MODE" == "live" ]
then
  read -n1 -p "Are you sure to perform LIVE setup? [y,N]" doit
  case $doit in
    y|Y) START_DIR="";;
    n|N) echo "Setup with test mode...";;
  esac
fi

# Define setup directorie
echo "Now populate directories:\n"
TEMP_DIR=$START_DIR/tmp

MAIN_DIR=$START_DIR$HOME

SYSTEMD_DIR=$START_DIR/etc/systemd/system
SERVICE_CONF_DIR=$START_DIR/etc/ethereum

LOGROTATE_DIR=$START_DIR/etc/logrotate.d
USR_LOCAL_BIN=$START_DIR/usr/local/bin

GRAFANA_DIR=$START_DIR/var/lib/grafana
PROMETHEUS_DIR=$START_DIR/home/prometheus/node-exporter

create_dir $TEMP_DIR
create_dir $MAIN_DIR

create_dir $SYSTEMD_DIR
create_dir $SERVICE_CONF_DIR

create_dir $LOGROTATE_DIR
create_dir $USR_LOCAL_BIN

create_dir $GRAFANA_DIR
create_dir $PROMETHEUS_DIR

mkdir -p $MAIN_DIR/{.eth2,.eth2stats,.eth2validators,.ethereum,.password,logs,prysm,prysm/configs}

# Create files
touch $MAIN_DIR/.password/password.txt
touch $MAIN_DIR/logs/{beacon,validator,slasher}.log


# Get preset config
#echo "https://cdn.discordapp.com/attachments/726496972277809284/743626826252943400/configs.20200813.zip"
#echo "Please enter the PRESET config download URL:"
#read configURL

echo "Download PRESET config from: $configURL"
wget -O $TEMP_DIR/configs.zip $configURL
unzip $TEMP_DIR/configs.zip -d $TEMP_DIR
rm $TEMP_DIR/configs.zip

# Repace dirs
find $TEMP_DIR/configs -type f -exec sed -i -e "s:_HOME_:$MAIN_DIR:g" {} \;
# Replace user
find $TEMP_DIR/configs -type f -exec sed -i -e "s:_USER_:$USER:g" {} \;

echo "Please choose a graffiti:"
read graffiti

# Replace graffiti
find $TEMP_DIR/configs -type f -exec sed -i -e "s:_GRAFFITI_:$graffiti:g" {} \;

# Replace public ip
public_ip=$(curl v4.ident.me)
find $TEMP_DIR/configs -type f -exec sed -i -e "s:_PUBLIC_IP_:$public_ip:g" {} \;


# Move prysm.sh
cp -a $TEMP_DIR/configs/prysm/prysm.sh $MAIN_DIR/prysm/prysm.sh
sudo chmod +x $MAIN_DIR/prysm/prysm.sh

# Move systemd config files
cp -a $TEMP_DIR/configs/systemd_services/*.service $SYSTEMD_DIR

# Move service config files
cp -a $TEMP_DIR/configs/services_conf/*.conf $SERVICE_CONF_DIR

# Move logrotate config file
cp -a $TEMP_DIR/configs/logrotate_conf/prysm-logs $LOGROTATE_DIR

# Move prometheus config
sudo useradd -m prometheus
sudo chown -R prometheus:prometheus /home/prometheus/
#cp -a $TEMP_DIR/configs/prometheus_conf/prometheus.yml


# Download Pryms programs
$MAIN_DIR/prysm/prysm.sh beacon-chain --download-only
$MAIN_DIR/prysm/prysm.sh validator --download-only
$MAIN_DIR/prysm/prysm.sh slasher --download-only

# Download Grafana
if [! -e  $TEMP_DIR/grafana.deb]
then
  wget -O $TEMP_DIR/grafana.deb $grafanaURL
fi

# Download Python
if [! -e $TEMP_DIR/python.tgz]
then
  wget -O $TEMP_DIR/python.tgz $pythonURL
  mkdir -p $TEMP_DIR/Python
  tar -C $TEMP_DIR/Python --strip-components 1 -xvf $TEMP_DIR/python.tgz
fi

# Download Eth2.0 Deposit CLI
if [! -d $MAIN_DIR/eth2.0-deposit-cli]
then
  git clone https://github.com/ethereum/eth2.0-deposit-cli.git  $MAIN_DIR/eth2.0-deposit-cli
fi

# Download GETH
if [! -e $TEMP_DIR/geth.tar.gz]
then
  wget -O $TEMP_DIR/geth.tar.gz $gethURL
  mkdir -p $TEMP_DIR/Geth
  tar -C $TEMP_DIR/Geth --strip-components 1 -xvf $TEMP_DIR/geth.tar.gz
  sudo cp -a $TEMP_DIR/Geth/geth $USR_LOCAL_BIN
fi

# Download cryptowatch
if [! -e $TEMP_DIR/cryptowatch.zip]
then
  wget -O $TEMP_DIR/cryptowatch.zip $cryptowatchURL
  unzip -j $TEMP_DIR/cryptowatch.zip -d $MAIN_DIR/cryptowatch
fi
