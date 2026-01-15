#!/bin/bash

MY_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source ${MY_DIR}/params.sh

CLI_ARGS="--verbose \
 --merkle_depth=${MERKLE_DEPTH} \
 --limit_bits=${LIMIT_BITS}"

if [[ "$1" == "--export" ]]
then
  echo "exporting CLI_ARGS"
  echo $CLI_ARGS
  export CLI_ARGS
fi
