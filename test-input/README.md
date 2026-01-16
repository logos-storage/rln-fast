
create test input data for `rln-fast`
-------------------------------------

### Generating test input for the RLN circuit

Quickstart:

    $ nimble build -d:release cli
    $ ./cli --help

Examples:

    $ ./cli -v --merkle_depth=18 --limit_bits=12 --circom=main.circom --output=input.json --partial=partial.json
    $ ./cli -v -d=16 -b=10 --output=tmp/input.json --partial=tmp/partial.json

### Testing the two-step prover

    $ nimble build -d:release prover_cli
    $ ./prover_cli --help

Exmaple

    $ DIR=<...> ./prover_cli -i=$DIR/input.json -p=$DIR/partial.json -g=$DIR/rln_main.graph -z=$DIR/rln_main.zkey
