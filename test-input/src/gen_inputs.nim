
import std/random

import poseidon2/compress

import ./types
import ./misc
import ./merkle
import ./simulate

#-------------------------------------------------------------------------------

type

  Leaf* = object
    secret_key* : F
    public_key* : F 
    msg_limit*  : int

  TreeWithSecrets* = object
    leaves* : seq[Leaf]
    tree*   : MerkleTree

#-------------------------------------------------------------------------------

proc genTreeWithSecrets*(globCfg: GlobalConfig): TreeWithSecrets = 

  let N : int = pow2(globCfg.merkle_depth)
  let M : int = pow2(globCfg.limit_bits  )

  let maxMsgLimit = M - 1

  var public_keys : seq[F]    = newSeq[F   ]( N )  
  var leaves      : seq[Leaf] = newSeq[Leaf]( N )  

  for i in 0..<N:
    let secret_key = randomF()
    let msg_limit  = min( 1 , rand(M) )
    let public_key = compress( secret_key, intToBN254(msg_limit) );

    assert( msg_limit <= M , "msg limit hard bound failed")

    let leaf = Leaf( secret_key : secret_key 
                   , public_key : public_key  
                   , msg_limit  : msg_limit  
                   )

    public_keys[i] = public_key
    leaves[i]      = leaf

  let tree = buildMerkleTree( public_keys )

  return TreeWithSecrets(leaves: leaves, tree: tree)

#-------------------------------------------------------------------------------

proc genProofInput*( globCfg: GlobalConfig, secretTree: TreeWithSecrets): ProofInput = 

  let tree = secretTree.tree

  let N           : int = pow2(globCfg.merkle_depth)
  let maxLeafIdx  : int = N - 1
  let leaf_idx    : int = rand(maxLeafIdx)  

  let leaf = secretTree.leaves[leaf_idx]

  let msg_limit   : int = leaf.msg_limit
  let msg_idx     : int = rand( msg_limit - 1 )

  assert( leaf_idx  < N         )
  assert( msg_idx   < msg_limit )

  let ext_null   = randomF()  
  let msg_hash   = randomF()  

  let merkle_proof = getMerkleInclusionProof(tree, leaf_idx)
  let merkle_root  = extractMerkleRoot(tree)
  let merkle_path  = merkle_proof.merklePath

  assert( checkMerkleInclusionProof( merkle_root , merkle_proof ) , "merkle inclusion proof sanity check failed" )

  let proof_inputs = ProofInput( 
        # public inputs
          merkle_root  : merkle_root
        , ext_null     : ext_null
        , msg_hash     : msg_hash
          # private inputs    
        , secret_key   : leaf.secret_key
        , msg_limit    : msg_limit
        , leaf_idx     : leaf_idx
        , merkle_path  : merkle_path
        , msg_idx      : msg_idx
        )

  let ok = sanityCheckRLNProof( globCfg, proof_inputs, false )
  assert( ok , "RLN proof sanity check failed" )

  return proof_inputs

#-------------------------------------------------------------------------------

proc genManyProofInputs*( globCfg: GlobalConfig, secretTree: TreeWithSecrets, K: int): seq[ProofInput] =
  var inputs : seq[ProofInput] = newSeq[ProofInput]( K )
  for i in 0..<K:
    inputs[i] = genProofInput( globCfg, secretTree ) 
  return inputs

#-------------------------------------------------------------------------------
