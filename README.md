rln-fast
--------

This is a proof-of-concept implemetation of the following idea:

We want to speed up the proof generation of [Rate Limiting Nullifiers](https://rate-limiting-nullifier.github.io/rln-docs/) (RLN), by exploiting the following simple observation:

A dominating part of the witness of the Groth16 zero-knowledge proof changes much less often than the proof generation happens; and because of this, the structure of Groth16 proofs allows a significant amount of precalculation.

Our [`circom`](https://docs.circom.io/) circuit is very similar to the one in [the PSE repo](https://github.com/Rate-Limiting-Nullifier/), and implements essentially the [RLNv2 spec](https://rfc.vac.dev/vac/raw/rln-v2), but it's not exactly the same (see below for the details). However this optimization should apply to those too the same way. 

### Benchmarks

TODO after the implementation :)

### Differences from the PSE circuit

Note that we are not generic in the curve/field choice, requiring BN254 curve. This is only a limitation of the implementation of this PoC, it would work exactly the same with eg. BLS12-381.

Actual differences:

- we use Poseidon2 hash instead of `circomlib`'s Poseidon 
- we only use the Poseidon2 permutation with fixed width `t=3` (for simplicity)
- when computing `a1`, we use the formula `a1 := H(sk+j|ext)` instead of `H(sk|ext|j)`, as this results in one less hash invocation (but shouldn't really cause any difference)

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


