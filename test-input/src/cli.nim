
{. warning[UnusedImport]:off .}

import sugar
import std/strutils
import std/sequtils
import std/os
import std/parseopt

import std/random

import types
import json/bn254
import gen_inputs
import misc

#-------------------------------------------------------------------------------

type FullConfig = object
  globCfg:     GlobalConfig
  seed:        int64
  outFile:     string
  circomFile:  string
  partial:     bool
  verbose:     bool
  how_many:    int

const defaultFullCfg =
  FullConfig( globCfg:    defaultGlobalConfig
            , seed:       0
            , outFile:    ""
            , circomFile: ""
            , partial:    false
            , verbose:    false
            , how_many:   1
            )

#-------------------------------------------------------------------------------

proc printHelp() =
  echo "usage:"
  echo "$ ./cli [options] --output=proof_input.json --circom=proof_main.circom"
  echo ""
  echo "available options:"
  echo " -h, --help                         : print this help"
  echo " -v, --verbose                      : verbose output (print the actual parameters)"
  echo " -d, --merkle_depth = <depth>       : Merkle tree depth (default: 20)"
  echo " -b, --limit_bits   = <bits>        : log2 of maximum number of messages per epoch (default: 16)"
  echo " -s, --seed         = <seed>        : seed to generate the fake data (eg. 12345; default: random)"
  echo " -o, --output       = <input.json>  : the JSON file into which we write the proof inputs"
  echo " -c, --circom       = <main.circom> : the circom main component to create with these parameters"
  echo " -n, --count        = <K>           : generate K proof inputs at the same time (instead of 1)"
  echo " -p, --partial                      : generate partial input"
  echo ""

  quit()

#-------------------------------------------------------------------------------

proc parseCliOptions(): FullConfig =

  var globCfg = defaultGlobalConfig
  var fullCfg = defaultFullCfg

  # randomize the seed
  fullCfg.seed = rand(int64)  

  var argCtr: int = 0
  for kind, key, value in getOpt():
    case kind

    # Positional arguments
    of cmdArgument:
      # echo ("arg #" & $argCtr & " = " & key)
      argCtr += 1

    # Switches
    of cmdLongOption, cmdShortOption:
      case key

      of "h", "help"          : printHelp()
      of "v", "verbose"       : fullCfg.verbose       = true
      of "d", "merkle_depth"  : globCfg.merkle_depth  = parseInt(value) 
      of "b", "limit_bits"    : globCfg.limit_bits    = parseInt(value)
      of "s", "seed"          : fullCfg.seed          = int64(parseInt(value))
      of "o", "output"        : fullCfg.outFile       = value
      of "c", "circom"        : fullCfg.circomFile    = value
      of "p", "partial"       : fullCfg.partial       = true
      of "n", "count"         : fullCfg.how_many      = parseInt(value)
      else:
        echo "Unknown option: ", key
        echo "use --help to get a list of options"
        quit()

    of cmdEnd:
      discard  

  fullCfg.globCfg = globCfg

  assert( globCfg.merkle_depth >= 2 and globCfg.merkle_depth <=  22 )
  assert( globCfg.limit_bits   >= 2 and globCfg.limit_bits   <=  32 )
  assert( fullCfg.how_many     >= 1 and fullCfg.how_many     <= 100 )

  return fullCfg

#-------------------------------------------------------------------------------

proc printConfig(fullCfg: FullConfig) =

  let globCfg = fullCfg.globCfg

  # echo "field           = BN254"
  # echo "hash function   = Poseidon2"
  echo "merkle_depth    = " & ($globCfg.merkle_depth)
  echo "limit_bits      = " & ($globCfg.limit_bits)
  echo "random seed     = " & ($fullCfg.seed)
  echo "partial         = " & ($fullCfg.partial)
  echo "how many inputs = " & ($fullCfg.how_many)

#-------------------------------------------------------------------------------

proc writeCircomMainComponent(fullCfg: FullConfig, fname: string) = 

  let params: (int,int) = 
        ( fullCfg.globCfg.limit_bits
        , fullCfg.globCfg.merkle_depth
        )

  let f = open(fname, fmWrite)
  defer: f.close()

  f.writeLine("pragma circom 2.1.1;")
  f.writeLine("include \"rln_proof.circom\";")
  f.writeLine("// argument order convention: RLN(limit_bits, merkle_depth)")
  f.writeLine("component main {public [msg_hash, ext_null, merkle_root]} = RLN" & ($params) & ";")

#-------------------------------------------------------------------------------

when isMainModule:

  randomize()

  let fullCfg = parseCliOptions()
  let globCfg = fullCfg.globCfg

  # now use the set seed
  randomize(fullCfg.seed)

  if fullCfg.verbose:
    printConfig(fullCfg)

  if fullCfg.circomFile == "" and fullCfg.outFile == "":
    echo "nothing to do!"
    echo "use --help for getting a list of options"
    quit()

  if fullCfg.circomFile != "":
    let fname = fullCfg.circomFile
    echo "writing circom main component into `" & fname & "`"
    writeCircomMainComponent(fullCfg, fname)

  if fullCfg.outFile != "":
    let fname      = fullCfg.outFile
    let secretTree = genTreeWithSecrets( globCfg )
    let prfInput   = genProofInput( globCfg , secretTree )
    if fullCfg.partial:
      echo "writing partial proof input into `" & fname & "`..."
      let partial = extractPartialInputs( prfInput )
      exportPartialInput( fname, partial )
    else:
      echo "writing full proof input into `"    & fname & "`..."
      exportProofInput( fname, prfInput )

  echo "done"
