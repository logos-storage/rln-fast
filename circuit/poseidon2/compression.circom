pragma circom 2.1.1;

include "permutation.circom";

//
// The Poseidon2 compression function 
// (used for example when constructing binary Merkle trees)
//

//------------------------------------------------------------------------------
// the "compression function" takes 2 field elements as input and produces
// 1 field element as output. It is a trivial application of the permutation.

template Compress() {
  signal input  inp0;
  signal input  inp1;
  signal output out;

  component perm = Permutation();
  perm.inp[0] <== inp0;
  perm.inp[1] <== inp1;
  perm.inp[2] <== 0;

  perm.out[0] ==> out;
}

//------------------------------------------------------------------------------
