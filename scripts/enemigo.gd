extends CharacterBody3D

signal murio(enemigo: Node)

const ANIMACIONES := {
	"quieto": "res://assets3d/player/rifle aiming idle.fbx",
	"caminar": "res://assets3d/player/walking.fbx",
	"disparar": "res://assets3d/player/firing rifle.fbx",
	"golpeado": "res://assets3d/player/hit reaction.fbx",
	"morir": "res://assets3d/player/walking to dying.fbx"
}
const CICLICAS := ["quieto", "caminar"]

@export var vida_maxima := 100
@export var dano := 8
@export var cadencia := 1.5
@export var rango_vision := 17.0
@export var angulo_vision := 220.0
@export var precision := 0.38
@export var altura_ojos := 1.55
@export var velocidad := 2.4
@export var distancia_combate := 8.0
@export var memoria := 2.5
@export var reaccion_min := 0.5
@export var reaccion_max := 1.4
@export var radio_patrulla := 4.0
@export var radio_aviso := 9.0
@export var suelta_llave := false
@export var escena_llave: PackedScene

@onready var modelo: Node3D = $character
@onready var esqueleto: Skeleton3D = $character/Skeleton3D
@onready var anim: AnimationPlayer = $character/AnimationPlayer
@onready var arma: Node3D = $Arma
@onready var colision: CollisionShape3D = $Colision
@onready var sangre: GPUParticles3D = $Sangre

var vida := 0
var jugador: Node3D = null
var espera := 0.0
var accion := 0.0
var muerto := false
var animacion_actual := ""
var estado := "patrulla"
var sitio := Vector3.ZERO
var destino := Vector3.ZERO
var ultima_vista := Vector3.ZERO
var sin_ver := 0.0
var descanso := 0.0
var reaccion := 0.0
var atasco := 0.0

var _pista := {}


func _ready() -> void:
	add_to_group("enemigo")
	vida = vida_maxima
	_preparar_animaciones()
	_montar_arma()
	_pintar_arma()
	espera = randf_range(0.3, 1.2)
	jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	sitio = global_position
	destino = global_position


func _preparar_animaciones() -> void:
	for clave in ANIMACIONES:
		if not anim.has_animation_library(clave):
			var lib: Variant = load(ANIMACIONES[clave])
			if lib is AnimationLibrary:
				anim.add_animation_library(clave, lib)
		if not anim.has_animation_library(clave):
			continue
		var lista := anim.get_animation_library(clave).get_animation_list()
		if lista.is_empty():
			continue
		var nombre := "%s/%s" % [clave, lista[0]]
		_pista[clave] = nombre
		var pista := anim.get_animation(nombre)
		if pista == null:
			continue
		_quitar_traslacion_raiz(pista)
		if clave in CICLICAS:
			pista.loop_mode = Animation.LOOP_LINEAR
	_reproducir("quieto", 0.1)


func _quitar_traslacion_raiz(a: Animation) -> void:
	for i in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var ruta := String(a.track_get_path(i))
		if ruta.ends_with(":mixamorig_Hips") or ruta.ends_with(":Hips"):
			a.remove_track(i)


func _montar_arma() -> void:
	var union := BoneAttachment3D.new()
	union.name = "ManoDerecha"
	esqueleto.add_child(union)
	union.bone_name = "mixamorig_RightHand"
	arma.reparent(union, false)


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
	if muerto:
		_frenar(delta)
		move_and_slide()
		if accion > 0.0:
			accion -= delta
		elif is_on_floor():
			set_physics_process(false)
		return
	if accion > 0.0:
		accion -= delta
	if espera > 0.0:
		espera -= delta
	if reaccion > 0.0:
		reaccion -= delta
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Node3D

	if _ve_al_jugador():
		ultima_vista = jugador.global_position
		sin_ver = 0.0
		reaccion = minf(reaccion, 0.15)
		estado = "combate" if _distancia() <= distancia_combate else "alerta"
	elif estado != "patrulla":
		sin_ver += delta
		if sin_ver >= memoria:
			estado = "patrulla"
			_nuevo_destino_patrulla()

	if reaccion > 0.0:
		_frenar(delta)
		_mirar_a(ultima_vista, delta)
		move_and_slide()
		_animar_movimiento()
		return

	match estado:
		"combate":
			_hacer_combate(delta)
		"alerta":
			_hacer_alerta(delta)
		_:
			_hacer_patrulla(delta)

	move_and_slide()
	_animar_movimiento()


func _hacer_combate(delta: float) -> void:
	_mirar_a(ultima_vista, delta)
	var dir := Vector3.ZERO
	if _distancia() < distancia_combate * 0.55:
		dir = _esquivar(global_position - jugador.global_position)
	_mover(dir, delta, velocidad * 0.7)
	if espera <= 0.0 and accion <= 0.0:
		_disparar()


func _hacer_alerta(delta: float) -> void:
	var plano := ultima_vista - global_position
	plano.y = 0.0
	if plano.length() < 0.7:
		_frenar(delta)
		return
	var dir := _esquivar(plano)
	_mirar_hacia(dir, delta)
	_mover(dir, delta, velocidad)


func _hacer_patrulla(delta: float) -> void:
	descanso -= delta
	var plano := destino - global_position
	plano.y = 0.0
	if plano.length() < 0.6:
		_frenar(delta)
		if descanso <= 0.0:
			_nuevo_destino_patrulla()
			descanso = randf_range(1.5, 4.0)
		return
	if Vector2(velocity.x, velocity.z).length() < 0.2:
		atasco += delta
		if atasco > 1.5:
			atasco = 0.0
			_nuevo_destino_patrulla()
			return
	else:
		atasco = 0.0
	var dir := _esquivar(plano)
	_mirar_hacia(dir, delta)
	_mover(dir, delta, velocidad * 0.55)


func _nuevo_destino_patrulla() -> void:
	var ang := randf() * TAU
	var r := randf() * radio_patrulla
	destino = sitio + Vector3(cos(ang) * r, 0.0, sin(ang) * r)


func _esquivar(dir: Vector3) -> Vector3:
	dir.y = 0.0
	if dir.length() < 0.1:
		return dir
	dir = dir.normalized()
	var origen := global_position + Vector3(0.0, 0.9, 0.0)
	if not _bloqueado(origen, dir):
		return dir
	var izquierda := dir.rotated(Vector3.UP, PI * 0.45)
	if not _bloqueado(origen, izquierda):
		return izquierda
	var derecha := dir.rotated(Vector3.UP, -PI * 0.45)
	if not _bloqueado(origen, derecha):
		return derecha
	return dir.rotated(Vector3.UP, PI * 0.9)


func _bloqueado(origen: Vector3, dir: Vector3) -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + dir.normalized() * 1.4)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	return not golpe.is_empty() and golpe["collider"] != jugador


func _mover(dir: Vector3, delta: float, vel: float) -> void:
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * vel, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * vel, 12.0 * delta)


func _frenar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)


func _distancia() -> float:
	return global_position.distance_to(jugador.global_position) if jugador != null else 9999.0


func _ve_al_jugador() -> bool:
	if jugador == null or jugador.get("muerto") == true:
		return false
	if _distancia() > rango_vision:
		return false
	if estado == "patrulla":
		var hacia := jugador.global_position - global_position
		hacia.y = 0.0
		var frente := Vector3(sin(modelo.rotation.y), 0.0, cos(modelo.rotation.y))
		if hacia.normalized().dot(frente) < cos(deg_to_rad(angulo_vision * 0.5)):
			return false
	return _lo_veo()


func alertar(punto: Vector3, propagar := true) -> void:
	if muerto:
		return
	if estado == "patrulla":
		estado = "alerta"
		sin_ver = 0.0
		reaccion = randf_range(reaccion_min, reaccion_max)
		ultima_vista = punto + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5))
	if propagar:
		_avisar_companeros(punto)


func _avisar_companeros(punto: Vector3) -> void:
	for otro in get_tree().get_nodes_in_group("enemigo"):
		if otro == self or not is_instance_valid(otro):
			continue
		if otro.global_position.distance_to(global_position) <= radio_aviso and otro.has_method("alertar"):
			otro.alertar(punto, false)


func _mirar_a(punto: Vector3, delta: float) -> void:
	_mirar_hacia(punto - global_position, delta)


func _mirar_hacia(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.1:
		return
	modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(dir.x, dir.z), delta * 8.0)


func _animar_movimiento() -> void:
	if accion > 0.0:
		return
	if Vector2(velocity.x, velocity.z).length() > 0.35:
		_reproducir("caminar", 0.15)
	else:
		_reproducir("quieto", 0.2)


func _lo_veo() -> bool:
	var origen := global_position + Vector3(0.0, altura_ojos, 0.0)
	var mira := jugador.global_position + Vector3(0.0, 1.2, 0.0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, mira)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return true
	return golpe["collider"] == jugador


func _disparar() -> void:
	if jugador == null or jugador.get("muerto") == true:
		return
	espera = cadencia
	accion = 0.4
	_reproducir("disparar", 0.05, true)
	var luz := arma.get_node_or_null(^"Fogonazo")
	if luz != null:
		luz.visible = true
		get_tree().create_timer(0.06).timeout.connect(func(): luz.visible = false)
	if randf() > precision:
		return
	var origen := global_position + Vector3(0.0, altura_ojos, 0.0)
	var mira := jugador.global_position + Vector3(0.0, 1.2, 0.0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, mira)
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
	Efectos.particulas(sangre)
	var foco: Vector3 = atacante.global_position if atacante is Node3D else global_position
	alertar(foco, false)
	if vida <= 0:
		_morir(atacante)
		return
	if accion <= 0.0:
		accion = 0.4
		_reproducir("golpeado", 0.1, true)


func _morir(atacante: Node) -> void:
	muerto = true
	vida = 0
	accion = 3.0
	set_deferred("collision_layer", 0)
	_reproducir("morir", 0.2, true)
	var luz := arma.get_node_or_null(^"Fogonazo")
	if luz != null:
		luz.visible = false
	if suelta_llave and escena_llave != null:
		var raiz: Node = get_parent()
		if raiz == null:
			raiz = get_tree().current_scene
		var punto := global_position + Vector3(0.0, 0.4, 0.0)
		if raiz is Node3D:
			punto = (raiz as Node3D).to_local(punto)
		var llave: Node3D = escena_llave.instantiate()
		llave.position = punto
		raiz.add_child.call_deferred(llave)
	if atacante != null and atacante.has_method("avisar_baja"):
		atacante.avisar_baja()
	var foco: Vector3 = atacante.global_position if atacante is Node3D else global_position
	_avisar_companeros(foco)
	murio.emit(self)


func _reproducir(clave: String, mezcla: float, reiniciar := false) -> void:
	if not _pista.has(clave):
		return
	var nombre: String = _pista[clave]
	if not reiniciar and animacion_actual == nombre and anim.is_playing():
		return
	animacion_actual = nombre
	anim.play(nombre, mezcla)
	if reiniciar:
		anim.seek(0.0, true)
