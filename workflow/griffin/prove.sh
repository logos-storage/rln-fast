#!/bin/bash

source ./paths.sh
source ./cli_args.sh

# --- setup build directory ---

mkdir -p build 
cd build

# --- generate the witness ---

start=`date +%s`
echo ""
echo "generating the witness..."
cd ${CIRCUIT_MAIN}_js
time node generate_witness.js ${CIRCUIT_MAIN}.wasm ../input.json ../witness.wtns
cd ${ORIG}/build
end=`date +%s`
echo "Generating the witness took `expr $end - $start` seconds."

# --- create the proof ---

PROVER="snarkjs"

RS=`which rapidsnark`
if [[ ! -z "$RS" ]]
then
  PROVER="rapidsnark"
fi

# PROVER="zikkurat"
PROVER="nim"

echo ""
echo "creating the proof... using prover: \`$PROVER\`"

start=`date +%s`
case $PROVER in
  snarkjs)
    time snarkjs groth16 prove ${CIRCUIT_MAIN}.zkey witness.wtns proof.json public.json
    ;;
  rapidsnark)
    time rapidsnark ${CIRCUIT_MAIN}.zkey witness.wtns proof.json public.json
    ;;
  nim)
    time nim-groth16 -tpv --nthreads=1 --zkey=${CIRCUIT_MAIN}.zkey --wtns=witness.wtns -o=proof.json -i=public.json
    ;;
  zikkurat)
    time zikkurat-groth16 -tpv --zkey=${CIRCUIT_MAIN}.zkey --wtns=witness.wtns # -o=proof.json -i=public.json
    ;;
  *)
    echo "unknown prover \`$PROVER\`"
    exit 99
    ;;
esac
end=`date +%s`
echo "Creating the proof took `expr $end - $start` seconds."

# --- create the partial proof ---

echo ""
echo "--------------------------------------------------------------------------"
echo ""

${NIMCLI_DIR}/prover_cli -i=input.json -p=partial.json -g=${CIRCUIT_MAIN}.graph -z=${CIRCUIT_MAIN}.zkey -r=${CIRCUIT_MAIN}.r1cs

# --- verify the proof ---

echo ""
echo "verifying the proof:"
snarkjs groth16 verify ${CIRCUIT_MAIN}_verification_key.json public.json proof.json

# --- create solidity verifier contract ---

echo ""
echo "creating solidity verifier contract:"
snarkjs zkey export solidityverifier ${CIRCUIT_MAIN}.zkey verifier.sol

# --- finish  ---

cd $ORIG
