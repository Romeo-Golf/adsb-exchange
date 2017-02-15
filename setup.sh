#!/bin/bash

#####################################################################################
#                        ADS-B EXCHANGE SETUP SCRIPT                                #
#####################################################################################
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                                   #
# Copyright (c) 2015-2017 Joseph A. Prochazka                                       #
#                                                                                   #
# Permission is hereby granted, free of charge, to any person obtaining a copy      #
# of this software and associated documentation files (the "Software"), to deal     #
# in the Software without restriction, including without limitation the rights      #
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell         #
# copies of the Software, and to permit persons to whom the Software is             #
# furnished to do so, subject to the following conditions:                          #
#                                                                                   #
# The above copyright notice and this permission notice shall be included in all    #
# copies or substantial portions of the Software.                                   #
#                                                                                   #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR        #
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,          #
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE       #
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER            #
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,     #
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE     #
# SOFTWARE.                                                                         #
#                                                                                   #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

### VARIABLES

RECEIVER_PROJECT_TITLE="ADS-B Exchange Setup Script"
LOG_DIRECTORY="$PWD/logs"
MLAT_CLIENT_VERSION="0.2.7"
MLAT_CLIENT_TAG="v0.2.7"

### BEGIN SETUP

## CHECK IF SCRIPT WAS RAN USING SUDO

if [ "$(id -u)" != "0" ]; then
    echo -e "\033[33m"
    echo "This script must be ran using sudo or as root."
    echo -e "\033[37m"
    exit 1
fi

## WHIPTAIL DIALOGS

# Interactive install.
whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$RECEIVER_PROJECT_TITLE" --yesno "Thanks for choosing to share your data with ADS-B Exchange!\n\nADSBexchange.com is a co-op of ADS-B/Mode S/MLAT feeders from around the world. This script will configure your current your ADS-B receiver to share your feeders data with ADS-B Exchange.\n\nWould you like to continue setup?" 13 78
CONTINUE_SETUP=$?
if [ $CONTINUE_SETUP = 1 ]; then
    exit 0
fi

## CHECK FOR PREREQUISITE PACKAGES

echo -e "\033[33m"
echo "Checking for packages needed to run this script..."
sudo apt-get update

if [ $(dpkg-query -W -f='${STATUS}' curl 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
    echo "Installing the curl package..."
    echo -e "\033[37m"
    sudo apt-get install -y curl
fi
echo -e "\033[37m"

## CONFIRM DERIVED VALUES

# For interactive install we test each required variable and prompt the user if not present.
ADSBEXCHANGE_USERNAME=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "ADS-B Exchange User Name" --nocancel --inputbox "\nPlease enter your ADS-B Exchange user name.\n\nIf you have more than one receiver, this username should be unique.\nExample: \"username-01\", \"username-02\", etc." 12 78 3>&1 1>&2 2>&3)
RECEIVER_LATITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Receiver Latitude" --nocancel --inputbox "\nPlease enter your receiver's latitude." 9 78 3>&1 1>&2 2>&3)
RECEIVER_LONGITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Receiver Longitude" --nocancel --inputbox "\nPlease enter your receiver's longitude." 9 78 3>&1 1>&2 2>&3)
RECEIVER_ALTITUDE=$(whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Receiver Altitude" --nocancel --inputbox "\nPlease enter your receiver's altitude in meters above sea level, the below value is obtained from Google but should be increased to reflect your antennas height above ground level." 11  78 "`curl -s https://maps.googleapis.com/maps/api/elevation/json?locations=$RECEIVER_LATITUDE,$RECEIVER_LONGITUDE | python -c "import json,sys;obj=json.load(sys.stdin);print obj['results'][0]['elevation'];"`" 3>&1 1>&2 2>&3)

whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "$RECEIVER_PROJECT_TITLE" --yesno "We are now ready to begin setting up your receiver to feed ADS-B Exchange.\n\nDo you wish to proceed?" 9 78
CONTINUE_SETUP=$?
if [ $CONTINUE_SETUP = 1 ]; then
    exit 0
fi

## START WHIPTAIL PROGRESS GAUGE

{

    # Make a log directory if it does not already exist.
    if [ ! -d "$LOG_DIRECTORY" ]; then
        mkdir $LOG_DIRECTORY
    fi
    LOG_FILE="$LOG_DIRECTORY/image_setup-$(date +%F_%R)"
    touch $LOG_FILE

    echo 4
    sleep 0.25

    echo "INSTALLING PREREQUISITE PACKAGES" >> $LOG_FILE
    echo "--------------------------------------" >> $LOG_FILE
    echo "" >> $LOG_FILE


    # Check that the prerequisite packages needed to build and install mlat-client are installed.
    if [ $(dpkg-query -W -f='${STATUS}' build-essential 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y build-essential >> $LOG_FILE  2>&1
    fi

    echo 10
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' debhelper 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y debhelper >> $LOG_FILE  2>&1
    fi

    echo 16
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' python3-dev 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y python3-dev >> $LOG_FILE  2>&1
    fi

    echo 22
    sleep 0.25

    if [ $(dpkg-query -W -f='${STATUS}' netcat 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt-get install -y netcat >> $LOG_FILE  2>&1
    fi

    echo 28
    sleep 0.25

    ## DOWNLOAD OR UPDATE THE MLAT-CLIENT SOURCE

    echo "" >> $LOG_FILE
    echo " BUILD AND INSTALL MLAT-CLIENT" >> $LOG_FILE
    echo "-----------------------------------" >> $LOG_FILE
    echo "" >> $LOG_FILE

    # Check if build directory exists and contains a git repository.
    if [[ -d mlat-client ]] && [[ -d mlat-client/.git ]] ; then
        # A directory with a git repository containing the source code already exists.
        cd mlat-client >> ${LOG_FILE} 2>&1
        git fetch --tags >> ${LOG_FILE} 2>&1
    else
        # A directory containing the source code does not exist locally.
        git clone https://github.com/mutability/mlat-client.git >> ${LOG_FILE} 2>&1
        cd mlat-client >> ${LOG_FILE} 2>&1
    fi

    # Check that a git tag has been specified and that it is valid.
    if [[ -z "${MLAT_CLIENT_TAG}" ]] || [[ `git ls-remote 2>/dev/null| grep -c "refs/tags/${MLAT_CLIENT_TAG}\$"` -eq 0 ]] ; then
        # No tag has been specified, or the this tag is not present in the remote repo.
        if [[ -n "${MLAT_CLIENT_VERSION}" ]] && [[ `git ls-remote 2>/dev/null| grep -c "refs/tags/v${MLAT_CLIENT_VERSION}\$"` -gt 0 ]] ; then
            # If there is a tag matching the configured version use that.
            MLAT_CLIENT_TAG="v${MLAT_CLIENT_VERSION}"
        else
            # Otherwise get the most recent tag in the hope that it is a stable release.
            MLAT_CLIENT_TAG=`git ls-remote | grep "refs/tags/v" | awk '{print $2}'| sort -V | awk -F "/" '{print $3}' | tail -1`
        fi
    fi

    # Attempt to check out the required code version based on the supplied tag.
    if [[ -n "${MLAT_CLIENT_TAG}" ]] && [[ `git ls-remote 2>/dev/null| grep -c "refs/tags/${MLAT_CLIENT_TAG}"` -gt 0 ]] ; then
        # If a valid git tag has been specified then check that out.
        git checkout tags/${MLAT_CLIENT_TAG} >> ${LOG_FILE} 2>&1
    else
        # Otherwise checkout the master branch.
        git checkout master  >> ${LOG_FILE} 2>&1
    fi

    echo 34
    sleep 0.25

    ## BUILD AND INSTALL THE MLAT-CLIENT PACKAGE

    # Build binary package.
    dpkg-buildpackage -b -uc >> $LOG_FILE 2>&1
    cd .. >> $LOG_FILE
    # Install binary package.
    sudo dpkg -i mlat-client_${MLAT_CLIENT_VERSION}*.deb >> $LOG_FILE

    echo 40
    sleep 0.25

    ## CREATE THE SCRIPT TO EXECUTE AND MAINTAIN NETCAT AND MLAT-CLIENT FEEDS ADS-B EXCHANGE

    echo "" >> $LOG_FILE
    echo " CREATE AND CONFIGURE MLAT-CLIENT STARTUP SCRIPTS" >> $LOG_FILE
    echo "------------------------------------------------------" >> $LOG_FILE
    echo "" >> $LOG_FILE

    # Create the mlat-client maintenance script.
    tee adsbexchange-mlat_maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
    /usr/bin/mlat-client --input-type dump1090 --input-connect localhost:30005 --lat $RECEIVER_LATITUDE --lon $RECEIVER_LONGITUDE --alt $RECEIVER_ALTITUDE --user $ADSBEXCHANGE_USERNAME --server feed.adsbexchange.com:31090 --no-udp --results beast,connect,localhost:30104
  done
EOF

    echo 46
    sleep 0.25

    # Set execute permissions on the mlat-client maintenance script.
    chmod +x adsbexchange-mlat_maint.sh >> $LOG_FILE

    echo 52
    sleep 0.25

    # Add a line to execute the mlat-client maintenance script to /etc/rc.local so it is started after each reboot if one does not already exist.
    if ! grep -Fxq "$PWD/adsbexchange-mlat_maint.sh &" /etc/rc.local; then
        LINENUMBER=($(sed -n '/exit 0/=' /etc/rc.local))
        ((LINENUMBER>0)) && sudo sed -i "${LINENUMBER[$((${#LINENUMBER[@]}-1))]}i $PWD/adsbexchange-mlat_maint.sh &\n" /etc/rc.local >> $LOG_FILE
    fi

    echo 58
    sleep 0.25

    echo "" >> $LOG_FILE
    echo " CREATE AND CONFIGURE NETCAT STARTUP SCRIPTS" >> $LOG_FILE
    echo "-------------------------------------------------" >> $LOG_FILE
    echo "" >> $LOG_FILE

    # Kill any currently running instances of the adsbexchange-mlat_maint.sh script.
    PIDS=`ps -efww | grep -w "adsbexchange-mlat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        sudo kill $PIDS >> $LOG_FILE
        sudo kill -9 $PIDS >> $LOG_FILE
    fi

    echo 64
    sleep 0.25

    # Execute the mlat-client maintenance script.
    sudo nohup $PWD/adsbexchange-mlat_maint.sh > /dev/null 2>&1 & >> $LOG_FILE

    echo 70
    sleep 0.25

    # SETUP NETCAT TO SEND DUMP1090 DATA TO ADS-B EXCHANGE

    # Create the netcat maintenance script.
    tee adsbexchange-netcat_maint.sh > /dev/null <<EOF
#!/bin/sh
while true
  do
    sleep 30
    /bin/nc 127.0.0.1 30005 | /bin/nc feed.adsbexchange.com 30005
  done
EOF

    echo 76
    sleep 0.25

    # Set permissions on the file adsbexchange-netcat_maint.sh.
    chmod +x adsbexchange-netcat_maint.sh >> $LOG_FILE

    echo 82
    sleep 0.25

    # Add a line to execute the netcat maintenance script to /etc/rc.local so it is started after each reboot if one does not already exist.
    if ! grep -Fxq "$PWD/adsbexchange-netcat_maint.sh &" /etc/rc.local; then
        lnum=($(sed -n '/exit 0/=' /etc/rc.local))
        ((lnum>0)) && sudo sed -i "${lnum[$((${#lnum[@]}-1))]}i $PWD/adsbexchange-netcat_maint.sh &\n" /etc/rc.local >> $LOG_FILE
    fi

    echo 88
    sleep 0.25

    # Kill any currently running instances of the adsbexchange-netcat_maint.sh script.
    PIDS=`ps -efww | grep -w "adsbexchange-netcat_maint.sh" | awk -vpid=$$ '$2 != pid { print $2 }'`
    if [ ! -z "$PIDS" ]; then
        sudo kill $PIDS >> $LOG_FILE
        sudo kill -9 $PIDS >> $LOG_FILE
    fi

    echo 94
    sleep 0.25

    # Start netcat script.
    sudo nohup $PWD/adsbexchange-netcat_maint.sh > /dev/null 2>&1 & >> $LOG_FILE
    echo 100
    sleep 0.25

} | whiptail --backtitle "$RECEIVER_PROJECT_TITLE" --title "Setting Up ADS-B Exchange Feed"  --gauge "\nSetting up your receiver to feed ADS-B Exchange.\nThe setup process may take awhile to complete..." 8 60 0

### SETUP COMPLETE

# Display the thank you message box.
whiptail --title "ADS-B Exchange Setup Script" --msgbox "\nSetup is now complete.\n\nYour feeder should now be feeding data to ADS-B Exchange.\nThanks again for choosing to share your data with ADS-B Exchange!\n\nIf you have questions or encountered any issues while using this script feel free to post them to one of the following places.\n\nhttps://github.com/jprochazka/adsb-exchange\nhttp://www.adsbexchange.com/forums/topic/ads-b-exchange-setup-script/" 17 73

exit 0
