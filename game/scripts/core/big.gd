class_name Big
extends RefCounted
## Arbitrary-magnitude number stored as mantissa * 10^exponent.
## Mantissa is kept in [1, 10) (or 0). Values are immutable: every operation returns a new Big.

var m: float = 0.0
var e: int = 0


static func of(v: float) -> Big:
	var b := Big.new()
	b.m = v
	b.e = 0
	b._normalize()
	return b


static func me(mantissa: float, exponent: int) -> Big:
	var b := Big.new()
	b.m = mantissa
	b.e = exponent
	b._normalize()
	return b


static func zero() -> Big:
	return Big.new()


## base^power for positive base, computed in log space (no overflow).
static func power(base: float, p: float) -> Big:
	if base <= 0.0:
		return Big.zero()
	var lg: float = p * (log(base) / log(10.0))
	var ex: int = int(floor(lg))
	return Big.me(pow(10.0, lg - float(ex)), ex)


static func from_variant(v: Variant) -> Big:
	if v is Big:
		return v
	if v is Array and v.size() == 2:
		return Big.me(float(v[0]), int(v[1]))
	if v is float or v is int:
		return Big.of(float(v))
	if v is String:
		return Big.parse(v)
	return Big.zero()


static func parse(s: String) -> Big:
	var t := s.strip_edges().to_lower()
	if t.contains("e"):
		var parts := t.split("e")
		return Big.me(parts[0].to_float(), parts[1].to_int())
	return Big.of(t.to_float())


func _normalize() -> void:
	if m == 0.0 or is_nan(m):
		m = 0.0
		e = 0
		return
	if is_inf(m):
		m = 9.99
		e += 308
		return
	var a: float = absf(m)
	var shift: int = int(floor(log(a) / log(10.0)))
	if shift != 0:
		m = m / pow(10.0, shift)
		e += shift
	# guard against floating rounding (e.g. 9.9999999 -> 10)
	if absf(m) >= 10.0:
		m /= 10.0
		e += 1
	elif absf(m) < 1.0:
		m *= 10.0
		e -= 1


func is_zero() -> bool:
	return m == 0.0


func to_variant() -> Array:
	return [m, e]


func copy() -> Big:
	return Big.me(m, e)


func to_float() -> float:
	if e > 307:
		return INF if m > 0.0 else -INF
	if e < -307:
		return 0.0
	return m * pow(10.0, e)


func log10() -> float:
	if m <= 0.0:
		return -INF
	return log(m) / log(10.0) + float(e)


func add(o: Big) -> Big:
	if o.is_zero():
		return copy()
	if is_zero():
		return o.copy()
	var d: int = e - o.e
	if d > 17:
		return copy()
	if d < -17:
		return o.copy()
	if d >= 0:
		return Big.me(m + o.m / pow(10.0, d), e)
	return Big.me(o.m + m / pow(10.0, -d), o.e)


func neg() -> Big:
	return Big.me(-m, e)


func sub(o: Big) -> Big:
	return add(o.neg())


func mul(o: Big) -> Big:
	return Big.me(m * o.m, e + o.e)


func mulf(f: float) -> Big:
	return Big.me(m * f, e)


func div(o: Big) -> Big:
	if o.is_zero():
		push_error("Big.div by zero")
		return Big.zero()
	return Big.me(m / o.m, e - o.e)


func divf(f: float) -> Big:
	if f == 0.0:
		push_error("Big.divf by zero")
		return Big.zero()
	return Big.me(m / f, e)


## -1, 0, 1
func cmp(o: Big) -> int:
	var sa: int = signi(int(signf(m)))
	var sb: int = signi(int(signf(o.m)))
	if sa != sb:
		return 1 if sa > sb else -1
	if sa == 0:
		return 0
	var r: int = 0
	if e != o.e:
		r = 1 if e > o.e else -1
	elif m != o.m:
		r = 1 if m > o.m else -1
	return r * sa


func gte(o: Big) -> bool:
	return cmp(o) >= 0


func gt(o: Big) -> bool:
	return cmp(o) > 0


func lt(o: Big) -> bool:
	return cmp(o) < 0


func lte(o: Big) -> bool:
	return cmp(o) <= 0


func max_with(o: Big) -> Big:
	return copy() if gte(o) else o.copy()


func floor_big() -> Big:
	if e >= 15 or is_zero():
		return copy()
	if e < 0:
		return Big.zero() if m > 0.0 else Big.of(-1.0)
	return Big.of(floor(to_float() + 1e-9))


## Ratio self/o as float in [0, +inf) (useful for bars).
func ratio(o: Big) -> float:
	if o.is_zero():
		return 0.0
	var d: int = e - o.e
	if d > 300:
		return 1e300
	if d < -300:
		return 0.0
	return (m / o.m) * pow(10.0, d)


static func _group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if n < 0 else "") + out


static func _dec(v: float, digits: int) -> String:
	var txt := String.num(v, digits)
	return txt.replace(".", ",")


## French compact formatting: 1 500 · 2,4 M · 8,7 Md · 3,1 Bn · 1,25e18
func fmt() -> String:
	if is_zero():
		return "0"
	if e < 6:
		return Big._group(int(round(to_float())))
	var sgn := "-" if m < 0.0 else ""
	var am: float = absf(m)
	if e < 15:
		var units := ["M", "Md", "Bn"]
		var idx: int = int((e - 6) / 3)
		var val: float = am * pow(10.0, (e - 6) % 3)
		var digits: int = 2 if val < 10.0 else (1 if val < 100.0 else 0)
		return sgn + Big._dec(snappedf(val, pow(10.0, -digits)), digits) + " " + units[idx]
	return sgn + Big._dec(snappedf(am, 0.01), 2) + "e" + str(e)


func _to_string() -> String:
	return fmt()
