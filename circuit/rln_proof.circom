
pragma circom 2.1.1;

include "merkle.circom";
include "poseidon2/compression.circom";
include "misc.circom";

template RLN(limit_bits, merkle_depth) {

  // public input
  signal input msg_hash;                    // x = hash of the message
  signal input ext_null;                    // the external "nullifier" ext = H(protocol|epoch)
  signal input merkle_root;                 // the Merkle root we check against

  // private input
  signal input secret_key;                  // the user's secret key
  signal input msg_limit;                   // message limit per epoch
  signal input msg_idx;                     // the message index (should be 0 <= msg_idx < msg_limit)
  signal input leaf_idx;                    // leaf index in the Merkle tree
  signal input merkle_path[merkle_depth];   // the Merkle inclusion proof

  // public output
  signal output y_value;                    // the value y = sk + x * a1
  signal output local_null;                 // the "epoch-local nullifier" null = H(a1) (to detect repeated a1)

  // computations
  signal pk       <== Compress()( secret_key , msg_limit );           // public key - this doesn't ever change
  signal pre_a1   <== Compress()( secret_key , ext_null  );           // H(sk|ext)  - this doesn't change often
  signal a1       <== Compress()( pre_a1 , msg_idx );                 // a1 = H(H(sk|ext)|j)
  local_null      <== Compress()( a1 , 0 );                           // H(a1);
  y_value         <== secret_key + msg_hash * a1;                     // y = sk + x*a1

  // checks
  RangeCheck (limit_bits)  ( msg_idx , msg_limit );                           // range check for the message index
  MerkleCheck(merkle_depth)( pk , leaf_idx , merkle_path , merkle_root );     // Merkle inclusion proof check

}

