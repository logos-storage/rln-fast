#!/bin/bash

source ./paths.sh
source ./cli_args.sh

# --- setup build directory ---

mkdir -p build
cd build

# --- circuit specific setup ---

snarkjs="snarkjs-malleable"

CIRCUIT_MAIN="permuted"

start=`date +%s`

NODE_OPTIONS="--max-old-space-size=8192" $snarkjs groth16 setup ${CIRCUIT_MAIN}.r1cs $PTAU_PATH ${CIRCUIT_MAIN}_0000.zkey
echo "some_entropy_75289v3a7rcawcsyiur" | \
NODE_OPTIONS="--max-old-space-size=8192" $snarkjs zkey contribute ${CIRCUIT_MAIN}_0000.zkey ${CIRCUIT_MAIN}_0001.zkey --name="1st Contributor Name"

rm ${CIRCUIT_MAIN}_0000.zkey
mv ${CIRCUIT_MAIN}_0001.zkey ${CIRCUIT_MAIN}.zkey
$snarkjs zkey export verificationkey ${CIRCUIT_MAIN}.zkey ${CIRCUIT_MAIN}_verification_key.json

end=`date +%s`
echo "The circuit specific setup took `expr $end - $start` seconds."

# --- finish the setup ---

cd $ORIG
