#!/bin/bash
set -e

# Current directory of the script
DIR="$(realpath $( dirname "${BASH_SOURCE[0]}" ))"
source "${DIR}/global-functions"
OGA_DEVICE="$(get_oga_device)"

DEVICE="$(get_device)"
CONSOLE="$(get_console)"

if [[ ! -f "${DIR}/conf/cdogs-sdl/options.cnf" ]]; then
  config_type=480 #oga, rk2020
  if [[ "${DEVICE}" == "ogs" ]]; then
    config_type=ogs
  elif [[ "${DEVICE}" == "chi" || "${DEVICE}" == "rg351v" || "${DEVICE}" == "rg351mp"  ]]; then
    config_type=640
  fi
  mv -f "${DIR}/conf/cdogs-sdl/options.cnf.${config_type}" "${DIR}/conf/cdogs-sdl/options.cnf"
  rm -f ${DIR}/conf/cdogs-sdl/options.cnf.*
fi

sudo chmod 666 "${CONSOLE}"

sudo rm -rf ~/.config/cdogs-sdl
ln -sfv "${DIR}/conf/cdogs-sdl/" ~/.config/
cd "${DIR}/cdogs/data"
sudo ./oga_controls cdogs-sdl "${DEVICE}" &
./cdogs-sdl
sudo kill -9 "$(pidof oga_controls)"
sudo systemctl restart oga_events &
printf "\033c" > "${CONSOLE}"