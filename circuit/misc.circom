pragma circom 2.1.1;

//------------------------------------------------------------------------------

function FloorLog2(n) {
  return (n==0) ? -1 : (1 + FloorLog2(n>>1));
}

function CeilLog2(n) {
  return (n==0) ? 0 : (1 + FloorLog2(n-1));
}

//------------------------------------------------------------------------------
// decompose an n-bit number into bits (least significant bit first)

template ToBits(n) {
  signal input  inp;
  signal output out[n];

  var sum = 0;
  for(var i=0; i<n; i++) {
    out[i] <-- (inp >> i) & 1;
    out[i] * (1-out[i]) === 0;
    sum += (1<<i) * out[i];
  }

  inp === sum;
}

//------------------------------------------------------------------------------
// check range (0 <= i < limit)

template RangeCheck(limit_bits) {
  signal input what;
  signal input limit;

  _ <== ToBits(limit_bits)( what );                  // 0 <= what             < 2^limit_bits 
  _ <== ToBits(limit_bits)( limit - 1 - what );      // 0 <= limit - 1 - what < 2^limit_bits

  // note that `0 <= limit-1-what` is equivalent to `what < limit`, 
  // and we already have `0 <= what` from the first one.
}

//------------------------------------------------------------------------------
// conditional swap
// We swap if selector = 1, we don't swap if selector = 0
// NOTEe: we assume that the selector is already checked to be a bit!

template SwapIfOne() {
  signal input  selector;      // assumed to be a bit!
  signal input  inp0, inp1;
  signal output out0, out1;

  out0 <== inp0 + selector * ( inp1 - inp0 );
  out1 <== inp1 + selector * ( inp0 - inp1 );
}

//------------------------------------------------------------------------------
// check equality to zero; that is, compute `(inp==0) ? 1 : 0`

template IsZero() {
  signal input  inp;
  signal output out;

  // guess the inverse
  signal inv;
  inv <-- (inp != 0) ? (1/inp) : 0 ;

  // if `inp==0`, then by definition `out==1`
  // if `out==0`, then the inverse must must exist, so `inp!=0`
  out <== 1 - inp * inv;

  // enfore that either `inp` or `out` must be zero
  inp*out === 0;
}

//------------------------------------------------------------------------------
// check equality of two field elements; that is, computes `(A==B) ? 1 : 0`

template IsEqual() {
  signal input  A,B;
  signal output out;

  component isz = IsZero();
  isz.inp <== A - B;
  isz.out ==> out;
}

//------------------------------------------------------------------------------
