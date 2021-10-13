#!/bin/bash
set -e

# Current directory of the script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${DIR}/global-functions"

DEVICE="$(get_device)"
ROMS_DIR=$(get_roms_dir)
CONSOLE="$(get_console)"

if [[ ! -f "${DIR}/conf/cdogs-sdl/options.cnf" ]]; then
  config_type=480 #oga, rk2020
  if [[ "${DEVICE}" == "ogs" ]]; then
    config_type=ogs
  elif [[ "${DEVICE}" == "chi" || "${DEVICE}" == "anbernic-rg351v" || "${DEVICE}" == "anbernic-rg351mp"  ]]; then
    config_type=640
  fi
  mv -f "${DIR}/conf/cdogs-sdl/options.cnf.${config_type}" "${DIR}/conf/cdogs-sdl/options.cnf"
  rm -f /roms/ports/cdogs/conf/cdogs-sdl/options.cnf.*
fi

sudo chmod 666 "${CONSOLE}"

sudo rm -rf ~/.config/cdogs-sdl
ln -sfv "${ROMS_DIR}/ports/cdogs/conf/cdogs-sdl/" ~/.config/
cd "${ROMS_DIR}/ports/cdogs/data"
sudo ./oga_controls cdogs-sdl "${DEVICE}" &
./cdogs-sdl
sudo kill -9 "$(pidof oga_controls)"
sudo systemctl restart oga_events &
printf "\033c" > "${CONSOLE}"