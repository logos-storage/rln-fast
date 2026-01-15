
Guide though the whole proof workflow
-------------------------------------

The workflow described below is implemented with shell scripts in this directory.
So the below is more like an explanation.

To run the full workflow:

- set the parameters by editing `params.sh`
- run `setup.sh` to do the circuit-specific setup
- run `prove.sh` to generate input, compute witness and create (and verify) the proof

NOTE: the examples below assume `bash`. In particular, it won't work with `zsh` 
(which is the dafault on newer macOS)! Because, you know, reasons...

To have an overview of what all the different steps and files are, see [PROOFS.md](PROOFS.md).

### Preliminaries

- install `circom`, `snarkjs`, `rapidsnark`: <https://docs.circom.io/getting-started/installation>
- furthermore install `circom-witnesscalc`: <https://github.com/iden3/circom-witnesscalc/> (note: we need the legacy `build-circuit` version!)
- install Nim: <https://nim-lang.org/>

Build the Nim cli proof input generator:

    $ cd ../test-input
    $ nimble build -d:release cli
    $ cd ../workflow

### Powers of tau setup

Either download a ready-to-use "powers of tau" setup file (section 7), or generate one
youself using `snarkjs` (sections 1..7), see the README here: <https://github.com/iden3/snarkjs>

Size `2^13 = 8192` (file size about 10MB) should be big enough:

    $ cd ../ceremony
    $ wget https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_13.ptau
    $ cd ../workflow

Note: generating this yourself will probably take quite some time (though this size is relatively small, so maybe not that bad).

### Set the parameters

There are quite a few parameters (run `cli --help` too see them), it's probably
best to collect them into a parameter file. Check out `params.sh` and `cli_args.sh` 
to see one way to do that.

You can edit `params.sh` to your taste before running the workflow scripts.

### Compile the circuit

Create a build directory so we don't pollute the repo:

    $ mkdir -p build
    $ cd build

After that, the first real step is to create the main component:

    $ source ../cli_args.sh && ../../reference/nim/proof_input/cli $CLI_ARGS -v --circom="rln_main.circom"

Then compile the circuit:

    $ export CIRCUIT_LIBDIRS="-l../../circuit/lib -l../../circuit/poseidon2 -l../../circuit/codex"
    $ circom --r1cs --wasm --O2 ${CIRCUIT_LIBDIRS} rln_main.circom

### Extract the witness computation graph

    $ build-circuit rln_main.circom rln_main.graph ${CIRCUIT_LIBDIRS}

### Do the circuit-specific setup

See the [`snarkjs` README](https://github.com/iden3/snarkjs) for an overview of
the whole process.

    $ snarkjs groth16 setup rln_main.r1cs ../../ceremony/powersOfTau28_hez_final_21.ptau rln_main_0000.zkey
    $ snarkjs zkey contribute rln_main_0000.zkey rln_main_0001.zkey --name="1st Contributor Name"

NOTE: with large circuits, javascript can run out of heap. You can increase the
heap limit with (but as this is a small circuit, this is not necessary):

    $ NODE_OPTIONS="--max-old-space-size=8192" snarkjs groth16 setup <...>

You can add more contributors here if you want.

Finally rename the last contributions result and export the verification key:

    $ rm rln_main_0000.zkey
    $ mv rln_main_0001.zkey rln_main.zkey
    
    $ snarkjs zkey export verificationkey rln_main.zkey rln_main_verification_key.json

NOTE: You have redo all the above if you change any of the five parameters the circuit 
depends on (these are: maxdepth, maxslots, cellsize, blocksize, nsamples).

### Generate an input to the circuit

    $ source ../cli_args.sh && ../../test-input/cli $CLI_ARGS -v --output=input.json --partial=partial.json

### Generate the witness

    $ cd rln_main_js
    $ time node generate_witness.js rln_main.wasm ../input.json ../witness.wtns
    $ cd ..

### Create the proof

Using `snarkjs` (very slow, but more portable):

    $ snarkjs groth16 prove rln_main.zkey witness.wtns proof.json public.json

Or using `rapidsnark` (fast, but not very portable):

    $ rapidsnark rln_main.zkey witness.wtns proof.json public.json

Or using `nim-groth16` (experimental):

    $ nim-groth16 -p -z=rln_main.zkey -w=witness.wtns -o=proof.json -i=public.json
    
The output of this step will consist of:

- `proof.json` containing the proof itself
- `public.json` containing the public inputs

### Verify the proof (on CPU)

    $ snarkjs groth16 verify rln_main_verification_key.json public.json proof.json

### Generate solidity verifier contract

    $ snarkjs zkey export solidityverifier rln_main.zkey verifier.sol

