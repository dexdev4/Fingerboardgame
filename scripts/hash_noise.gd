## Deterministic integer-hash noise for world generation.
## Same inputs → same output on every device and every run (no engine RNG, no floats in the
## hash). All values are kept inside 32 bits (& M) so the 64-bit multiplications never overflow.
class_name HashNoise
extends RefCounted

const M := 0xFFFFFFFF


## 32-bit hash of (seed, x, y, salt). `salt` separates independent noise "channels"
## (caves, ores, pickups...) that share a seed.
static func hash_i(seed: int, x: int, y: int = 0, salt: int = 0) -> int:
	var h: int = ((x * 73856093) ^ (y * 19349663) ^ ((seed & M) * 83492791) ^ (salt * 1103515245)) & M
	# Murmur-style finaliser: spreads every input bit over the whole output.
	h ^= h >> 16
	h = (h * 0x45d9f3b) & M
	h ^= h >> 16
	h = (h * 0x45d9f3b) & M
	h ^= h >> 16
	return h


## Hash → float in [0, 1).
static func hash_f(seed: int, x: int, y: int = 0, salt: int = 0) -> float:
	return float(hash_i(seed, x, y, salt)) / 4294967296.0


## Smooth 1D value noise in [0, 1]: random values at integer points, smoothstep between them.
static func value1(seed: int, salt: int, x: float) -> float:
	var i := floori(x)
	var f := x - i
	var s := f * f * (3.0 - 2.0 * f)
	return lerpf(hash_f(seed, i, 0, salt), hash_f(seed, i + 1, 0, salt), s)


## Smooth 2D value noise in [0, 1] (bilinear between random corner values, smoothstep weights).
static func value2(seed: int, salt: int, x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sy := fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(hash_f(seed, ix, iy, salt), hash_f(seed, ix + 1, iy, salt), sx)
	var b := lerpf(hash_f(seed, ix, iy + 1, salt), hash_f(seed, ix + 1, iy + 1, salt), sx)
	return lerpf(a, b, sy)


## Fractal 1D noise: `octaves` layers, each twice the frequency and half the strength. [0, 1].
static func fbm1(seed: int, salt: int, x: float, octaves: int) -> float:
	var sum := 0.0
	var amp := 1.0
	var norm := 0.0
	var f := 1.0
	for o in octaves:
		sum += value1(seed, salt + o * 101, x * f) * amp
		norm += amp
		amp *= 0.5
		f *= 2.0
	return sum / norm


## Fractal 2D noise. [0, 1].
static func fbm2(seed: int, salt: int, x: float, y: float, octaves: int) -> float:
	var sum := 0.0
	var amp := 1.0
	var norm := 0.0
	var f := 1.0
	for o in octaves:
		sum += value2(seed, salt + o * 101, x * f, y * f) * amp
		norm += amp
		amp *= 0.5
		f *= 2.0
	return sum / norm
