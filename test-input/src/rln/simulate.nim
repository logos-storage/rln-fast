
# simulate to RLN proof for sanity checking

import std/options

import poseidon2/types
import poseidon2/compress         as posei
import poseidon2/griffin/compress as griffin

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

  var public_key : F 
  var sk_plus_j  : F 
  var a1         : F 
  var y_value    : F 
  var local_null : F 

  if globCfg.griffin:
    public_key = griffin.compress( inp.secret_key , intToBN254(inp.msg_limit) )
    sk_plus_j  = addF( inp.secret_key ,  intToBN254(inp.msg_idx) )
    a1         = griffin.compress( sk_plus_j , inp.ext_null )
    y_value    = addF( inp.secret_key , mulf( inp.msg_hash , a1 ) )
    local_null = griffin.compress( a1 , intToBN254(0) )

  else:
    public_key = posei.compression( inp.secret_key , intToBN254(inp.msg_limit) )
    sk_plus_j  = addF( inp.secret_key ,  intToBN254(inp.msg_idx) )
    a1         = posei.compression( sk_plus_j , inp.ext_null )
    y_value    = addF( inp.secret_key , mulf( inp.msg_hash , a1 ) )
    local_null = posei.compression( a1 , intToBN254(0) )

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
