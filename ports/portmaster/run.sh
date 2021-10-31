#!/bin/bash
#
# PortMaster
# https://github.com/christianhaitian/arkOS/wiki/PortMaster
# Description : A simple tool that allows you to download
# various game ports that are available for RK3326 DEVICEs
# using 351Elec and Ubuntu based distrOS such as ArkOS, TheRA, and RetroOZ.
#
set -e
DIR="$(realpath $( dirname "${BASH_SOURCE[0]}" ))"
TITLE="PortMaster"

# shellcheck source=/dev/null
source "${DIR}/global-functions"

OS=$(get_os)
DEVICE=$(get_device)
ROMS_DIR=$(get_roms_dir)
TOOLS_DIR=$(get_tools_dir)
HOTKEY=$(get_hotkey)
CONSOLE=$(get_console)
GITHUB_ORG=pkegg  #just for testing - should be: christianhaitian or derived
RELEASE_VERSION=2020-10-29
WEBSITE="https://github.com/${GITHUB_ORG}/PortMaster/releases/download/${RELEASE_VERSION}"
WEBSITE_IN_CHINA=

echo "OS: ${OS} DEVICE: ${DEVICE} ROMS_DIR: ${ROMS_DIR} TOOLS_DIR: ${TOOLS_DIR} CONSOLE: ${CONSOLE} HOTKEY: ${HOTKEY}" 

ESUDO="sudo"
if [ "${OS}" == "351ELEC" ]; then
  ESUDO=""
  export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/storage/roms/ports/PortMaster/libs"
elif ! which sudo &> /dev/null; then
  ESUDO=""
elif [ "${OS}" == "unknown" ]; then
  $ESUDO mkdir -p "${ROMS_DIR}" "${TOOLS_DIR}"
fi

$ESUDO chmod 666 ${CONSOLE}
export TERM=linux
export XDG_RUNTIME_DIR=/run/user/$UID/

#TODO: Does `clear` work on all systems?  If yes - use that for clarity
if [[ "${IS_TEST_MODE}" != "true" ]]; then
  printf "\033c" >> ${CONSOLE}
fi

HEIGHT="15"
WIDTH="55"

if [[ "${DEVICE}" == "rg351p" || "${DEVICE}" == "rg351v" ]]; then
  if [[ "${OS}" == "ArkOS" ]]; then
    $ESUDO setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
    HEIGHT="20"
    WIDTH="60"
  fi
elif [[ "${DEVICE}" == "ogs" ]]; then
  $ESUDO setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
  HEIGHT="20"
  WIDTH="60"
elif [[ "${DEVICE}" == "chi" ]]; then
  $ESUDO setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
  HEIGHT="20"
  WIDTH="60"
fi
mkdir -p "${TOOLS_DIR}"
cd "$TOOLS_DIR"
$ESUDO "$DIR/oga_controls" PortMaster.sh "$DEVICE" &> /dev/null &

if ! which curl &> /dev/null; then
  echo "curl not found"
  dpkg -s "curl" &>/dev/null
  if [ "$?" != "0" ]; then
    $ESUDO apt update && $ESUDO apt install -y curl --no-install-recommends
  fi
fi

if ! which dialog &> /dev/null; then
  echo "dialog not found"
  dpkg -s "dialog" &>/dev/null
  if [ "$?" != "0" ]; then
    $ESUDO apt update && $ESUDO apt install -y dialog --no-install-recommends
    temp=$(grep "title=" /usr/share/plymouth/themes/text.plymouth)
    if [[ $temp == *"ArkOS 351P/M"* ]]; then
  	#Make sure sdl2 wasn't impacted by the install of dialog for the 351P/M
      $ESUDO ln -sfv /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.14.1 /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0
  	  $ESUDO ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.10.0 /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0
    fi
  fi
fi
curversion="$(curl "file://$(realpath "${DIR}")/version")"

GW=$(ip route | awk '/default/ { print $3 }')
if [ -z "$GW" ]; then
  dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "${TITLE}" \
  --msgbox "\n\nYour network connection doesn't seem to be working. \
  \nDid you make sure to configure your wifi connection?" $HEIGHT $WIDTH
  $ESUDO kill -9 "$(pidof oga_controls)"
  $ESUDO systemctl restart oga_events &
  exit 0
fi

if [[ "ArkOS" == "${OS}" ]]; then
  $ESUDO timedatectl set-ntp 1
fi

website=${WEBSITE}
in_china=$(in_china)
if [[ "$in_china" == "true" ]]; then
  website="${WEBSITE_IN_CHINA}"
fi
echo "In china: ${in_china}"

if [ ! -d "/dev/shm/portmaster" ]; then
  mkdir /dev/shm/portmaster
fi



dialog --clear --stdout


function UpdateCheck() {

  version_url="${WEBSITE}version"
  gitversion=$(curl -s --connect-timeout 30 -m 60 "${version_url}")
  portmaster_download_zip=/dev/shm/portmaster/PortMaster.zip

  if [[ "$gitversion" != "$curversion" ]]; then
    wget -t 3 -T 60 -q --show-progress "${WEBSITE}PortMaster.zip" -O ${portmaster_download_zip} 2>&1 | stdbuf -oL sed -E 's/\.\.+/---/g'| dialog \
          --progressbox "Downloading and installing PortMaster update..." "$HEIGHT" "$WIDTH"
   	if [ "${PIPESTATUS[0]}" -eq 0 ]; then
         unzip -X -o ${portmaster_download_zip} -d "${TOOLS_DIR}/"
   	  if [[ "TheRA" == "${OS}" ]]; then
   		  $ESUDO chmod -R 777 "$TOOLS_DIR/PortMaster"
   	  fi
   	  dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$TITLE" --msgbox "\n\nPortMaster updated successfully." "$HEIGHT" "$WIDTH"
   	  
       oga_pid="$(pidof oga_controls)"
       if [[ -n "${oga_pid}" ]];then
         $ESUDO kill -9 "${oga_pid}"
       fi
   	  $ESUDO rm -f ${portmaster_download_zip} 
   	  $ESUDO systemctl restart oga_events &
   	  exit 0
   	else
   	  dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$TITLE" --msgbox "\n\nPortMaster failed to update." "$HEIGHT" "$WIDTH"
   	  $ESUDO rm -f ${portmaster_download_zip}
   	fi
  else
    dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$TITLE" --msgbox "\n\nNo update needed." "$HEIGHT" "$WIDTH"
  fi
}

PortInfoInstall() {
  local choice="$1"

  local portmaster_tmp=/dev/shm/portmaster
  local ports_file=/dev/shm/portmaster/ports.md
  
  msgtxt=$(cat "$ports_file" | grep "$choice" | grep -oP '(?<=Desc=").*?(?=")')
  installloc=$(cat "$ports_file" | grep "$choice" | grep -oP '(?<=locat=").*?(?=")')
  porter=$(cat "$ports_file" | grep "$choice" | grep -oP '(?<=porter=").*?(?=")')
  local port_url="${website}${installloc}"

  if dialog --clear --stdout --backtitle "PortMaster v$curversion" \
            --title "$choice" \
            --yesno "\n$msgtxt \n\nPorted By: $porter\n\nWould you like to continue to install this port?" \
            $HEIGHT $WIDTH &> ${CONSOLE}; then
  
    wget -t 3 -T 60 -q --show-progress ${port_url} -O \
	    $portmaster_tmp/$installloc 2>&1 | stdbuf -oL sed -E 's/\.\.+/---/g'| dialog --progressbox \
		"Downloading ${1} package..." $HEIGHT $WIDTH

		if [ ${PIPESTATUS[0]} -eq 0 ] ; then
          
      if unzip -o $portmaster_tmp/$installloc -d ${ROMS_DIR}/ports/; then
  		  if [[ "$OS" == "TheRA" ]]; then
  		    $ESUDO chmod -R 777 ${ROMS_DIR}/ports
  		  fi
  			if [[ "${OS}" == "351ELEC" ]]; then
  			  sed -i 's/sudo //g' ${ROMS_DIR}/ports/*.sh
  			fi
  		    dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$choice" --msgbox "\n\n$choice installed successfully. \
  		    \n\nMake sure to restart EmulationStation in order to see it in the ports menu." $HEIGHT $WIDTH
  		  else
  		    dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$choice"--msgbox "\n\n$choice did NOT install. \
  		    \n\nYour roms partition seems to be full." $HEIGHT $WIDTH
  		  fi
      else
        dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$choice" --msgbox "\n\n$choice failed to install successfully." $HEIGHT $WIDTH
      fi
  	else
  		  dialog --clear --stdout --backtitle "PortMaster v$curversion" --title "$choice" --msgbox "\n\n$choice failed to download successfully.  The PortMaster server maybe busy or check your internet connection." $HEIGHT $WIDTH
  	fi
    $ESUDO rm -f $portmaster_tmp/$installloc

}

userExit() {
  echo "removing ports.md"
  rm -f /dev/shm/portmaster/ports.md

  echo "checking oga_controls"
  if pidof oga_controls; then
    echo "killing oga_controls"
    $ESUDO kill -9 $(pidof oga_controls);
  fi
  echo "checking oga_events"
  if systemctl list-units --full -all | grep -Fq "oga_events"; then
    echo "restarting oga_events"
    $ESUDO systemctl restart oga_events &
  fi
  echo "clearing dialog"
  #dialog --clear
  echo "clearing console"
  printf "\033c" >> ${CONSOLE}
  echo "done"
  exit 0
}

MainMenu() {
  echo "in main menu"

  local options=(
   $(cat /dev/shm/portmaster/ports.md | grep -oP '(?<=Title=").*?(?=")')
  )

  echo "generating choices"
  while true; do
    selection=(dialog \
   	--backtitle "PortMaster v$curversion" \
   	--title "[ Main Menu ]" \
   	--no-collapse \
   	--clear --stdout \
	  --cancel-label "$HOTKEY + Start to Exit" \
    --menu "Available ports for install" $HEIGHT $WIDTH 15)

    echo "choice"
    choices=$("${selection[@]}" "${options[@]}" 2> /dev/null) || userExit
    echo "choice done"

    for choice in $choices; do
      case $choice in
        *) PortInfoInstall $choice ;;
      esac
    done
  done
}
echo "done choice"

wget -t 3 -T 60 --no-check-certificate "$website"ports.md -O /dev/shm/portmaster/ports.md
echo_err "done with ports.md"

if [[ "${IS_TEST_MODE}" == "true" ]]; then
  echo "${IS_TEST_MODE}"
  exit 0
fi

if dialog --clear --stdout --backtitle "PortMaster v$curversion" \
          --title "$1" --yesno "\nWould you like to check for an update to the PortMaster tool?" \
          $HEIGHT $WIDTH; then
   UpdateCheck
fi

MainMenu

