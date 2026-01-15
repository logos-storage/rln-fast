
#
# export the proof inputs as a JSON file suitable for `snarkjs`
# 

import std/streams

import ../types
import shared

#-------------------------------------------------------------------------------

proc writeFieldElems(h: Stream, prefix: string, xs: seq[F]) = 
  writeList[F]( h, prefix, xs, writeLnF )

#-------------------------------------------------------------------------------

proc writeSingleMerklePath(h: Stream, prefix: string, path: seq[F]) = 
  writeFieldElems(h, prefix, path)

#-------------------------------------------------------------------------------

#[
  // public input
  signal input merkle_root;                 // the Merkle root we check against
  signal input ext_null;                    // the external "nullifier" ext = H(protocol|epoch)
  signal input msg_hash;                    // x = hash of the message

  // private input
  signal input secret_key;                  // the user's secret key
  signal input msg_limit;                   // message limit per epoch
  signal input msg_idx;                     // the message index (should be 0 <= msg_idx < msg_limit)
  signal input leaf_idx;                    // leaf index in the Merkle tree
  signal input merkle_path[merkle_depth];   // the Merkle inclusion proof
]#

proc exportProofInput*(fname: string, prfInput: ProofInput) = 
  let h = openFileStream(fname, fmWrite)
  defer: h.close()

  h.writeLine("{")
  h.writeLine("  \"merkle_root\":      " & toQuotedDecimalF(prfInput.merkle_root) )
  h.writeLine(", \"ext_null\":         " & toQuotedDecimalF(prfInput.ext_null   ) )
  h.writeLine(", \"msg_hash\":         " & toQuotedDecimalF(prfInput.msg_hash   ) )
  h.writeLine(", \"secret_key\":       " & toQuotedDecimalF(prfInput.secret_key ) )
  h.writeLine(", \"msg_limit\":        " & toQuotedDecimalF(intToBN254(prfInput.msg_limit)) )
  h.writeLine(", \"msg_idx\":          " & toQuotedDecimalF(intToBN254(prfInput.msg_idx  )) )
  h.writeLine(", \"leaf_idx\":         " & toQuotedDecimalF(intToBN254(prfInput.leaf_idx )) )
  h.writeLine(", \"merkle_path\":")
  writeSingleMerklePath(h, "  ", prfInput.merkle_path )
  h.writeLine("}")

proc exportPartialInput*(fname: string, prfInput: PartialInput) = 
  let h = openFileStream(fname, fmWrite)
  defer: h.close()

  h.writeLine("{")
  h.writeLine("  \"merkle_root\":      " & toQuotedDecimalF(prfInput.merkle_root) )
  h.writeLine(", \"secret_key\":       " & toQuotedDecimalF(prfInput.secret_key ) )
  h.writeLine(", \"msg_limit\":        " & toQuotedDecimalF(intToBN254(prfInput.msg_limit)) )
  h.writeLine(", \"leaf_idx\":         " & toQuotedDecimalF(intToBN254(prfInput.leaf_idx )) )
  h.writeLine(", \"merkle_path\":")
  writeSingleMerklePath(h, "  ", prfInput.merkle_path )
  h.writeLine("}")

#-------------------------------------------------------------------------------
