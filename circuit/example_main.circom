
pragma circom 2.1.1;

include "rln_proof.circom";

// argument conventions:
// RLN(limit_bits, merkle_depth) 

component main {public [msg_hash, ext_null, merkle_root]} = RLN(16,20);