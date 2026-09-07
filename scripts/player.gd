extends CharacterBody3D

signal vida_cambiada(actual: int, maxima: int)
signal municion_cambiada(cargador: int, reserva: int)
signal arma_cambiada(nombre: String, indice: int)
signal apuntando_cambiado(activo: bool)
signal llave_cambiada(tiene: bool)
signal aviso_cambiado(texto: String)
signal nota_abierta(titulo: String, texto: String)
signal nota_cerrada
signal jugador_murio
signal enemigo_abatido
signal impacto(en_enemigo: bool)
signal agachado_cambiado(activo: bool)

const ANIMACIONES := {
	"quieto": "res://assets3d/rifle aiming idle.fbx",
	"caminar": "res://assets3d/walking.fbx",
	"correr": "res://assets3d/rifle run.fbx",
	"atras": "res://assets3d/walking backwards.fbx",
	"izquierda": "res://assets3d/strafe left.fbx",
	"derecha": "res://assets3d/strafe right.fbx",
	"pistola": "res://assets3d/Pistol Walk.fbx",
	"disparar": "res://assets3d/firing rifle.fbx",
	"recargar": "res://assets3d/reloading.fbx",
	"cuchillada": "res://assets3d/toss grenade.fbx",
	"saltar": "res://assets3d/rifle jump.fbx",
	"golpeado": "res://assets3d/hit reaction.fbx",
	"morir": "res://assets3d/walking to dying.fbx"
}

const CICLICAS := ["quieto", "caminar", "correr", "atras", "izquierda", "derecha", "pistola"]

@export var vida_maxima := 100
@export var velocidad_caminar := 3.2
@export var velocidad_correr := 5.8
@export var velocidad_apuntando := 1.9
@export var velocidad_agachado := 1.5
@export var fuerza_salto := 4.5
@export var altura_de_pie := 1.8
@export var altura_agachado := 1.05
@export var camara_de_pie := 1.5
@export var camara_agachado := 0.95

@export_group("Agacharse (dobla el esqueleto, no hay animación)")
@export var crouch_cadera := 0.14
@export var crouch_inclina := 14.0
@export var crouch_muslo := 0.0
@export var crouch_rodilla := 0.0
@export var crouch_tobillo := 0.0
@export var crouch_espalda := 0.0

@export_group("Cámara y puntería")
@export var sensibilidad := 0.0022
@export var angulo_minimo := -60.0
@export var angulo_maximo := 35.0
@export var campo_normal := 75.0
@export var brazo_normal := 2.6
@export var brazo_apuntando := 1.3
@export var hombro_normal := 0.6
@export var hombro_apuntando := 0.45

@onready var modelo: Node3D = $character
@onready var esqueleto: Skeleton3D = $character/Skeleton3D
@onready var anim: AnimationPlayer = $character/AnimationPlayer
@onready var pivote: Node3D = $Pivote
@onready var brazo: SpringArm3D = $Pivote/Brazo
@onready var camara: Camera3D = $Pivote/Brazo/Soporte/Camara
@onready var armas: Node3D = $Armas
@onready var colision: CollisionShape3D = $Colision

var vida := 0
var apuntando := false
var agachado := false
var muerto := false
var tiene_llave := false
var leyendo := false
var accion := 0.0
var animacion_actual := ""
var giro_modelo := 0.0
var interactuable: Node = null
var texto_interaccion := ""

var _pista := {}
var _capsula: CapsuleShape3D = null
var disparo_timer := 0.0

var _crouch := 0.0
var _h_muslo_i := -1
var _h_muslo_d := -1
var _h_rodilla_i := -1
var _h_rodilla_d := -1
var _h_tobillo_i := -1
var _h_tobillo_d := -1
var _h_espalda := -1
var _h_cadera := -1
var _cadera_base := Vector3.ZERO
var _rest := {}


func _ready() -> void:
	add_to_group("jugador")
	vida = vida_maxima
	if colision.shape is CapsuleShape3D:
		colision.shape = colision.shape.duplicate()
		_capsula = colision.shape
		altura_de_pie = _capsula.height
	_preparar_animaciones()
	_montar_armas()
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_h_muslo_i = esqueleto.find_bone("mixamorig_LeftUpLeg")
	_h_muslo_d = esqueleto.find_bone("mixamorig_RightUpLeg")
	_h_rodilla_i = esqueleto.find_bone("mixamorig_LeftLeg")
	_h_rodilla_d = esqueleto.find_bone("mixamorig_RightLeg")
	_h_tobillo_i = esqueleto.find_bone("mixamorig_LeftFoot")
	_h_tobillo_d = esqueleto.find_bone("mixamorig_RightFoot")
	_h_espalda = esqueleto.find_bone("mixamorig_Spine")
	_h_cadera = esqueleto.find_bone("mixamorig_Hips")
	for h in [_h_muslo_i, _h_muslo_d, _h_rodilla_i, _h_rodilla_d, _h_tobillo_i, _h_tobillo_d, _h_espalda]:
		if h != -1:
			_rest[h] = esqueleto.get_bone_pose_rotation(h)
	if _h_cadera != -1:
		_cadera_base = esqueleto.get_bone_pose_position(_h_cadera)
	brazo.add_excluded_object(get_rid())
	brazo.spring_length = brazo_normal
	camara.fov = campo_normal
	camara.position.x = hombro_normal
	giro_modelo = modelo.rotation.y
	armas.municion_cambiada.connect(_reenviar_municion)
	armas.arma_cambiada.connect(_reenviar_arma)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	emitir_estado()
	_colocar_en_suelo.call_deferred()


func _colocar_en_suelo() -> void:
	var desde := global_position + Vector3.UP * 2.0
	var consulta := PhysicsRayQueryParameters3D.create(desde, global_position - Vector3.UP * 12.0)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if not golpe.is_empty():
		global_position.y = golpe.position.y + 0.05


func _reenviar_municion(cargador: int, reserva: int) -> void:
	municion_cambiada.emit(cargador, reserva)


func _reenviar_arma(nombre: String, indice: int) -> void:
	arma_cambiada.emit(nombre, indice)


func _preparar_animaciones() -> void:
	for clave in ANIMACIONES:
		if not anim.has_animation_library(clave):
			var lib: Variant = load(ANIMACIONES[clave])
			if lib is AnimationLibrary:
				anim.add_animation_library(clave, lib)
		if not anim.has_animation_library(clave):
			push_warning("Jugador: no pude cargar la animación '%s' (%s)" % [clave, ANIMACIONES[clave]])
			continue
		var libreria := anim.get_animation_library(clave)
		var lista := libreria.get_animation_list()
		if lista.is_empty():
			continue
		var nombre := "%s/%s" % [clave, lista[0]]
		_pista[clave] = nombre
		var pista := anim.get_animation(nombre)
		if pista == null:
			continue
		_quitar_traslacion_raiz(pista) if clave != "morir" else _conservar_desplome(pista)
		if clave in CICLICAS:
			pista.loop_mode = Animation.LOOP_LINEAR


func _quitar_traslacion_raiz(a: Animation) -> void:
	for i in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(i) == Animation.TYPE_POSITION_3D:
			var ruta := String(a.track_get_path(i))
			if ruta.ends_with(":mixamorig_Hips") or ruta.ends_with(":Hips"):
				a.remove_track(i)


func _conservar_desplome(a: Animation) -> void:
	for i in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var ruta := String(a.track_get_path(i))
		if ruta.ends_with(":mixamorig_Hips") or ruta.ends_with(":Hips"):
			for k in range(a.track_get_key_count(i)):
				var v: Vector3 = a.track_get_key_value(i, k)
				a.track_set_key_value(i, k, Vector3(0.0, v.y, 0.0))


func _montar_armas() -> void:
	var union := BoneAttachment3D.new()
	union.name = "ManoDerecha"
	esqueleto.add_child(union)
	union.bone_name = "mixamorig_RightHand"
	armas.reparent(union, false)


func emitir_estado() -> void:
	vida_cambiada.emit(vida, vida_maxima)
	llave_cambiada.emit(tiene_llave)
	armas.avisar_municion()
	arma_cambiada.emit(armas.datos()["nombre"], armas.indice)


func fijar_interaccion(nodo: Node, texto: String) -> void:
	interactuable = nodo
	texto_interaccion = texto
	aviso_cambiado.emit(texto)


func quitar_interaccion(nodo: Node) -> void:
	if interactuable != nodo:
		return
	interactuable = null
	texto_interaccion = ""
	aviso_cambiado.emit("")


func mostrar_aviso(texto: String, segundos: float = 2.0) -> void:
	aviso_cambiado.emit(texto)
	if segundos <= 0.0:
		return
	await get_tree().create_timer(segundos).timeout
	aviso_cambiado.emit(texto_interaccion)


func recoger_llave() -> void:
	tiene_llave = true
	llave_cambiada.emit(true)


func abrir_nota(titulo: String, texto: String) -> void:
	leyendo = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	nota_abierta.emit(titulo, texto)


func cerrar_nota() -> void:
	leyendo = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	nota_cerrada.emit()


func recibir_dano(cantidad: int) -> void:
	if muerto:
		return
	vida = clampi(vida - cantidad, 0, vida_maxima)
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		muerto = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_anim_play("morir", 0.2, true)
		accion = 5.0
		jugador_murio.emit()
	elif accion <= 0.0:
		_anim_play("golpeado", 0.1, true)
		accion = 0.45


func curar(cantidad: int) -> void:
	vida = clampi(vida + cantidad, 0, vida_maxima)
	vida_cambiada.emit(vida, vida_maxima)


func avisar_baja() -> void:
	enemigo_abatido.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausa"):
		if leyendo:
			cerrar_nota()
		return
	if leyendo:
		if evento.is_action_pressed("interactuar"):
			cerrar_nota()
		return
	if muerto:
		return
	if evento is InputEventMouseButton and evento.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivote.rotation.y -= evento.relative.x * sensibilidad
		brazo.rotation.x = clampf(brazo.rotation.x - evento.relative.y * sensibilidad, deg_to_rad(angulo_minimo), deg_to_rad(angulo_maximo))
	if evento.is_action_pressed("interactuar") and interactuable != null and interactuable.has_method("interactuar"):
		interactuable.interactuar(self)
	if evento.is_action_pressed("recargar"):
		_recargar()
	if evento.is_action_pressed("arma_1"):
		armas.cambiar(0)
	if evento.is_action_pressed("arma_2"):
		armas.cambiar(1)
	if evento.is_action_pressed("arma_3"):
		armas.cambiar(2)
	if evento.is_action_pressed("arma_siguiente"):
		armas.siguiente()
	if evento.is_action_pressed("arma_anterior"):
		armas.anterior()


func _physics_process(delta: float) -> void:
	if accion > 0.0:
		accion -= delta
	if disparo_timer > 0.0:
		disparo_timer -= delta
	if not is_on_floor():
		velocity += get_gravity() * delta
	if muerto or leyendo:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
		move_and_slide()
		return
	_actualizar_apuntado(delta)
	_actualizar_agachado(delta)
	var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direccion := pivote.global_basis * Vector3(entrada.x, 0.0, entrada.y)
	direccion.y = 0.0
	direccion = direccion.normalized()
	var corriendo := Input.is_action_pressed("correr") and not apuntando and not agachado and entrada.y < -0.1
	var velocidad_objetivo := velocidad_caminar
	if agachado:
		velocidad_objetivo = velocidad_agachado
	elif apuntando:
		velocidad_objetivo = velocidad_apuntando
	elif corriendo:
		velocidad_objetivo = velocidad_correr
	if direccion.length() > 0.1:
		velocity.x = move_toward(velocity.x, direccion.x * velocidad_objetivo, 30.0 * delta)
		velocity.z = move_toward(velocity.z, direccion.z * velocidad_objetivo, 30.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor() and not agachado:
		velocity.y = fuerza_salto
	_girar_modelo(direccion, delta)
	if Input.is_action_pressed("disparar"):
		if armas.datos()["automatica"] or Input.is_action_just_pressed("disparar"):
			_disparar()
	move_and_slide()
	_elegir_animacion(entrada, corriendo)


func _actualizar_apuntado(delta: float) -> void:
	var quiere := Input.is_action_pressed("apuntar")
	if quiere != apuntando:
		apuntando = quiere
		apuntando_cambiado.emit(apuntando)
	var largo := brazo_apuntando if apuntando else brazo_normal
	var hombro := hombro_apuntando if apuntando else hombro_normal
	var campo: float = armas.datos()["zoom"] if apuntando else campo_normal
	brazo.spring_length = lerpf(brazo.spring_length, largo, delta * 12.0)
	camara.position.x = lerpf(camara.position.x, hombro, delta * 12.0)
	camara.fov = lerpf(camara.fov, campo, delta * 12.0)


func _actualizar_agachado(delta: float) -> void:
	var quiere := Input.is_action_pressed("agacharse") and is_on_floor()
	if not quiere and agachado and _hay_techo():
		quiere = true
	if quiere != agachado:
		agachado = quiere
		agachado_cambiado.emit(agachado)
	if _capsula != null:
		var alto: float = altura_agachado if agachado else altura_de_pie
		_capsula.height = lerpf(_capsula.height, alto, delta * 12.0)
		colision.position.y = _capsula.height * 0.5
	var alto_cam: float = camara_agachado if agachado else camara_de_pie
	pivote.position.y = lerpf(pivote.position.y, alto_cam, delta * 12.0)
	_crouch = lerpf(_crouch, 1.0 if agachado else 0.0, delta * 12.0)


func _process(_delta: float) -> void:
	modelo.rotation.x = deg_to_rad(crouch_inclina) * _crouch
	if _crouch <= 0.002:
		return
	_doblar(_h_muslo_i, deg_to_rad(crouch_muslo))
	_doblar(_h_muslo_d, deg_to_rad(crouch_muslo))
	_doblar(_h_rodilla_i, deg_to_rad(-crouch_rodilla))
	_doblar(_h_rodilla_d, deg_to_rad(-crouch_rodilla))
	_doblar(_h_tobillo_i, deg_to_rad(crouch_tobillo))
	_doblar(_h_tobillo_d, deg_to_rad(crouch_tobillo))
	_doblar(_h_espalda, deg_to_rad(crouch_espalda))
	if _h_cadera != -1:
		esqueleto.set_bone_pose_position(_h_cadera, _cadera_base - Vector3(0.0, crouch_cadera * _crouch, 0.0))


func _doblar(hueso: int, angulo: float) -> void:
	if hueso == -1 or not _rest.has(hueso) or absf(angulo) < 0.001:
		return
	var base: Quaternion = _rest[hueso]
	var objetivo := base * Quaternion(Vector3(1, 0, 0), angulo)
	esqueleto.set_bone_pose_rotation(hueso, base.slerp(objetivo, _crouch))


func _hay_techo() -> bool:
	var desde := global_position + Vector3(0.0, 0.3, 0.0)
	var hasta := global_position + Vector3(0.0, altura_de_pie + 0.1, 0.0)
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta)
	consulta.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func _girar_modelo(direccion: Vector3, delta: float) -> void:
	var objetivo := giro_modelo
	if apuntando:
		objetivo = pivote.rotation.y + PI
	elif direccion.length() > 0.1:
		objetivo = atan2(direccion.x, direccion.z)
	giro_modelo = lerp_angle(giro_modelo, objetivo, delta * 12.0)
	modelo.rotation.y = giro_modelo


func _elegir_animacion(entrada: Vector2, corriendo: bool) -> void:
	if accion > 0.0:
		return
	if disparo_timer > 0.0 and is_on_floor():
		return
	var plana := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		_anim_play("saltar", 0.15)
	elif plana < 0.4:
		_anim_play("quieto", 0.2)
	elif agachado:
		_anim_play("caminar", 0.15)
	elif corriendo:
		_anim_play("correr", 0.15)
	elif apuntando and entrada.y > 0.1:
		_anim_play("atras", 0.15)
	elif apuntando and entrada.x < -0.1:
		_anim_play("izquierda", 0.15)
	elif apuntando and entrada.x > 0.1:
		_anim_play("derecha", 0.15)
	elif armas.indice == 1:
		_anim_play("pistola", 0.15)
	else:
		_anim_play("caminar", 0.15)


func _anim_play(clave: String, mezcla: float, reiniciar := false, velocidad := 1.0) -> void:
	if not _pista.has(clave):
		return
	var nombre: String = _pista[clave]
	if not reiniciar and animacion_actual == nombre and anim.is_playing():
		return
	animacion_actual = nombre
	anim.play(nombre, mezcla, velocidad)
	if reiniciar:
		anim.seek(0.0, true)


func _duracion_clip(clave: String) -> float:
	if _pista.has(clave):
		var clip := anim.get_animation(_pista[clave])
		if clip != null:
			return clip.length
	return 0.0


func _recargar() -> void:
	if accion > 0.0:
		return
	if armas.recargar():
		var dur := 1.8
		var largo := _duracion_clip("recargar")
		_anim_play("recargar", 0.15, true, largo / dur if largo > 0.2 else 1.0)
		accion = dur
		armas.espera = maxf(armas.espera, dur)


func _disparar() -> void:
	if accion > 0.0:
		return
	if armas.sin_balas():
		_recargar()
		return
	if not armas.puede_disparar():
		return
	armas.gastar()
	var info: Dictionary = armas.datos()
	if info["cuerpo_a_cuerpo"]:
		var dur := 0.8
		var largo := _duracion_clip("cuchillada")
		_anim_play("cuchillada", 0.1, true, largo / dur if largo > 0.2 else 1.0)
		accion = dur
		_golpe_cuerpo(info)
		_alertar_enemigos()
		return
	_anim_play("disparar", 0.05, true)
	disparo_timer = 0.22
	_disparo_lejano(info)
	_alertar_enemigos()


func _alertar_enemigos() -> void:
	for e in get_tree().get_nodes_in_group("enemigo"):
		if is_instance_valid(e) and e.has_method("alertar") \
				and e.global_position.distance_to(global_position) <= 11.0:
			e.alertar(global_position, false)


func _disparo_lejano(info: Dictionary) -> void:
	var base := camara.global_transform
	var extra: float = info["dispersion"]
	if apuntando:
		extra *= 0.3
	var direccion := -base.basis.z
	direccion += base.basis.x * randf_range(-extra, extra)
	direccion += base.basis.y * randf_range(-extra, extra)
	direccion = direccion.normalized()
	var origen := base.origin
	var destino := origen + direccion * float(info["alcance"])
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return
	_marcar_impacto(golpe["position"])
	_aplicar_dano(golpe["collider"], int(info["dano"]))


func _golpe_cuerpo(info: Dictionary) -> void:
	var origen := global_position + Vector3(0.0, 1.2, 0.0)
	var direccion := -camara.global_transform.basis.z
	direccion.y = 0.0
	direccion = direccion.normalized()
	var consulta := PhysicsRayQueryParameters3D.create(origen, origen + direccion * float(info["alcance"]))
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return
	_marcar_impacto(golpe["position"])
	_aplicar_dano(golpe["collider"], int(info["dano"]))


func _aplicar_dano(cuerpo: Object, cantidad: int) -> void:
	var nodo := cuerpo as Node
	if nodo == null:
		return
	if nodo.is_in_group("enemigo") and nodo.has_method("recibir_dano"):
		nodo.recibir_dano(cantidad, self)
		impacto.emit(true)
	else:
		impacto.emit(false)


func _marcar_impacto(punto: Vector3) -> void:
	var chispa := OmniLight3D.new()
	chispa.light_color = Color(1.0, 0.78, 0.4)
	chispa.light_energy = 4.0
	chispa.omni_range = 1.8
	add_sibling(chispa)
	chispa.global_position = punto
	get_tree().create_timer(0.07).timeout.connect(chispa.queue_free)
