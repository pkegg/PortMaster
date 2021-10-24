#! /bin/bash
set -e
DIR="$(realpath $(dirname "${BASH_SOURCE[0]}"))"
PACKAGE="$1"
if [[ -z "$PACKAGE" ]]; then
  # This should be replaced on install
  PACKAGE=__PACKAGE__
fi
pushd "${DIR}/${PACKAGE}" &> /dev/null
bash ./run.sh