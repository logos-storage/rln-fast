#!/bin/bash

ORIG=`pwd`

NIMCLI_DIR="${ORIG}/../../test-input/"
PTAU_DIR="${ORIG}/../../ceremony/"

CIRCUIT_ROOT="${ORIG}/../../circuit/"
CIRCUIT_POSEI_DIR="${CIRCUIT_ROOT}/poseidon2/"
CIRCUIT_GRIFF_DIR="${CIRCUIT_ROOT}/griffin/"
CIRCUIT_INCLUDES="-l${CIRCUIT_ROOT} -l${CIRCUIT_POSEI_DIR} -l${CIRCUIT_GRIFF_DIR}"

# PTAU_FILE="powersOfTau28_hez_final_14.ptau"
PTAU_FILE="powersOfTau28_hez_final_13.ptau"
PTAU_PATH="${PTAU_DIR}/${PTAU_FILE}"

CIRCUIT_MAIN="rln_main_griffin"
