extends Node3D

@export var aviso_con_llave := "[E]  Abrir el candado"
@export var aviso_sin_llave := "Puerta con candado, falta la llave"
@export var angulo_abierta := -105.0
@export var duracion_apertura := 1.2
@export var velocidad_candado := 2.0

@onready var hoja: StaticBody3D = $Hoja
@onready var candado: Node3D = $Candado
@onready var zona: Area3D = $Zona

var abierta := false
var abriendo := false
var anim_candado: AnimationPlayer = null


func _ready() -> void:
	anim_candado = candado.find_child("AnimationPlayer", true, false)
	var llave := candado.get_node_or_null(^"Key")
	if llave != null:
		llave.visible = false
	zona.body_entered.connect(_al_entrar)
	zona.body_exited.connect(_al_salir)


func _al_entrar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("fijar_interaccion"):
		cuerpo.fijar_interaccion(self, _texto(cuerpo))


func _al_salir(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("quitar_interaccion"):
		cuerpo.quitar_interaccion(self)


func _texto(cuerpo: Node) -> String:
	if abierta:
		return ""
	if cuerpo.get("tiene_llave") == true:
		return aviso_con_llave
	return aviso_sin_llave


func interactuar(jugador: Node) -> void:
	if abierta or abriendo:
		return
	if jugador.get("tiene_llave") != true:
		if jugador.has_method("mostrar_aviso"):
			jugador.mostrar_aviso(aviso_sin_llave)
		return
	abriendo = true
	if jugador.has_method("mostrar_aviso"):
		jugador.mostrar_aviso("Abriendo el candado...", 0.0)
	var llave := candado.get_node_or_null(^"Key")
	if llave != null:
		llave.visible = true
	if anim_candado != null:
		anim_candado.speed_scale = velocidad_candado
		anim_candado.play("Scene")
		await anim_candado.animation_finished
	candado.visible = false
	var giro := create_tween()
	giro.set_trans(Tween.TRANS_CUBIC)
	giro.set_ease(Tween.EASE_IN_OUT)
	giro.tween_property(hoja, "rotation_degrees:y", angulo_abierta, duracion_apertura)
	await giro.finished
	abierta = true
	abriendo = false
	if jugador.has_method("quitar_interaccion"):
		jugador.quitar_interaccion(self)
