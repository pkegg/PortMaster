#!/bin/bash
set -e

# Current directory of the script
DIR="$(realpath $( dirname "${BASH_SOURCE[0]}" ))"
source "${DIR}/global-functions"


whichos=$(get_os)
if [[ $whichos == "TheRA" ]]; then
  raloc="/opt/retroarch/bin"
elif [[ "$whichos" == "351ELEC" ]]; then
  raloc="/usr/bin"
else
  raloc="/usr/local/bin"
fi

if [ -f "/opt/system/Advanced/Switch to main SD for Roms.sh" ]; then
  GAMEDIR="/roms2/ports/2048"
else
  GAMEDIR="/roms/ports/2048"
fi

$raloc/retroarch -L $GAMEDIR/2048_libretro.so
