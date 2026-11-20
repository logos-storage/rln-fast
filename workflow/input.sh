#!/bin/bash

source ./paths.sh
source ./cli_args.sh

# --- setup build directory ---

mkdir -p build 
cd build

# --- export the witness computation graph ---

if command -v build-circuit
then
  build-circuit ${CIRCUIT_MAIN}.circom ${CIRCUIT_MAIN}.graph ${CIRCUIT_INCLUDES}
else
  echo " "
  echo "\`circom-witnesscalc\` (in particular \`build-circuit\') not found; skipping graph extraction"
fi

# --- generate input for the circuit ---

echo ""
echo "generating the input for the proof circuit..."
echo "cli default arguments: $CLI_ARGS"

${NIMCLI_DIR}/cli $CLI_ARGS --output=input.json --partial=partial.json

# --- finish  ---

cd $ORIG
