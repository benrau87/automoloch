#!/bin/bash
####################################################################################################################
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
gitdir=$PWD

##Logging setup
logfile=/var/log/moloch_install.log
mkfifo ${logfile}.pipe
tee < ${logfile}.pipe $logfile &
exec &> ${logfile}.pipe
rm ${logfile}.pipe

##Functions
function print_status ()
{
    echo -e "\x1B[01;34m[*]\x1B[0m $1"
}

function print_good ()
{
    echo -e "\x1B[01;32m[*]\x1B[0m $1"
}

function print_error ()
{
    echo -e "\x1B[01;31m[*]\x1B[0m $1"
}

function print_notification ()
{
	echo -e "\x1B[01;33m[*]\x1B[0m $1"
}

function error_check
{

if [ $? -eq 0 ]; then
	print_good "$1 successfully."
else
	print_error "$1 failed. Please check $logfile for more details."
exit 1
fi

}

function install_packages()
{

apt-get update &>> $logfile && apt-get -y dist-upgrade &>> $logfile && apt-get install -y --allow-unauthenticated ${@} &>> $logfile
error_check 'Package installation completed'

}

function dir_check()
{

if [ ! -d $1 ]; then
	print_notification "$1 does not exist. Creating.."
	mkdir -p $1
else
	print_notification "$1 already exists. (No problem, We'll use it anyhow)"
fi

}

########################################
##BEGIN MAIN SCRIPT##
#Pre checks: These are a couple of basic sanity checks the script does before proceeding.
apt-get -y install apt-transport-https

##Java
add-apt-repository ppa:webupd8team/java -y 

#Nodejs
#curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -

##Elasticsearch
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - 
echo "deb https://artifacts.elastic.co/packages/5.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-5.x.list

apt-get update

cd ~

ES=5.4
NODEJS=6.10.3
INSTALL_DIR=$PWD

echo -n "Looking for java "
which java
JAVA_VAL=$?

if [ $JAVA_VAL -ne 0 ]; then
echo -n "java command not found, real Java 8 is recommended for this install, would you like to install it now? [yes] "
read INSTALLJAVA
if [ -n "$INSTALLJAVA" -a "x$INSTALLJAVA" != "xyes" ]; then
echo "Install java and try again"
exit
fi

if [ -f "/etc/debian_version" ]; then
echo debconf shared/accepted-oracle-license-v1-1 select true | \
  sudo debconf-set-selections
apt-get install oracle-java7-installer -y
if [ $? -ne 0 ]; then
echo "ERROR - 'apt-get install java7' failed"
exit
fi

if [ "x$http_proxy" != "x" ]; then
JAVA_OPTS="$JAVA_OPTS `echo $http_proxy | sed 's/https*:..\(.*\):\(.*\)/-Dhttp.proxyHost=\1 -Dhttp.proxyPort=\2/'`"
export JAVA_OPTS
echo "Because http_proxy is set ($http_proxy) setting JAVA_OPTS to ($JAVA_OPTS)"
sleep 1
fi

if [ "x$https_proxy" != "x" ]; then
JAVA_OPTS="$JAVA_OPTS `echo $https_proxy | sed 's/https*:..\(.*\):\(.*\)/-Dhttps.proxyHost=\1 -Dhttps.proxyPort=\2/'`"
export JAVA_OPTS
echo "Because https_proxy is set ($https_proxy) setting JAVA_OPTS to ($JAVA_OPTS)"
sleep 1
fi

##Pfring
echo -n "Use pfring? ('yes' enables) [no] "
read USEPFRING
PFRING=""
if [ -n "$USEPFRING" -a "x$USEPFRING" = "xyes" ]; then
echo "MOLOCH - Using pfring - Make sure to install the kernel modules"
sleep 1
PFRING="--pfring"
fi

## ElasticSearch
echo "MOLOCH: Downloading and installing elastic search"
if [ ! -f "elasticsearch-${ES}.tar.gz" ]; then
apt-get install -y elasticsearch
systemctl daemon-reload 
systemctl enable elasticsearch.service
systemctl start elasticsearch.service 
fi

# NodeJS
echo "MOLOCH: Downloading and installing node"
cd ${INSTALL_DIR}/thirdparty
if [ ! -f "node-v${NODEJS}.tar.gz" ]; then
wget http://nodejs.org/dist/v${NODEJS}/node-v${NODEJS}.tar.gz
fi

tar xfz node-v${NODEJS}.tar.gz
cd node-v${NODEJS}
./configure
make
make install
./configure --prefix=${TDIR}
make install

if [ "x$http_proxy" != "x" ]; then
${TDIR}/bin/npm config set proxy $http_proxy
echo "Because http_proxy is set ($http_proxy) setting npm proxy"
sleep 1
fi

if [ "x$https_proxy" != "x" ]; then
${TDIR}/bin/npm config set https-proxy $https_proxy
echo "Because https_proxy is set ($https_proxy) setting npm https-proxy"
sleep 1
fi


#git clone https://github.com/aol/moloch.git

#git clone https://github.com/benrau87/MolochSetup.git

#cp MolochSetup/Moloch\ Script.sh ~/moloch/

#cd moloch

#bash Moloch\ Script.sh


