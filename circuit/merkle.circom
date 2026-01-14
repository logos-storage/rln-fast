
pragma circom 2.1.1;

include "misc.circom";
include "poseidon2/compression.circom";

//------------------------------------------------------------------------------
// check a Merkle inclusion proof

template MerkleCheck(merkle_depth) {
  
  signal input leaf_hash;
  signal input leaf_idx;
  signal input merkle_path[merkle_depth];
  signal input merkle_root;

  signal idx_bits[merkle_depth] <== ToBits(merkle_depth)(leaf_idx);

  signal aux[merkle_depth+1];
  signal left[merkle_depth];
  signal right[merkle_depth];
  aux[0] <== leaf_hash;

  // reconstruct the root
  for(var i=0; i<merkle_depth; i++) {
    (left[i],right[i]) <== SwapIfOne()( idx_bits[i] , aux[i] , merkle_path[i] );
    aux[i+1]           <== Compress() ( left[i], right[i] );
  }

  aux[merkle_depth] === merkle_root;      // check that the reconstructed root matches !!!
} 

//------------------------------------------------------------------------------
