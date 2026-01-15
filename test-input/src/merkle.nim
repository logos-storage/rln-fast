
import poseidon2/compress

import ./types
import ./misc

#-------------------------------------------------------------------------------

type 

  MerkleProof* = object
    leafIndex*  : int             # linear index of the leaf, starting from 0
    leafHash*   : F               # (hash of the value of the leaf 
    merklePath* : seq[F]          # order: from the bottom to the top
    depth*      : int             # depth of the tree

  # note: the first layer is the bottom layer, and the last layer is the root
  MerkleTree* = object
    layers* : seq[seq[F]]


#-------------------------------------------------------------------------------

func merkleTreeDepth*(tree: MerkleTree): int = tree.layers.len - 1

func extractMerkleRoot*(tree: MerkleTree): Hash =
  let n  = tree.layers.len
  let xs = tree.layers[n-1]
  assert( xs.len == 1 , "merkle root is not a singleton" )
  return xs[0]

#-------------------------------------------------------------------------------

proc getMerkleInclusionProof*(tree: MerkleTree, leaf_idx: int): MerkleProof =

  let N = tree.layers[0].len
  let D = merkleTreeDepth( tree )

  assert( pow2(D) == N , "not a full binary tree or depth/size inconsistency" )

  assert( 0 <= leaf_idx and leaf_idx < N , "leaf index out of bounds")

  var idx  : int    = leaf_idx
  var path : seq[F] = newSeq[F]( D )
  for k in 0..<D:
    let is_even = isEven(idx)
    let j = (idx shr 1)
    if is_even:
      path[k] = tree.layers[k][2*j+1]
    else:
      path[k] = tree.layers[k][2*j]

    idx = j

  return MerkleProof( leafIndex  : leaf_idx
                    , leafHash   : tree.layers[0][leaf_idx]
                    , merklePath : path
                    , depth      : D
                    )

#-------------------------------------------------------------------------------

func checkMerkleInclusionProof*(expected_root: F, proof: MerkleProof): bool = 

  let path: seq[F] = proof.merklePath
  var this: F      = proof.leafHash
  var idx:  int    = proof.leafIndex
  for i in 0..<proof.depth:
    var next : F 
    if isEven(idx):
      next = compress( this , path[i] )
    else: 
      next = compress( path[i] , this )
    idx  = (idx shr 1)
    this = next

  return (expected_root == this)

#-------------------------------------------------------------------------------

proc buildMerkleTree*( leaf_hashes: seq[F] ): MerkleTree =

  let zeroF : F = intToBN254(0)

  let depth : int = ceilingLog2( leaf_hashes.len )

  var layers : seq[seq[F]] = newSeq[seq[F]](depth+1)
  layers[0] = leaf_hashes

  var N    : int    = leaf_hashes.len
  var prev : seq[F] = leaf_hashes
  var i    : int    = 0;

  while( N > 1 ):
    i += 1

    let H = (N+1) div 2
    let is_even = (H+H == N)

    var next: seq[F] = newSeq[F](H)
    for k in 0..<H:
      let j = 2*k
      if j+1 < N:
        next[k] = compress( prev[j] , prev[j+1] )
      else:
        next[k] = compress( prev[j] , zeroF     )

    layers[i] = next 
    prev      = next        
    N         = H  

  return MerkleTree(layers: layers)

#-------------------------------------------------------------------------------

