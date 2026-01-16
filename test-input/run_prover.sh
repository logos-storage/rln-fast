#!/bin/bash

DIR="../workflow/build/"
./prover_cli --input=$DIR/input.json --partial=$DIR/partial.json --graph=$DIR/rln_main.graph --zkey=$DIR/rln_main.zkey
