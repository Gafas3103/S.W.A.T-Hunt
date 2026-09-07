extends Node3D

@export var aviso_abrir := "[E]  Abrir la puerta"
@export var angulo_abierta := -105.0
@export var duracion_apertura := 1.2

@onready var hoja: StaticBody3D = $Hoja
@onready var zona: Area3D = $Zona

var abierta := false
var abriendo := false

func _ready() -> void:
	zona.body_entered.connect(_al_entrar)
	zona.body_exited.connect(_al_salir)

func _al_entrar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("fijar_interaccion"):
		cuerpo.fijar_interaccion(self, _texto())

func _al_salir(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("quitar_interaccion"):
		cuerpo.quitar_interaccion(self)

func _texto() -> String:
	if abierta:
		return ""
	return aviso_abrir

func interactuar(jugador: Node) -> void:
	if abierta or abriendo:
		return

	abriendo = true

	var giro := create_tween()
	giro.set_trans(Tween.TRANS_CUBIC)
	giro.set_ease(Tween.EASE_IN_OUT)
	giro.tween_property(hoja, "rotation_degrees:y", angulo_abierta, duracion_apertura)
	await giro.finished

	abierta = true
	abriendo = false

	if jugador.has_method("quitar_interaccion"):
		jugador.quitar_interaccion(self)
