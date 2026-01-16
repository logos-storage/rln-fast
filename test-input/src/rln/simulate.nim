
# simulate to RLN proof for sanity checking

import std/options

import poseidon2/types
import poseidon2/compress

import ./types
import ./merkle
import ./misc

#-------------------------------------------------------------------------------

type 

  ProofOutput* = object
    y_value*    : F
    local_null* : F

proc simulateRLNProof*( globCfg: GlobalConfig, inp: ProofInput, verbose: bool): Option[ProofOutput] = 

  if inp.msg_limit < 1 or inp.msg_limit > pow2(globCfg.limit_bits):
    if verbose:
      echo "rln proof: FATAL: message upper bound not fitting into limit_bits"
    return none(ProofOutput)

  if inp.msg_idx < 0 or inp.msg_idx >= inp.msg_limit:
    if verbose:
      echo "rln proof: message index range check failed"
    return none(ProofOutput)

  let public_key : F = compress( inp.secret_key , intToBN254(inp.msg_limit) )
  let sk_plus_j  : F = addF( inp.secret_key ,  intToBN254(inp.msg_idx) )
  let a1         : F = compress( sk_plus_j , inp.ext_null )
  let y_value    : F = addF( inp.secret_key , mulf( inp.msg_hash , a1 ) )
  let local_null : F = compress( a1 , intToBN254(0) )

  let merkle_proof = MerkleProof(
          leafIndex   : inp.leaf_idx
        , leafHash    : public_key          
        , merklePath  : inp.merkle_path
        , depth       : globCfg.merkle_depth
        ) 

  if not checkMerkleInclusionProof( inp.merkle_root , merkle_proof ):
    if verbose:
      echo "rln proof: Merkle inclusion check failed"
    return none(ProofOutput)

  if verbose:
    echo "rln proof sanity checked OK."
  
  return some( ProofOutput( y_value: y_value , local_null: local_null ) )
  

proc sanityCheckRLNProof*( globCfg: GlobalConfig, proof_inputs: ProofInput , verbose: bool ): bool =
  isSome( simulateRLNProof( globCfg , proof_inputs , verbose ) )

#-------------------------------------------------------------------------------
