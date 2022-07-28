#!/bin/bash
#Steps to build AAPS on Linux
#This has been tested on Rocky Linux (8.6) but should work on other Linux distros as long as Java 11 is installed (and default)
#
#
#Presteps:
# 1) Ensure Java 11 is installed
#  --> On Rocky Linux (and other RHEL clones run this:
#      yum install -y java-11-openjdk.x86_64 java-11-openjdk-devel
# 2) Compile AAPS manually and be sure to save your key
# 3) Update the varibles below to suit your environment

#Update these vars to suite your env:
SDK_VER="28"
BUILD_TOOLS_VER="28.0.3"
KEYSTORE="/home/android-build/aapskeystore.jks"
KEY_ALIAS="key0"
#Put your keystore password on the first line followed by your key password
#Nothing else should be in this file:
#https://developer.android.com/studio/command-line/apksigner
KEY_PASSWD_FILE="/home/android-build/aaps_key"
AAPS_APK_DIR="/home/android-build/AAPS_APKs"
INSTALL_PATH="/home/android-build/AAPS-Build-Tools"
#Branch to build
BRANCH="dev"

#The rest should hopefully not need to change (that often)
###############################################################################

#Exit on errors
set -e

echo "################################  NOTICE  ######################################"
echo
echo "You are about to compile AAPS yourself"
echo "Ensure you have read to docs: https://androidaps.readthedocs.io/en/latest/"
echo
echo "################################################################################"
echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  WARNING  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo
echo "Ensure you have fully read this script and understand it as you are responsible "
echo "for what it will do"
echo
echo "Before continuing enusre you have built AAPS manually as per the instructions"
echo "contained here (this script wont work without the keystore generated as part of"
echo "these manual steps!!):"
echo "https://androidaps.readthedocs.io/en/latest/Installing-AndroidAPS/Building-APK.html"
echo
echo "By continuing you agree to be fully responsible for what this script and AAPS "
echo "can and will do"
echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo
read -p "Type I AGREE if you agree: " confirm && [[ $confirm == "I AGREE" ]] || exit 1

echo "Started at:"
date

ANDROID_SDK_ROOT="$INSTALL_PATH/android_sdk"
BUILD_TOOLS_PATH="$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS_VER"
ANDROID_CMDLINE_TOOLS_PATH="$ANDROID_SDK_ROOT/cmdline-tools/bin"
CURRENT_DIR=`pwd`
CURRENT_DATE=`date +%F`
WORKING_DIR="/tmp/AAPS_Build-$$"
SOURCE_DIR="$WORKING_DIR/AndroidAPS"
RELEASE_DIR="$SOURCE_DIR/app/build/outputs/apk/full/release"
BUILD_FLAVOUR="assembleFullRelease"
BUILT_APK="app-full-release-unsigned.apk"
ALIGNED_APK="app-full-release-aligned.apk"
SIGNED_APK="aaps-full-release-$BRANCH-$CURRENT_DATE.apk"
GIT_PATH="https://github.com/nightscout/AndroidAPS.git"
COMMAND_LINE_TOOLS_DL="https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip"
COMMAND_LINE_TOOLS_SHA256SUM="87f6dcf41d4e642e37ba03cb2e387a542aa0bd73cb689a9e7152aad40a6e7a08"

SDKMANAGER="$ANDROID_CMDLINE_TOOLS_PATH/sdkmanager"
ZIPALIGN="$BUILD_TOOLS_PATH/zipalign"
APKSIGNER="$BUILD_TOOLS_PATH/apksigner"

export ANDROID_SDK_ROOT

rm -rf $WORKING_DIR
mkdir -p $WORKING_DIR
cd $WORKING_DIR

#Check build env
echo "Checking build environment..."
#Keystore files: Check permissions are secure and also checking if the file exists
chmod 600 $KEYSTORE
chmod 600 $KEY_PASSWD_FILE

#TODO: Handle multiple Java installs
which java >/dev/null
which jlink >/dev/null
JAVA_MAJOR_VER=`java -version 2>&1 | grep -i version | cut -d'"' -f2 | cut -d'.' -f1`
[[ "$JAVA_MAJOR_VER" == "11" ]] || ( echo "Java 11 not installed or default java" && exit 1 )

if [[ -f "$SDKMANAGER" && -x $(realpath "$SDKMANAGER") ]]; then
    echo "sdkmanager is installed..."
else
    wget -O commandlinetools.zip $COMMAND_LINE_TOOLS_DL -P $WORKING_DIR/
    echo "$COMMAND_LINE_TOOLS_SHA256SUM commandlinetools.zip" | sha256sum -c || ( echo "commandlinetools Checksum failed" && exit 1 )
    mkdir -p $ANDROID_SDK_ROOT
    unzip commandlinetools.zip -d $ANDROID_SDK_ROOT/
fi

#Check again
[[ -f "$SDKMANAGER" && -x $(realpath "$SDKMANAGER") ]] || \
    ( echo "sdkmanager binary not found/executable at $SDKMANAGER (install failed)" && \
    echo "Manually download from https://developer.android.com/studio#command-tools" && \
    echo "and install as per https://developer.android.com/studio/command-line/sdkmanager" && \
    exit 1 )

$SDKMANAGER --sdk_root="$ANDROID_SDK_ROOT" --install "build-tools;$BUILD_TOOLS_VER" <<<"y"
$SDKMANAGER --sdk_root="$ANDROID_SDK_ROOT" --install "platforms;android-$SDK_VER"
$SDKMANAGER --sdk_root="$ANDROID_SDK_ROOT" --install "sources;android-$SDK_VER"

[[ -f "$ZIPALIGN" && -x $(realpath "$ZIPALIGN") ]] || \
    ( echo "zipalign binary not found/executable at $ZIPALIGN" && exit 1 )
[[ -f "$APKSIGNER" && -x $(realpath "$APKSIGNER") ]] || \
    ( echo "apksigner binary not found/executable at $APKSIGNER" && exit 1 )

#Clone latest AAPS
echo "Cloning AAPS source code..."
git clone $GIT_PATH
cd $SOURCE_DIR
[[ "BRANCH" == "master" ]] || git checkout $BRANCH

#Build
echo "Compiling AAPS..."
./gradlew $BUILD_FLAVOUR
echo

#Zipalign
echo "Zipaligning APK..."
$ZIPALIGN -v -p 4 $RELEASE_DIR/$BUILT_APK $RELEASE_DIR/$ALIGNED_APK

#Sign
echo "Signing APK..."
$APKSIGNER sign --ks $KEYSTORE --ks-key-alias $KEY_ALIAS --ks-pass file:$KEY_PASSWD_FILE \
    --out $AAPS_APK_DIR/$SIGNED_APK $RELEASE_DIR/$ALIGNED_APK

#Cleanup
echo "Cleaning up..."
cd $CURRENT_DIR
rm -rf $WORKING_DIR

echo
echo "Finished..."
date
echo "You have successfully built AAPS"
