extends CharacterBody3D

signal murio(enemigo: Node)

const ANIMACIONES := {
	"quieto": "res://assets3d/rifle aiming idle.fbx",
	"disparar": "res://assets3d/firing rifle.fbx",
	"golpeado": "res://assets3d/hit reaction.fbx",
	"morir": "res://assets3d/walking to dying.fbx"
}

@export var vida_maxima := 100
@export var dano := 8
@export var cadencia := 1.25
@export var rango_vision := 22.0
@export var precision := 0.45
@export var altura_ojos := 1.55
@export var suelta_llave := false
@export var escena_llave: PackedScene

@onready var modelo: Node3D = $character
@onready var esqueleto: Skeleton3D = $character/Skeleton3D
@onready var anim: AnimationPlayer = $character/AnimationPlayer
@onready var arma: Node3D = $Arma
@onready var colision: CollisionShape3D = $Colision

var vida := 0
var jugador: Node3D = null
var espera := 0.0
var accion := 0.0
var muerto := false
var animacion_actual := ""


func _ready() -> void:
	add_to_group("enemigo")
	vida = vida_maxima
	_preparar_animaciones()
	_montar_arma()
	_pintar()
	_pintar_arma()
	espera = randf_range(0.3, 1.2)
	jugador = get_tree().get_first_node_in_group("jugador") as Node3D


func _preparar_animaciones() -> void:
	for clave in ANIMACIONES:
		if not anim.has_animation_library(clave):
			anim.add_animation_library(clave, load(ANIMACIONES[clave]))
	var quieto: Animation = anim.get_animation("quieto/mixamo_com")
	if quieto != null:
		quieto.loop_mode = Animation.LOOP_LINEAR
	_reproducir("quieto", 0.1)


func _montar_arma() -> void:
	var union := BoneAttachment3D.new()
	union.name = "ManoDerecha"
	esqueleto.add_child(union)
	union.bone_name = "mixamorig_RightHand"
	arma.reparent(union, false)


func _pintar() -> void:
	var tinte := StandardMaterial3D.new()
	tinte.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tinte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinte.albedo_color = Color(0.66, 0.14, 0.11, 0.18)
	for hijo in esqueleto.get_children():
		if hijo is MeshInstance3D:
			(hijo as MeshInstance3D).material_overlay = tinte


func _pintar_arma() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.12, 0.13)
	metal.metallic = 0.8
	metal.roughness = 0.42
	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.32, 0.18, 0.09)
	madera.roughness = 0.75
	_repartir_material(arma, metal, madera)


func _repartir_material(nodo: Node, metal: Material, madera: Material) -> void:
	if nodo is MeshInstance3D:
		var minuscula := String(nodo.name).to_lower()
		var es_madera := minuscula.contains("wood") or minuscula.contains("grip") or minuscula.contains("stock")
		(nodo as MeshInstance3D).material_override = madera if es_madera else metal
	for hijo in nodo.get_children():
		_repartir_material(hijo, metal, madera)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if muerto:
		return
	if accion > 0.0:
		accion -= delta
	if espera > 0.0:
		espera -= delta
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Node3D
		return
	if jugador.get("muerto") == true:
		return
	var distancia := global_position.distance_to(jugador.global_position)
	if distancia > rango_vision or not _lo_veo():
		if accion <= 0.0:
			_reproducir("quieto", 0.2)
		return
	_mirar_al_jugador(delta)
	if espera <= 0.0 and accion <= 0.0:
		_disparar()


func _lo_veo() -> bool:
	var origen := global_position + Vector3(0.0, altura_ojos, 0.0)
	var destino := jugador.global_position + Vector3(0.0, 1.2, 0.0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return true
	return golpe["collider"] == jugador


func _mirar_al_jugador(delta: float) -> void:
	var hacia := jugador.global_position - global_position
	hacia.y = 0.0
	if hacia.length() < 0.1:
		return
	var objetivo := atan2(hacia.x, hacia.z)
	modelo.rotation.y = lerp_angle(modelo.rotation.y, objetivo, delta * 6.0)


func _disparar() -> void:
	espera = cadencia
	accion = 0.4
	animacion_actual = ""
	anim.play("disparar/mixamo_com", 0.05)
	anim.seek(0.0, true)
	var luz := arma.get_node_or_null(^"Fogonazo")
	if luz != null:
		luz.visible = true
		get_tree().create_timer(0.06).timeout.connect(func(): luz.visible = false)
	if randf() > precision:
		return
	var origen := global_position + Vector3(0.0, altura_ojos, 0.0)
	var destino := jugador.global_position + Vector3(0.0, 1.2, 0.0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty() or golpe["collider"] != jugador:
		return
	if jugador.has_method("recibir_dano"):
		jugador.recibir_dano(dano)


func recibir_dano(cantidad: int, atacante: Node = null) -> void:
	if muerto:
		return
	vida -= cantidad
	if vida <= 0:
		_morir(atacante)
		return
	if accion <= 0.0:
		accion = 0.4
		animacion_actual = ""
		anim.play("golpeado/mixamo_com", 0.1)
		anim.seek(0.0, true)


func _morir(atacante: Node) -> void:
	muerto = true
	vida = 0
	colision.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	animacion_actual = ""
	anim.play("morir/mixamo_com", 0.2)
	var luz := arma.get_node_or_null(^"Fogonazo")
	if luz != null:
		luz.visible = false
	if suelta_llave and escena_llave != null:
		var raiz: Node = get_tree().current_scene
		if raiz == null:
			raiz = get_parent()
		var llave: Node3D = escena_llave.instantiate()
		llave.position = global_position + Vector3(0.0, 0.4, 0.0)
		raiz.add_child.call_deferred(llave)
	if atacante != null and atacante.has_method("avisar_baja"):
		atacante.avisar_baja()
	murio.emit(self)


func _reproducir(clave: String, mezcla: float) -> void:
	var nombre := clave + "/mixamo_com"
	if animacion_actual == nombre and anim.is_playing():
		return
	animacion_actual = nombre
	anim.play(nombre, mezcla)
