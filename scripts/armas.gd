extends Node3D

signal municion_cambiada(cargador: int, reserva: int)
signal arma_cambiada(nombre: String, indice: int)

const ARMAS := [
	{
		"nombre": "HK416",
		"nodo": "HK416",
		"dano": 24,
		"cadencia": 0.11,
		"automatica": true,
		"cargador_max": 30,
		"reserva_max": 180,
		"alcance": 90.0,
		"dispersion": 0.014,
		"zoom": 42.0,
		"cuerpo_a_cuerpo": false
	},
	{
		"nombre": "Pistola",
		"nodo": "Pistola",
		"dano": 18,
		"cadencia": 0.26,
		"automatica": false,
		"cargador_max": 12,
		"reserva_max": 96,
		"alcance": 45.0,
		"dispersion": 0.022,
		"zoom": 52.0,
		"cuerpo_a_cuerpo": false
	},
	{
		"nombre": "Cuchillo",
		"nodo": "Cuchillo",
		"dano": 65,
		"cadencia": 0.65,
		"automatica": false,
		"cargador_max": 0,
		"reserva_max": 0,
		"alcance": 2.4,
		"dispersion": 0.0,
		"zoom": 68.0,
		"cuerpo_a_cuerpo": true
	}
]

var indice := 0
var cargadores: Array[int] = []
var reservas: Array[int] = []
var espera := 0.0
var brillo := 0.0


func _ready() -> void:
	for datos_arma in ARMAS:
		cargadores.append(datos_arma["cargador_max"])
		reservas.append(datos_arma["reserva_max"])
	cambiar(0)


func _process(delta: float) -> void:
	if espera > 0.0:
		espera -= delta
	if brillo > 0.0:
		brillo -= delta
		if brillo <= 0.0:
			apagar_fogonazo()


func datos() -> Dictionary:
	return ARMAS[indice]


func nodo_actual() -> Node3D:
	return get_node_or_null(NodePath(datos()["nodo"]))


func punta() -> Node3D:
	var n := nodo_actual()
	if n == null:
		return self
	var p := n.get_node_or_null(^"Punta")
	if p == null:
		return n
	return p


func apagar_fogonazo() -> void:
	for datos_arma in ARMAS:
		var n := get_node_or_null(NodePath(datos_arma["nodo"]))
		if n == null:
			continue
		var luz := n.get_node_or_null(^"Fogonazo")
		if luz != null:
			luz.visible = false


func cambiar(nuevo: int) -> void:
	indice = clampi(nuevo, 0, ARMAS.size() - 1)
	for datos_arma in ARMAS:
		var n := get_node_or_null(NodePath(datos_arma["nodo"]))
		if n != null:
			n.visible = datos_arma["nodo"] == datos()["nodo"]
	espera = 0.35
	brillo = 0.0
	apagar_fogonazo()
	arma_cambiada.emit(datos()["nombre"], indice)
	avisar_municion()


func siguiente() -> void:
	cambiar((indice + 1) % ARMAS.size())


func anterior() -> void:
	cambiar((indice - 1 + ARMAS.size()) % ARMAS.size())


func avisar_municion() -> void:
	municion_cambiada.emit(cargadores[indice], reservas[indice])


func cargador_lleno() -> bool:
	return cargadores[indice] >= int(datos()["cargador_max"])


func puede_disparar() -> bool:
	if espera > 0.0:
		return false
	if datos()["cuerpo_a_cuerpo"]:
		return true
	return cargadores[indice] > 0


func sin_balas() -> bool:
	if datos()["cuerpo_a_cuerpo"]:
		return false
	return cargadores[indice] <= 0


func gastar() -> void:
	espera = datos()["cadencia"]
	if datos()["cuerpo_a_cuerpo"]:
		return
	cargadores[indice] -= 1
	avisar_municion()
	brillo = 0.05
	var n := nodo_actual()
	if n != null:
		var luz := n.get_node_or_null(^"Fogonazo")
		if luz != null:
			luz.visible = true


func recargar() -> bool:
	if datos()["cuerpo_a_cuerpo"]:
		return false
	if cargador_lleno() or reservas[indice] <= 0:
		return false
	var faltan: int = int(datos()["cargador_max"]) - cargadores[indice]
	var mueve: int = mini(faltan, reservas[indice])
	cargadores[indice] += mueve
	reservas[indice] -= mueve
	espera = 1.2
	avisar_municion()
	return true


func dar_municion(cantidad: int) -> void:
	reservas[indice] = mini(reservas[indice] + cantidad, int(datos()["reserva_max"]))
	avisar_municion()
