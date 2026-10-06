// Pisos ecologicos de los Andes centrales del Peru por altitud real (msnm), para el relieve lejano (Terreno) y la
// cordillera del fondo (Cordillera). Junio = estacion seca: la puna esta pajiza y no hay nevadas que bajen la cota.
//   valles interandinos  < 3300 m   verdes (chacras, matorral de molle)
//   quenuales (Polylepis) 3500-4400  bosquetes oscuros solo en quebradas (lo concavo)
//   puna                 3800-4700   ichu pajizo; bofedales verdes en lo llano y concavo
//   superpuna            4600-4950   pedregal gris pardo con plantas en cojin (yareta)
//   nieve                > ~4950     mas abajo en las caras al sur (sombrias en el hemisferio sur) y en los circos,
//                                    mas arriba en las caras al norte y en la vertiente seca del oeste; las paredes de
//                                    mas de ~50 grados no la sostienen (vetas de roca); lenguas de glaciar hasta ~4650
// Fuentes: linea de nieve 4700 (este humedo) a 5100 m (oeste seco) en el Peru central; ELA tropical > 5000 m con
// lenguas hasta ~4600 m (docs/PLAN_NIVEL1.md).

const float BIO_PLAZA_MSNM = 3482.0;

// La altura del mundo esta exagerada (herramientas/hornear_relieve.gd): x1,4 cerca de la plaza, x2,6 desde ~6 km. La
// cordillera usa la misma x2,6.
float bio_exageracion(float r) {
	return mix(1.4, 2.6, smoothstep(700.0, 6000.0, r));
}

float bio_msnm(vec3 p_mundo) {
	return BIO_PLAZA_MSNM + p_mundo.y / bio_exageracion(length(p_mundo.xz));
}

float bio_azar(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float bio_ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(bio_azar(i), bio_azar(i + vec2(1.0, 0.0)), u.x), mix(bio_azar(i + vec2(0.0, 1.0)), bio_azar(i + vec2(1.0, 1.0)), u.x), u.y);
}

float bio_fbm(vec2 p) {
	return bio_ruido(p) * 0.5 + bio_ruido(p * 2.03 + 5.2) * 0.3 + bio_ruido(p * 4.1 + 1.7) * 0.2;
}

// Color (rgb) y rugosidad (a) del suelo.
//   m      altitud real (msnm)
//   n      normal del mundo
//   conc   concavidad 0..1 (quebradas, circos)
//   r1     ruido de gran escala 0..1 (manchas), r2 ruido fino 0..1
//   seco   0..1: vertiente seca del oeste (la nieve sube)
//   k_pend cuanto se atenua la pendiente del mundo: el relieve esta exagerado y con la pendiente del mundo casi todo
//          seria pared (el terreno pasa su exageracion; la cordillera algo menos, para que sus cumbres muestren roca)
vec4 bio_suelo(float m, vec3 n, float conc, float r1, float r2, float seco, float k_pend) {
	float pendiente = degrees(atan(tan(acos(clamp(n.y, 0.001, 1.0))) / k_pend));
	vec2 h = n.xz;
	float lh = length(h);
	// +1 cara al sur (+z), -1 cara al norte; 0 en lo llano.
	float sur = (lh > 0.001 ? h.y / lh : 0.0) * smoothstep(0.05, 0.3, lh);

	vec3 valle = vec3(0.35, 0.37, 0.23);   // junio: el valle esta mas seco que verde
	vec3 matorral = vec3(0.43, 0.39, 0.26);
	vec3 puna = mix(vec3(0.60, 0.50, 0.31), vec3(0.66, 0.57, 0.36), r2);
	vec3 bofedal = vec3(0.24, 0.36, 0.17);
	vec3 quenual = vec3(0.15, 0.21, 0.12);
	vec3 pedregal = mix(vec3(0.37, 0.31, 0.25), vec3(0.31, 0.26, 0.21), r1);
	vec3 cojin = vec3(0.30, 0.37, 0.19);
	vec3 roca = mix(vec3(0.23, 0.18, 0.14), vec3(0.31, 0.25, 0.19), r2);   // parda, rojiza: la roca seca andina
	vec3 nieve = vec3(0.88, 0.90, 0.95);
	vec3 glaciar = vec3(0.72, 0.81, 0.92);

	// Por altitud: valle -> matorral -> puna -> superpuna.
	vec3 c = mix(valle, matorral, smoothstep(3150.0, 3500.0, m + (r1 - 0.5) * 200.0));
	c = mix(c, puna, smoothstep(3600.0, 3900.0, m + (r1 - 0.5) * 250.0));
	float superpuna = smoothstep(4550.0, 4750.0, m + (r1 - 0.5) * 220.0);
	vec3 alto = mix(pedregal, cojin, step(0.82, r2) * 0.7);
	c = mix(c, alto, superpuna);
	// Bofedales: lo llano y concavo de la puna.
	float bof = smoothstep(0.985, 0.998, n.y) * smoothstep(0.35, 0.6, conc) * smoothstep(3850.0, 3950.0, m) * (1.0 - superpuna) * step(0.45, r1);
	c = mix(c, bofedal, bof);
	// Quenuales: bosquetes oscuros en quebradas de 3500 a 4400 m.
	float q = smoothstep(0.5, 0.75, conc) * smoothstep(3450.0, 3550.0, m) * (1.0 - smoothstep(4300.0, 4450.0, m)) * smoothstep(0.5, 0.65, r2);
	c = mix(c, quenual, q * 0.75);
	// Roca en las laderas fuertes (y en lo alto, donde no hay suelo).
	float en_roca = smoothstep(33.0 - superpuna * 10.0, 45.0 - superpuna * 10.0, pendiente + (r2 - 0.5) * 8.0);
	c = mix(c, roca, en_roca);
	float rugoso = 0.95;

	// Nieve.
	float cota = 4950.0 - 200.0 * max(sur, 0.0) + 150.0 * max(-sur, 0.0) + 100.0 * seco - 300.0 * conc + (r1 - 0.5) * 180.0;
	float n_alt = smoothstep(cota - 70.0, cota + 70.0, m);
	// Banda de manchas bajo la cota: nieve solo donde el ruido fino lo permite.
	n_alt = max(n_alt, smoothstep(cota - 160.0, cota - 40.0, m) * step(0.62, r2));
	float sostiene = 1.0 - smoothstep(46.0, 56.0, pendiente + (r2 - 0.5) * 14.0);
	float en_nieve = n_alt * sostiene;
	// Glaciar: en lo concavo y alto la nieve es hielo azulado con grietas.
	float hielo = smoothstep(0.45, 0.7, conc) * smoothstep(cota - 100.0, cota + 200.0, m);
	vec3 blanco = mix(nieve, glaciar, hielo * 0.7);
	float grieta = hielo * smoothstep(0.93, 0.98, abs(sin(m * 0.12 + r1 * 20.0)));
	blanco = mix(blanco, glaciar * 0.55, grieta);
	c = mix(c, blanco, en_nieve);
	rugoso = mix(rugoso, mix(0.65, 0.35, hielo), en_nieve);
	// La paleta de arriba esta en sRGB (como un selector de color); ALBEDO es lineal.
	return vec4(pow(max(c, vec3(0.0)), vec3(2.2)), rugoso);
}
