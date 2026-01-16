rln-fast
--------

This is a proof-of-concept implemetation of the following idea:

We want to speed up the proof generation of [Rate Limiting Nullifiers](https://rate-limiting-nullifier.github.io/rln-docs/) (RLN), by exploiting the following simple observation:

A dominating part of the witness of the Groth16 zero-knowledge proof changes much less often than the proof generation happens; and because of this, the structure of Groth16 proofs allows a significant amount of precalculation.

Our [`circom`](https://docs.circom.io/) circuit is very similar to the one in [the PSE repo](https://github.com/Rate-Limiting-Nullifier/), and implements essentially the [RLNv2 spec](https://rfc.vac.dev/vac/raw/rln-v2), but it's not exactly the same (see below for the details). However this optimization should apply to those too the same way. 

### Benchmarks

TODO: proper benchmarking; but for some preliminary numbers, see below:

#### Circuit parameters

We use the default circuit parameters:

 - `LIMIT_BITS = 16` (max 65536 messages per epoch per user)
 - `MERKLE_DEPTH = 20` (max 1 million registered users)

Circuit sizes

- witness size = 5637
- unchanging   = 5123
- remaining    = 514

So we can see that only less than 10% of the circuit is changing at every proof generation, the rest is changing when a new user registers (and thus the Merkle tree changes).

#### Full proof with `nim-groth16`

Single-threaded (macbook pro M2), excluding witness generation:

    the quotient (FFTs) took 0.0151 seconds
    pi_A (G1 MSM)       took 0.0203 seconds
    rho  (G1 MSM)       took 0.0243 seconds
    pi_B (G2 MSM)       took 0.0869 seconds
    pi_C (2x G1 MSM)    took 0.0528 seconds
    ---------------------------------------
    full proof          took 0.2009 seconds

From this we can see that $\pi_B$ dominates, which is a good sign.

Some preliminary numbers for the partial proofs:

    generating full witness    : 0.0013 seconds
    generating full proof      : 0.2015 seconds

    generating partial witness : 0.0021 seconds
    generating partial proof   : 0.1362 seconds
    finishing partial proof    : 0.0630 seconds

So we can already see a nice speedup of about 300%.

Note: This very much just hacked together, and there are further optimization opportunities.

### Differences from the PSE circuit

Note that we are not generic in the curve/field choice, requiring the BN254 curve. This is only a limitation of the implementation of this PoC, it would work exactly the same with eg. BLS12-381.

Actual differences:

- we use Poseidon2 hash instead of `circomlib`'s Poseidon 
- we only use the Poseidon2 permutation with fixed width `t=3` (for simplicity)
- when computing `a1`, we use the formula `a1 := H(sk+j|ext)` instead of `H(sk|ext|j)`, as this results in one less `t=3` hash invocation (but this shouldn't really cause any issues, as`sk` is authenticated and `j` is range checked)
- the Merkle root is an input, not an output (you won't forget to check out externally)
- we input the Merkle leaf index directly, not as bits (you need check them to be bits anyway, so this is essentially free; and somewhat simpler to use)
- no external dependencies

Remarks: 

1. if one feels "uneasy" with `sk+j` in `a1`, an  alternative while still keeping `t=3` would be to use `a1 = H(H(sk|ext)|j)`. This is more expensive (an extra hash invocation), but the inner hash `H(sk|ext)` only changes once per epoch. So technically one could do a three-layered computation: Precompute most of the things when the Merkle root changes; precompute this one hash at the start of epoch; and finish at each message. We don't implement this 3 layers here, as it would add a lot of complexity.
2. the computation `local_null = H(a1)` could be optimized by using a `t=2` Poseidon instance (instead of `t=3`). We don't do that here because the lack of pre-made such Poseidon2 instance.

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

We want to precalculate the part of the witness which only depends on the rarely changing inputs, including `"merkle_path"`.

### Partial witness generation

A first step is to figure out which part of the witness is constant (in practice, it's of course not constant just rarely changed, but we will call it constant for brevity).

As we prefer to use (relatively) high-level languages (eg. `circom`) to write our circuit, this should be automated; and we also need to split the witness generation into precalculation and finishing.

This is not too hard to do: We only need to annotation which inputs (both private and public inputs) are constant, and then from the witness calculation graph we can derive all elements of the witness which are constant.

Then based on this we can also easily split the witness generation into two.

### Proof precalculation

Recall the formulas to calculate a Groth16 proof:

$$
\begin{align*}
\pi_a  &:= [\alpha]_1 \;+\; \sum_{j=1}^M z_j*[\mathcal{A}_j(\tau)]_1 \;+\; r*[\delta]_1 \\
\rho   &:= [\beta]_1  \;+\; \sum_{j=1}^M z_j*[\mathcal{B}_j(\tau)]_1 \;+\; s*[\delta]_1 \\
\pi_b  &:= [\beta]_2  \;+\; \sum_{j=1}^M z_j*[\mathcal{B}_j(\tau)]_2 \;+\; s*[\delta]_2 \\
\pi_c  &:= \sum_{j=\ell+1}^M z_j*[K_j]_1 \;+\; \sum_{i=1}^N q_i*[Z_i]_1 \;+\; s*\pi_a \;+\; r*\rho \;-\; (rs)*[\delta]_1
\end{align*}
$$

Here $z\in\mathbb{F}^M$ denotes the witness vector, $[\mathcal{A}_j(\tau)]_1,\; [\mathcal{B}_j(\tau)]_1\in\mathbb{G}_1$, $[K_j]_1,\;[Z_i]_1\in\mathbb{G}_1$ and $[\mathcal{B}_j(\tau)]_2\in\mathbb{G}_2$ are fixed elliptic curve points (depending only the circuit, and some on the trusted setup too) $[\alpha]_1,\;[\beta]_1,\;[\beta]_2,\;[\delta]_1,\;[\delta]_2$ come from the so-called "toxic waste"; $q_i$ are coefficients of the quotient polynomials (remark: the [`snarkjs`](https://github.com/iden3/snarkjs) version is slightly different here); $r,s\in\mathbb{F}$ are blinding coefficients; and $*$ denotes elliptic curve scalar multiplication.

Observe that this computation is dominated by 5 multi-scalar multiplications (MSM), _4 of which_ depends only on the witness (the 5th is with the coefficients of the quotient polynomial, that unfortunately cannot be precalculated).

So we will simply precalculate the sums (MSM-s) of the form

$$\sum_{j\in \mathcal{F}}^M z_j*[\mathcal{A}_j(\tau)]_1 $$

where $\mathcal{F}\subset[1\dots M]$ is the set of witness indices which are unchanged, and the the remaing sum (over the complement indices) at the final proof generation.

The only other significant computation is computing the quotient polynomial; that's usually done with FFT. Some part of that can be partially precomputed, but probably won't give a significant speedup.


