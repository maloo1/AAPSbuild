#!/bin/bash
#Steps to build AAPS on Rocky Linux (8.6)
#This will probably work on other Linux distros, but will obviously need to change java packages/installer
#
#
#Presteps:
#1) Ensure the following RPMs are installed. If using a non redhat based distro change to suite:
#  a) yum install -y java-11-openjdk.x86_64
#  b) yum install -y java-11-openjdk-devel
#2) Download android command line tools from here: https://developer.android.com/studio#command-tools
#3) Unzip as per instructions https://developer.android.com/studio/command-line/sdkmanager

#Update these vars to suite your env:
SDK_VER="28"
BUILD_TOOLS_VER="28.0.3"
ANDROID_SDK_ROOT="/home/android-build/android_sdk"
BUILD_TOOLS_PATH="$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS_VER"
ANDROID_CMDLINE_TOOLS_PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
KEYSTORE="/home/android-build/aapskeystore.jks"
KEY_ALIAS="key0"
#Put your keystore password on the first line followed by your key password
#Nothing else should be in this file:
#https://developer.android.com/studio/command-line/apksigner
KEY_PASSWD_FILE="/home/android-build/aaps_key"
#`pwd` will output to current dir
OUTPUT_DIR=`pwd`



#The rest should hopefully not need to change (that often)
###############################################################################
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

export ANDROID_SDK_ROOT
SDKMANAGER="$ANDROID_CMDLINE_TOOLS_PATH/sdkmanager"
ZIPALIGN="$BUILD_TOOLS_PATH/zipalign"
APKSIGNER="$BUILD_TOOLS_PATH/apksigner"

CURRENT_DIR=`pwd`
WORKING_DIR="/tmp/AAPS_Build-$$"
SOURCE_DIR="$WORKING_DIR/AndroidAPS"
RELEASE_DIR="$SOURCE_DIR/app/build/outputs/apk/full/release"
BUILD_FLAVOUR="assembleFullRelease"
BUILT_APK="app-full-release-unsigned.apk"
ALIGNED_APK="app-full-release-aligned.apk"
SIGNED_APK="app-full-release.apk"
GIT_PATH="https://github.com/nightscout/AndroidAPS.git"

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

[[ -f "$SDKMANAGER" && -x $(realpath "$SDKMANAGER") ]] || \
    ( echo "sdkmanager binary not found/executable at $SDKMANAGER" && \
    echo "Download from https://developer.android.com/studio#command-tools" && \
    echo "and install as per https://developer.android.com/studio/command-line/sdkmanager" && \
    exit 1 )

cd $ANDROID_SDK_ROOT
$SDKMANAGER --install "build-tools;$BUILD_TOOLS_VER"
$SDKMANAGER --install "platforms;android-$SDK_VER"
$SDKMANAGER --install "sources;android-$SDK_VER"

[[ -f "$ZIPALIGN" && -x $(realpath "$ZIPALIGN") ]] || \
    ( echo "zipalign binary not found/executable at $ZIPALIGN" && exit 1 )
[[ -f "$APKSIGNER" && -x $(realpath "$APKSIGNER") ]] || \
    ( echo "apksigner binary not found/executable at $APKSIGNER" && exit 1 )


#Clone latest AAPS
echo "Cloning AAPS source code..."
mkdir -p $WORKING_DIR
cd $WORKING_DIR
git clone $GIT_PATH
#You could auto build a dev branch, but I can't recommend that due to safety
#best to be fully aware of the changes that were made there:)
cd $SOURCE_DIR

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
    --out $OUTPUT_DIR/$SIGNED_APK $RELEASE_DIR/$ALIGNED_APK

#Cleanup
echo "Cleaning up..."
cd $CURRENT_DIR
rm -rf $WORKING_DIR

echo
echo "Finished..."
date
echo "You have successfully built AAPS"
