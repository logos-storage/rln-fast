
create test input data for `rln-fast`
-------------------------------------

Quickstart:

    $ nimble build cli
    $ ./cli --help

Examples:

    $ ./cli -v --merkle_depth=18 --limit_bits=12 --circom=main.circom --output=input.json --partial=partial.json
    $ ./cli -v -d=16 -b=10 --output=tmp/input.json --partial=tmp/partial.json
