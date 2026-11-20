#!/bin/bash

ORIG=`pwd`

NIMCLI_DIR="${ORIG}/../test-input/"
#PTAU_DIR="${ORIG}/../ceremony/"
PTAU_DIR="~/zk/ptau"

CIRCUIT_ROOT="${ORIG}/../circuit/"
CIRCUIT_INCLUDES="-l${CIRCUIT_ROOT}"

# PTAU_FILE="powersOfTau28_hez_final_14.ptau"
PTAU_FILE="powersOfTau28_hez_final_20.ptau"
PTAU_PATH="${PTAU_DIR}/${PTAU_FILE}"

CIRCUIT_MAIN="rln_main"
