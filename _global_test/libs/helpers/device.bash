device_common() {
  output "creating device filesystem in: ${ROOR_DIR}"
  mkdir -p ${ROOT_DIR}/dev/input/by-path/

}

create_rg351p() {
  device_common
  touch "${ROOT_DIR}/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick"
  touch "${ROOT_DIR}/dev/input/event2"
}


create_rg351v() {
  device_common
  touch "${ROOT_DIR}/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick"
  touch "${ROOT_DIR}/dev/input/event3"
}

create_rg351mp() {
  device_common
  touch "${ROOT_DIR}/dev/input/by-path/platform-odroidgo3-joypad-event-joystick"
  touch "${ROOT_DIR}/dev/input/by-path/platform-rg351-keys-event"
}

create_oga() {
  device_common
  touch "${ROOT_DIR}/dev/input/by-path/platform-odroidgo2-joypad-event-joystick"
  mkdir -p "${ROOT_DIR}/etc/emulationstation"
  echo  "190000004b4800000010000001010000" > "${ROOT_DIR}/etc/emulationstation/es_input.cfg"
}

create_rk2020() {
  device_common
  touch "${ROOT_DIR}/dev/input/by-path/platform-odroidgo2-joypad-event-joystick"
}

create_ogs() {
  device_common
  touch "${ROOT_DIR}/dev/input/by-path/platform-odroidgo3-joypad-event-joystick"
}

create_chi() {
  device_common
  #TODO: something
}