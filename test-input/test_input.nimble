
version       = "0.0.0"
author        = "Balazs Komuves"
description   = "create test inputs for the RLN circuit"
license       = "MIT or Apache-2.0"
srcDir        = "src"
bin           = @["cli"]

requires "nim >= 2.0.0"
requires "https://github.com/mratsim/constantine#bc3845aa492b52f7fef047503b1592e830d1a774"
requires "https://github.com/logos-storage/nim-poseidon2#7749c368a9302167f94bd0133fb881cb83392caf"