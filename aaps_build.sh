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

#Declare array of shortened repo/fork names (replaced from github URL (after github.com/) and used in version name)
declare -A SHORT_VER_NAMES
SHORT_VER_NAMES[nightscout]="Main"
SHORT_VER_NAMES[tim2000s]="Tim"
SHORT_VER_NAMES[AndroidAPS]="AAPS"
SHORT_VER_NAMES[AndroidAPS-2]="AAPS"
SHORT_VER_NAMES[T-o-b-i-a-s]="Tobias"


#The rest should hopefully not need to change (that often)
###############################################################################

#Exit on errors
set -e

usage() { 
    echo "Usage: $0 [-g <github repo>] [-b <branch>] [-k <keystore>] [-o <apk output dir>] [-i <apk build tools install dir>] [-s <keystore password file>] [-p] | [-h]

  -a <key alias>
     The alias to the key to use in the keystore (provided with the -k option)

  -b <git branch>
     Git branch to build. If not defined builds the master branch
     A few examples of some AAPS branches
     * dev
     * dynisf
     * dynisf_pred_curves
     * 3.1.0.3-ai2.2.8.1

  -g <git url>
     URL of the AAPS git repo. Currently only supports github type URLs
     eg: https://github.com/T-o-b-i-a-s/AndroidAPS

  -h
     Display this help

  -i <install dir>
     Directory to install required build and packaging tools

  -k <keystore file>
     Path to your keystore file

  -o <apk output dir>
     Directory to store the built and signed apk in

  -p
     This will run the aaps_publish script that should exist in the same directory as this script.
     It will use fdroidserver to create/update your local (private) fdroid repo with the newly built apk if the build was successful.

  -s <keystore password/secrets file>
     Put your keystore password on the first line followed by your key password
     Nothing else should be in this file:
     https://developer.android.com/studio/command-line/apksigner

"
}

#Set some sane defaults (can be overridden with command line options)
SCRIPT_DIR=$(dirname -- $(readlink -fn -- "$0"))
SCRIPT_PARENT_DIR=`dirname -- "$( readlink -f -- "$(dirname -- "$( readlink -f -- "$0"; )";)"; )";`
GIT_PATH="https://github.com/nightscout/AndroidAPS.git"
BRANCH="master"
INSTALL_PATH="$SCRIPT_PARENT_DIR/AAPS-Build-Tools"
AAPS_APK_DIR="$SCRIPT_PARENT_DIR/AAPS_APKs"
KEYSTORE="$SCRIPT_PARENT_DIR/aapskeystore.jks"
KEY_PASSWD_FILE="$SCRIPT_PARENT_DIR/aaps_key"
KEY_ALIAS="key0"
RUN_PUBLISH_SCRIPT=0

#Read in options. All are optional and defaults set above.
########################################
while getopts ":g:b:i:o:k:s:a:ph" opt; do
    case $opt in
      g)
        GIT_PATH=$OPTARG
        ;;
      b)
        BRANCH=$OPTARG
        ;;
      i)
        INSTALL_PATH=$OPTARG
        ;;
      o)
        AAPS_APK_DIR=$OPTARG
        ;;
      k)
        KEYSTORE=$OPTARG
        ;;
      s)
        KEY_PASSWD_FILE=$OPTARG
        ;;
      a)
        KEY_ALIAS=$OPTARG
        ;;
      p)
        RUN_PUBLISH_SCRIPT=1
        ;;
      h)
        usage
        exit 0
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        echo
        usage
        exit 1
        ;;
       :)
        echo "Option -$OPTARG requires an argument." >&2
        echo
        usage
        exit 1
        ;;
    esac
done

#Other vars/options that should rarely need to change
########################################
CURRENT_DIR=`pwd`
WORKING_DIR="/tmp/AAPS_Build-$$"
GITHUB_OWNER=`echo $GIT_PATH | cut -d'/' -f4`
GITHUB_REPO=`echo $GIT_PATH | cut -d'/' -f5 | sed "s/\.git//"`
SOURCE_DIR="$WORKING_DIR/$GITHUB_REPO"
ANDROID_SDK_ROOT="$INSTALL_PATH/android_sdk"
BUILD_TOOLS_PATH="$ANDROID_SDK_ROOT/build-tools/$BUILD_TOOLS_VER"
ANDROID_CMDLINE_TOOLS_PATH="$ANDROID_SDK_ROOT/cmdline-tools/bin"
CURRENT_DATE=`date +%F`
BUILDS_TRACKING_FILE="$AAPS_APK_DIR/AAPS_builds.txt"
RELEASE_DIR="$SOURCE_DIR/app/build/outputs/apk/full/release"
BUILD_FLAVOUR="assembleFullRelease"
BUILT_APK="app-full-release-unsigned.apk"
ALIGNED_APK="app-full-release-aligned.apk"
COMMAND_LINE_TOOLS_DL="https://dl.google.com/android/repository/commandlinetools-linux-6858069_latest.zip"
COMMAND_LINE_TOOLS_SHA256SUM="87f6dcf41d4e642e37ba03cb2e387a542aa0bd73cb689a9e7152aad40a6e7a08"

SDKMANAGER="$ANDROID_CMDLINE_TOOLS_PATH/sdkmanager"
ZIPALIGN="$BUILD_TOOLS_PATH/zipalign"
APKSIGNER="$BUILD_TOOLS_PATH/apksigner"


#Display warning
########################################
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
REGEX="^[Ii] [Aa][Gg][Rr][Ee][Ee]$"
read -p "Type I AGREE if you agree: " confirm && [[ $confirm =~ $REGEX ]] || exit 1

echo "Started at:"
date


#Check/Setup build env
########################################
rm -rf $WORKING_DIR
mkdir -p $WORKING_DIR
cd $WORKING_DIR

export ANDROID_SDK_ROOT
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

$SDKMANAGER --sdk_root="$ANDROID_SDK_ROOT" --install "build-tools;$BUILD_TOOLS_VER" <<<"y" >/dev/null 2>&1
$SDKMANAGER --sdk_root="$ANDROID_SDK_ROOT" --install "platforms;android-$SDK_VER" >/dev/null 2>&1
$SDKMANAGER --sdk_root="$ANDROID_SDK_ROOT" --install "sources;android-$SDK_VER" >/dev/null 2>&1

[[ -f "$ZIPALIGN" && -x $(realpath "$ZIPALIGN") ]] || \
    ( echo "zipalign binary not found/executable at $ZIPALIGN" && exit 1 )
[[ -f "$APKSIGNER" && -x $(realpath "$APKSIGNER") ]] || \
    ( echo "apksigner binary not found/executable at $APKSIGNER" && exit 1 )


#Clone latest AAPS
########################################
echo "Cloning AAPS source code..."
git clone $GIT_PATH
cd $SOURCE_DIR
if [[ "$BRANCH" == "master" ]]; then
    echo "Building master"
else
    git checkout $BRANCH
fi

#Patch code
########################################
if [[ -f "$SCRIPT_DIR/patch_code.sh" ]]; then
    echo "Patching code..."
    $SCRIPT_DIR/patch_code.sh $SOURCE_DIR
fi

#Update source with more meaningful version name
########################################
VERNUM=`egrep -o "^ +version \"[0-9][0-9.]+[0-9]" ./app/build.gradle | cut -d'"' -f2`
echo $VERNUM
#Replace git names if in short ver names array
N1=$GITHUB_OWNER
N2=$GITHUB_REPO
[[ -v "SHORT_VER_NAMES[$N1]" ]] && N1=${SHORT_VER_NAMES[$N1]}
[[ -v "SHORT_VER_NAMES[$N2]" ]] && N2=${SHORT_VER_NAMES[$N2]}
NEW_VER_NAME="$N2.$N1-$VERNUM-$BRANCH"
if [[ $BRANCH =~ $VERNUM ]]; then
    NEW_VER_NAME="$N2.$N1-$BRANCH"
fi
SIGNED_APK="aaps-$NEW_VER_NAME-$CURRENT_DATE.apk"

echo "Changing version name to: $NEW_VER_NAME"
sed -i -e "s/\(^ \+version\) \"[0-9][0-9.]\+[0-9].*\"/\1 \"$NEW_VER_NAME\"/" ./app/build.gradle


#Track already built packages
########################################
[[ -r $BUILDS_TRACKING_FILE ]] || touch $BUILDS_TRACKING_FILE
if egrep "^$NEW_VER_NAME$" $BUILDS_TRACKING_FILE; then
    echo "Build already exists. Not building again. Update $BUILDS_TRACKING_FILE if you want to change this"
else
    echo "Attempting to build $NEW_VER_NAME"
fi


#Build and sign APK
########################################
echo "Compiling AAPS..."
./gradlew $BUILD_FLAVOUR
echo

#Zipalign
echo "Zipaligning APK..."
$ZIPALIGN -p 4 $RELEASE_DIR/$BUILT_APK $RELEASE_DIR/$ALIGNED_APK

#Sign
echo "Signing APK..."
$APKSIGNER sign --ks $KEYSTORE --ks-key-alias $KEY_ALIAS --ks-pass file:$KEY_PASSWD_FILE \
    --out $AAPS_APK_DIR/$SIGNED_APK $RELEASE_DIR/$ALIGNED_APK


#Cleanup
########################################
echo "Cleaning up..."
cd $CURRENT_DIR
rm -rf $WORKING_DIR

echo
echo "Finished..."
date
echo "You have successfully built AAPS"
echo "$NEW_VER_NAME" >> $BUILDS_TRACKING_FILE


#Call publish script if requested to do so
########################################
if [[ $RUN_PUBLISH_SCRIPT == 1 ]]; then
    echo "Calling publish script..."
    $SCRIPT_DIR/aaps_publishrepo.sh
fi
