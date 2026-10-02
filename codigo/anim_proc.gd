class_name AnimProc
extends RefCounted
## Port de ProceduralAnim.ts y GestoPoder.ts de la version web (mismas formulas, ya probadas alli).
## Resorte criticamente amortiguado (Holden), respiracion organica y la curva de esfuerzo de los gestos.

const LN2 := 0.6931471805599453

# Curva de esfuerzo: anticipacion tensa -> subida laboriosa -> pico tardio -> aguante -> resorte.
const FIN_TENSION := 0.18
const T_PICO := 0.55
const FIN_HOLD := 0.67
const AMPL_TENSION := 0.15
const TB := 0.12  # escala base del temblor en rotaciones

## 6 poderes del GDD §10 x 2 variantes (AnimacionesPoder.ts). `dedos`: apreton | abanico | ola.
const REPERTORIO := {
	"halcon": [
		{nombre="garra_alta", duracion=0.95, seed=0.1, rot=Vector3(0.6, 0, -0.15), pos=Vector3(0, 0.05, 0), muneca=0.3, dedos="apreton", dedo_amt=0.7, espasmo=0.5},
		{nombre="zarpazo_frontal", duracion=1.05, seed=0.7, rot=Vector3(0.3, -0.2, 0.25), pos=Vector3(0, 0.02, -0.06), muneca=0.4, dedos="apreton", dedo_amt=0.8, espasmo=0.6},
	],
	"sapo": [
		{nombre="palmada_baja", duracion=0.9, seed=0.2, rot=Vector3(0.5, 0, 0), pos=Vector3(0, -0.14, 0.02), muneca=0.2, dedos="abanico", dedo_amt=0.5, espasmo=0.4},
		{nombre="aplastar", duracion=1.0, seed=0.85, rot=Vector3(0.6, 0.12, -0.08), pos=Vector3(0, -0.12, 0), muneca=0.3, dedos="abanico", dedo_amt=0.6, espasmo=0.5},
	],
	"amaru": [
		{nombre="ondular", duracion=1.15, seed=0.3, rot=Vector3(0, 0.25, 0.3), pos=Vector3.ZERO, muneca=0.3, dedos="ola", dedo_amt=0.5, espasmo=0.5},
		{nombre="reptar", duracion=1.2, seed=0.9, rot=Vector3(-0.1, -0.25, -0.3), pos=Vector3(0, 0.01, 0), muneca=0.35, dedos="ola", dedo_amt=0.5, espasmo=0.5},
	],
	"condor": [
		{nombre="alas", duracion=1.25, seed=0.15, rot=Vector3(-0.4, 0, 0.5), pos=Vector3(0, 0.02, 0), muneca=-0.2, dedos="abanico", dedo_amt=0.7, espasmo=0.3},
		{nombre="planear", duracion=1.3, seed=0.6, rot=Vector3(-0.5, 0.15, 0.4), pos=Vector3(0.02, 0.03, 0), muneca=-0.25, dedos="abanico", dedo_amt=0.6, espasmo=0.35},
	],
	"puma": [
		{nombre="acecho", duracion=0.95, seed=0.25, rot=Vector3(0.2, 0, 0), pos=Vector3(0, 0, -0.08), muneca=0.25, dedos="apreton", dedo_amt=0.6, espasmo=0.6},
		{nombre="zarpa", duracion=1.0, seed=0.75, rot=Vector3(0.1, 0.15, 0.1), pos=Vector3(0, 0.02, -0.06), muneca=0.3, dedos="apreton", dedo_amt=0.7, espasmo=0.6},
	],
	"colibri": [
		{nombre="aleteo", duracion=0.7, seed=0.4, rot=Vector3(0.1, 0, 0.2), pos=Vector3(0, 0.04, 0), muneca=0.15, dedos="apreton", dedo_amt=0.25, espasmo=0.9},
		{nombre="vibrar", duracion=0.65, seed=0.95, rot=Vector3(0.08, 0, -0.2), pos=Vector3(0.03, 0.03, 0), muneca=0.2, dedos="apreton", dedo_amt=0.2, espasmo=1.0},
	],
}


static func curva_esfuerzo(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < FIN_TENSION:
		var s := t / FIN_TENSION
		return -AMPL_TENSION * (s * s * (3.0 - 2.0 * s))
	if t < T_PICO:
		var s := (t - FIN_TENSION) / (T_PICO - FIN_TENSION)
		return -AMPL_TENSION + (1.0 + AMPL_TENSION) * pow(s, 1.3)
	if t < FIN_HOLD:
		return 1.0
	var tau := (t - FIN_HOLD) / (1.0 - FIN_HOLD)
	return exp(-3.4 * tau) * cos(5.4 * tau)


static func espasmo(t: float, semilla: float = 0.0) -> float:
	var env := maxf(0.0, sin(PI * pow(maxf(t, 0.0), 0.85)))
	return env * (sin(t * 90.0 + semilla * 5.0) * 0.6 + sin(t * 151.0 + semilla * 3.0 + 1.0) * 0.4)


static func respiracion(t: float, amplitud: float = 1.0) -> Vector2:
	var y := (sin(t * 1.6) * 0.7 + sin(t * 0.9 + 1.3) * 0.3) * amplitud
	var x := sin(t * 1.1 + 0.5) * amplitud
	return Vector2(x, y)


static func _negexp_rapido(x: float) -> float:
	return 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)


## Devuelve [x, v] tras dt: el resorte persigue `objetivo`; `halflife` = tiempo en que el error se reduce a la mitad.
static func resorte(x: float, v: float, objetivo: float, halflife: float, dt: float) -> Array[float]:
	var y := (2.0 * LN2) / maxf(1e-5, halflife)
	var j0 := x - objetivo
	var j1 := v + j0 * y
	var e := _negexp_rapido(y * dt)
	return [e * (j0 + j1 * dt) + objetivo, e * (v - j1 * y * dt)]


static func variante_al_azar(poder: String, rng: RandomNumberGenerator) -> Dictionary:
	var lista: Array = REPERTORIO[poder]
	return lista[rng.randi() % lista.size()]
