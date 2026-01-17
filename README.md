rln-fast
--------

This is a proof-of-concept implementation (in Nim) of the following idea:

We want to speed up the proof generation of [Rate Limiting Nullifiers](https://rate-limiting-nullifier.github.io/rln-docs/) (RLN), by exploiting the following simple observation:

The witness of the Groth16 zero-knowledge proof is dominated by a part (namely, the Merkle inclusion proof) which changes much less often than the proof normally generation happens; and this fact combined with how Groth16 proofs work allows for a significant amount of precalculation. Details below.

Our [`circom`](https://docs.circom.io/) circuit is very similar to the one in [the PSE repo](https://github.com/Rate-Limiting-Nullifier/), and implements essentially the [RLNv2 spec](https://rfc.vac.dev/vac/raw/rln-v2), but it's not exactly the same (see below for the details). However this optimization should apply to those too the same way. 

### Benchmarks

TODO: proper benchmarking; but for some preliminary numbers, see below:

#### Circuit parameters

We used the default circuit parameters:

 - `LIMIT_BITS = 16` (max 65536 messages per epoch per user)
 - `MERKLE_DEPTH = 20` (max 1 million registered users)

Circuit sizes:

- witness size = 5637 field elements
- unchanging   = 5123 (can be precalculated)
- remaining    = 514 (to be done each time)

So we can see that only less than 10% of the witness is changing at every proof generation, the rest is changing only when a new user registers (and thus the Merkle tree changes).

#### Full proof with `nim-groth16`

Single-threaded (macbook pro M2), excluding witness generation:

    the quotient (FFTs) took 0.0151 seconds
    pi_A (G1 MSM)       took 0.0203 seconds
    rho  (G1 MSM)       took 0.0243 seconds
    pi_B (G2 MSM)       took 0.0869 seconds
    pi_C (2x G1 MSM)    took 0.0528 seconds
    ---------------------------------------
    full proof          took 0.2009 seconds

From this we can see that $\pi_B$ dominates, which is a good sign. We can also see that $\pi_C$ is significant too,
which is a less good sign. That's actually two computations, one of which we can speed up, the other one, not.

Some preliminary numbers for the partial proofs:

    generating full witness    : 0.0013 seconds
    generating full proof      : 0.2015 seconds

    generating partial witness : 0.0021 seconds
    generating partial proof   : 0.1362 seconds
    finishing partial proof    : 0.0630 seconds

So we can already see a nice speedup of about 300%.

Note: This is very much just a quickly hacked together experiment, and there may be some further optimization opportunities (though on a second sight, they appear to be very minor...).

### Differences from the PSE circuit

Note that we are not generic in the curve/field choice, requiring the BN254 curve. This is only a limitation of this particular implementation; it would work exactly the same with eg. BLS12-381.

Actual circuit differences:

- we use Poseidon2 hash instead of `circomlib`'s Poseidon. The main reason for this is that we needed compatible CPU and circuit implementations, and this was already implemented and ready to use. We need the CPU version to generate test inputs for the proof.
- we only use the Poseidon2 permutation with fixed width `t=3` (for simplicity, and the above reason). In contrast, `circomlib` offers various widths (I believe `t=2,3,4` is used in PSE's circuit. A width `t` permutation can consume `t-1` field elements in one invocation)
- when computing `a1`, we use the formula `a1 := H(sk+j|ext)` instead of `H(sk|ext|j)`, as this results in one less `t=3` hash invocation (but this shouldn't really cause any issues, as`sk` is authenticated and `j` is range checked (and small)).
- the Merkle root is an input, not an output (this way you cannot accidentally forget to check it to be correct externally, in the surrounding code)
- we input the Merkle leaf index directly, not as bits (you need check them to be bits anyway, so this is essentially free; and somewhat simpler to use)
- no external dependencies (note that `circomlib` is LGPL, and used to be GPL a few years ago)

Remarks: 

1. if one feels "uneasy" with the `sk+j` hack in `a1`, an  alternative while still keeping `t=3` would be to use `a1 = H(H(sk|ext)|j)`. This is more expensive (an extra hash permutation invocation), but the inner hash `H(sk|ext)` only changes once per epoch. So technically one could do a three-layered computation: Precompute most of the things when the Merkle root changes; precompute this one hash at the start of epoch; and finish at each message. We don't implement this 3 layers here, as it would add a lot of extra complexity. 
2. One could also just use a wider `t=4` permutation as in PSE's version (that's less expensive than two copies of the `t=3`, but more expensive than the `sk+j` version)
3. the computation `local_null = H(a1)` could be optimized by using a `t=2` Poseidon instance (instead of `t=3`), the same way as in the PSE version. We don't do that here simply because the lack of pre-made such Poseidon2 instance (see above).

### Circuit I/O

Public inputs:

- `"merkle_root"` (rarely changes)
- `"ext_null"` (changes once per epoch)
- `"msg_hash"` (changes at each message)

Private inputs:

- `"secret_key"` (never changes)
- `"msg_limit"` (never changes)
- `"leaf_idx"` (normally never changes, though I guess in theory the registry could "garbage collect" once a while)
- `"merkle_path"` (changes only when the Merkle root  changes)
- `"msg_idx"` (changes at each message)

Public outputs:

- `"y_value"`
- `"local_null"` 

We want to precalculate the part of the witness which only depends on the rarely changing inputs, including `"merkle_path"`; and also the part of the proof which only depends on this part of the witness.

### Partial witness generation

A first step is to figure out which part of the witness is constant (in practice, it's of course not constant just rarely changed, but we will call it constant for brevity).

As we prefer to use (relatively) high-level languages (eg. `circom`) to write our circuit, this should be automated; and we also need to split the witness generation into precalculation and finishing.

This is not too hard to do: We only need to annotate which circuit inputs (both private and public inputs) are constant, and then from the witness calculation graph we can derive all elements of the witness which are constant.

The same way we can also easily split the witness generation into two parts.

#### Witness computation graph

The goal of [`circom-witnesscalc`](https://github.com/iden3/circom-witnesscalc/), associated with `circom` (but kind of originated externally) is to "liberate" the witness generation from the "old circom" WASM/C++ generated code, both of which are _completely impenetrable_.

Remark: `circom` actually allows the _structure_ of the witness computation to depend on the input (not only on the circuit), which makes it more flexible (but harder to implement). But this flexibility is relatively rarely needed. Fortunately for us, because of the complexity, early versions couldn't handle this "dynamic" case, only the cases when the witness computation was a completely static, linear program (no control flow).

So while recent versions of `circom-witnesscalc` implement a virtual machine to execute the witness generation process (instead of the old generated WASM or non-portable C++), the initial versions produced a so-called "computation graph" instead, which is essentially a static linear sequence of primitive operations, without any control flow.

This graph can be exported into a file via the `build-circuit` program, and then can be parsed and interpreted, compiled or analysed. 

The static structure makes it very easy to figure out exactly which elements of the witness depend only the "constant" circuit inputs.

### Proof precalculation

Recall the formulas to calculate a Groth16 proof (if you are reading this on `github`, well, unfortunately, `github`'s LaTeX parsing is completely broken...):

$$
\begin{align*}
\pi_a  &:= [\alpha]_1 \;+\; \sum_{j=1}^M z_j*[\mathcal{A}_j(\tau)]_1 \;+\; r*[\delta]_1 \\
\rho   &:= [\beta]_1  \;+\; \sum_{j=1}^M z_j*[\mathcal{B}_j(\tau)]_1 \;+\; s*[\delta]_1 \\
\pi_b  &:= [\beta]_2  \;+\; \sum_{j=1}^M z_j*[\mathcal{B}_j(\tau)]_2 \;+\; s*[\delta]_2 \\
\pi_c  &:= \sum_{j=\ell+1}^M z_j*[K_j]_1 \;+\; \sum_{i=1}^N q_i*[Z_i]_1 \;+\; s*\pi_a \;+\; r*\rho \;-\; (rs)*[\delta]_1
\end{align*}
$$

Here $z\in\mathbb{F}^M$ denotes the witness vector; $[\mathcal{A}_j(\tau)]_1,\; [\mathcal{B}_j(\tau)]_1\in\mathbb{G}_1$, $[K_j]_1,\;[Z_i]_1\in\mathbb{G}_1$ and $[\mathcal{B}_j(\tau)]_2\in\mathbb{G}_2$ are fixed elliptic curve points (depending only the circuit and the trusted setup); $[\alpha]_1,\;[\beta]_1,\;[\beta]_2,\;[\delta]_1,\;[\delta]_2$ came from the so-called "toxic waste", also constant; $q_i$ are coefficients of the quotient polynomial (note: the [`snarkjs`](https://github.com/iden3/snarkjs) version is slightly different here); $r,s\in\mathbb{F}$ are blinding coefficients; and $*$ denotes the elliptic curve scalar multiplication.

Observe that this proof computation is dominated by 5 multi-scalar multiplications (MSM), **4 of which** depends only on the witness (the 5th is with the coefficients of the quotient polynomial, that unfortunately cannot be precalculated).

So we will simply precalculate the sums (MSM-s) of the form

$$[\alpha]_1 + \sum_{j\in \mathcal{F}}^M z_j*[\mathcal{A}_j(\tau)]_1 $$

where $\mathcal{F}\subset[1\dots M]$ is the set of witness indices which are unchanged; and then compute the remaining terms of the sum (over the complement indices) at the final proof generation.

The only other significant computation is computing the quotient polynomial; that's usually done with FFT. Some part of that can be also possibly partially precomputed, but most probably won't give a significant speedup.

#### Numerical experiments

From some measurement experiments, it seems that bulk (like 98%) of the Groth16 proof computation is spread over the following computations:

- $\pi_A$ is an MSM on $\mathbb{G}_1$ of size $M$
- $\rho$ is an MSM on $\mathbb{G}_1$ of size $M$
- $\pi_B$ is an MSM on $\mathbb{G}_2$ of size $M$ (note: $\mathbb{G}_2$ is significantly slower!)
- $\sum z_j*[K_j]$ which is a $\mathbb{G}_1$ MSM of size $(M-\#\mathsf{pub})\approx M$
- computing $q_i$, which is 3 IFFT / FFT pairs (basically 6 FFTs) of size $N$ (rounded up to the next power of two)
- $\sum q_i*[Z_i]$ which is again a size $N$ MSM on $\mathbb{G}_1$

(here $j\in[1\dots M]$ corresponds to the witness variables, and $i\in[1\dots N]$ to the equations. In practice $N\approx M$)

The first 4 of these offers a significant opportunity to  precalculation, but the last two doesn't really.

Given that these computations are pretty much what they are, observing any reasonable implementation gives you a rough bound of how much speedup this idea can get you. Based on this, unfortunately I don't expect any more low-hanging fruits (so, the 3x speedup it is).