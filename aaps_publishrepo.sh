#!/bin/bash
#Steps to publish AAPS on a private fdroid repo
#This has been tested on Rocky Linux (8.6) but might work on other distros
#
#Presteps:
# 1) Ensure a webserver is installed and able to serve out files (keep this server private though!)
#  --> On Rocky Linux (and other RHEL clones run this:
#      yum install -y httpd rsync
#      systemctl enable --now httpd
#      chown android-build. /var/www/html/
#      firewall-cmd --add-service=http
# 2) Run the aaps_build.sh script 
# 3) Update the varibles below to suit your environment

#Update these vars to suite your env:
AAPS_APK_DIR="/home/android-build/AAPS_APKs"
INSTALL_PATH="/home/android-build/AAPS-Build-Tools"
WEBSERVER_ROOT="/var/www/html/"
WORKING_DIR="/home/android-build/AAPS-Build-Tools/src_repo"
WEBSERVER_HOSTNAME="aapsrepo.skidogs.com.au"
REPO_NAME="AAPS Repo"
REPO_DESC="Private AAPS Repo :)"

#The rest should hopefully not need to change (that often)
###############################################################################

#Exit on errors
set -e

FDROID_SERVER_INSTALL_PATH="$INSTALL_PATH/fdroid-server"
ANDROID_HOME="$INSTALL_PATH/android_sdk"

CURRENT_DIR=`pwd`

FDROID_BIN="$FDROID_SERVER_INSTALL_PATH/fdroidserver-env/bin/fdroid"

export ANDROID_HOME

#Setup/Install fdroid server
mkdir -p $FDROID_SERVER_INSTALL_PATH
cd $FDROID_SERVER_INSTALL_PATH

python3 -m venv env
source env/bin/activate
pyvenv-3 fdroidserver-env
. fdroidserver-env/bin/activate

if [[ -f "$FDROID_BIN" && -x $(realpath "$FDROID_BIN") ]]; then
    echo "fdroid server already looks to be installed"
else
    pip install --upgrade pip
    pip install git+https://gitlab.com/fdroid/fdroidserver.git
fi

if [ ! -d "$WORKING_DIR/fdroid" ]; then
    mkdir -p $WORKING_DIR/fdroid
    cd $WORKING_DIR/fdroid
    fdroid init
    echo "repo_url: http://$WEBSERVER_HOSTNAME/fdroid/repo" >> config.yml
    echo "repo_name: $REPO_NAME" >> config.yml
    echo "repo_description: $REPO_DESC" >> config.yml
fi

cd $WORKING_DIR/fdroid
mkdir -p $WORKING_DIR/fdroid/repo
cp $AAPS_APK_DIR/*.apk ./repo/
#rm -f $AAPS_APK_DIR/*.apk

fdroid update --create-metadata

mkdir -p $WEBSERVER_ROOT/fdroid
fdroid deploy --local-copy-dir $WEBSERVER_ROOT/fdroid

cd $CURRENT_DIR
echo "If your webserver is correctly setup you should now be able to access any updated AAPS apks"

