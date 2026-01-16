
import std/strutils
import std/streams
import std/random

import
  constantine/math/arithmetic,
  constantine/math/io/io_fields,
  constantine/math/io/io_bigints,
  constantine/named/algebras 

#from constantine/math/io/io_fields import toDecimal

import poseidon2/types
import poseidon2/io
export types

#-------------------------------------------------------------------------------

type BN254_T* = F
type Entropy* = F
type Hash*    = F
type Root*    = Hash

#-------------------------------------------------------------------------------

type 

  Seed* = uint64

  GlobalConfig* = object
    limit_bits*    : int
    merkle_depth*  : int     

  ProofInput* = object
    # public inputs
    merkle_root* : F
    ext_null*    : F
    msg_hash*    : F
    # private inputs    
    secret_key*  : F
    msg_limit*   : int
    leaf_idx*    : int
    merkle_path* : seq[F]
    msg_idx*     : int

  PartialInput* = object
    merkle_root* : F
    secret_key*  : F
    msg_limit*   : int
    leaf_idx*    : int
    merkle_path* : seq[F]

const defaultGlobalConfig* = 
  GlobalConfig( limit_bits: 16 , merkle_depth: 20 )

func extractPartialInputs*(input: ProofInput): PartialInput = 
  PartialInput( merkle_root : input.merkle_root 
              , secret_key  : input.secret_key  
              , msg_limit   : input.msg_limit   
              , leaf_idx    : input.leaf_idx    
              , merkle_path : input.merkle_path 
              )

#-----------------------------------------------

func intToBN254*(x: int): F = toF(x)

func uint64ToBN254*(x: uint64): F = toF(x)

func toDecimalF*(a : F): string =
  var s : string = toDecimal(a)
  s = s.strip( leading=true, trailing=false, chars={'0'} )
  if s.len == 0: s="0"
  return s

func toQuotedDecimalF*(x: F): string = 
  let s : string = toDecimalF(x)
  return ("\"" & s & "\"")

func addF*(x, y: F): F = x + y
func mulF*(x, y: F): F = x * y

# this is stupid, but it doesn't really matter here
proc randomF*(): F = 
  let mult : F = F.fromHex("0x0000000000000000000000000000000000000000000000010000000000000000")
  let a    : F =            uint64ToBN254(rand(uint64))
  let b    : F = a * mult + uint64ToBN254(rand(uint64))
  let c    : F = b * mult + uint64ToBN254(rand(uint64))
  let d    : F = c * mult + uint64ToBN254(rand(uint64))
  return d

proc writeLnF*(h: Stream, prefix: string, x: F) =
  h.writeLine(prefix & toQuotedDecimalF(x))

proc writeF*(h: Stream, prefix: string, x: F) =
  h.write(prefix & toQuotedDecimalF(x))

#-------------------------------------------------------------------------------
