#!/bin/bash

ORIG=`pwd`

NIMCLI_DIR="${ORIG}/../test-input/"
PTAU_DIR="${ORIG}/../ceremony/"

CIRCUIT_ROOT="${ORIG}/../circuit/"
CIRCUIT_POS_DIR="${CIRCUIT_ROOT}/poseidon2/"
CIRCUIT_INCLUDES="-l${CIRCUIT_ROOT} -l${CIRCUIT_POS_DIR}"

PTAU_FILE="powersOfTau28_hez_final_13.ptau"
PTAU_PATH="${PTAU_DIR}/${PTAU_FILE}"

CIRCUIT_MAIN="rln_main"
