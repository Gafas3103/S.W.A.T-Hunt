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
@export var fuerza_salto := 4.5
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

var vida := 0
var apuntando := false
var muerto := false
var tiene_llave := false
var leyendo := false
var accion := 0.0
var animacion_actual := ""
var giro_modelo := 0.0
var interactuable: Node = null
var texto_interaccion := ""


func _ready() -> void:
	add_to_group("jugador")
	vida = vida_maxima
	_preparar_animaciones()
	_montar_armas()
	brazo.add_excluded_object(get_rid())
	brazo.spring_length = brazo_normal
	camara.fov = campo_normal
	camara.position.x = hombro_normal
	giro_modelo = modelo.rotation.y
	armas.municion_cambiada.connect(_reenviar_municion)
	armas.arma_cambiada.connect(_reenviar_arma)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	emitir_estado()


func _reenviar_municion(cargador: int, reserva: int) -> void:
	municion_cambiada.emit(cargador, reserva)


func _reenviar_arma(nombre: String, indice: int) -> void:
	arma_cambiada.emit(nombre, indice)


func _preparar_animaciones() -> void:
	for clave in ANIMACIONES:
		if not anim.has_animation_library(clave):
			anim.add_animation_library(clave, load(ANIMACIONES[clave]))
	for clave in CICLICAS:
		var pista: Animation = anim.get_animation(clave + "/mixamo_com")
		if pista != null:
			pista.loop_mode = Animation.LOOP_LINEAR


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
		_reproducir("morir", 0.2)
		accion = 5.0
		jugador_murio.emit()
	elif accion <= 0.0:
		_reproducir("golpeado", 0.1)
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
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	if not is_on_floor():
		velocity += get_gravity() * delta
	if muerto or leyendo:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
		move_and_slide()
		return
	_actualizar_apuntado(delta)
	var entrada := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direccion := pivote.global_basis * Vector3(entrada.x, 0.0, entrada.y)
	direccion.y = 0.0
	direccion = direccion.normalized()
	var corriendo := Input.is_action_pressed("correr") and not apuntando and entrada.y < -0.1
	var velocidad_objetivo := velocidad_caminar
	if apuntando:
		velocidad_objetivo = velocidad_apuntando
	elif corriendo:
		velocidad_objetivo = velocidad_correr
	if direccion.length() > 0.1:
		velocity.x = move_toward(velocity.x, direccion.x * velocidad_objetivo, 30.0 * delta)
		velocity.z = move_toward(velocity.z, direccion.z * velocidad_objetivo, 30.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
	if Input.is_action_just_pressed("jump") and is_on_floor():
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
	var plana := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor():
		_reproducir("saltar", 0.15)
	elif plana < 0.4:
		_reproducir("quieto", 0.2)
	elif corriendo:
		_reproducir("correr", 0.15)
	elif apuntando and entrada.y > 0.1:
		_reproducir("atras", 0.15)
	elif apuntando and entrada.x < -0.1:
		_reproducir("izquierda", 0.15)
	elif apuntando and entrada.x > 0.1:
		_reproducir("derecha", 0.15)
	elif armas.indice == 1:
		_reproducir("pistola", 0.15)
	else:
		_reproducir("caminar", 0.15)


func _reproducir(clave: String, mezcla: float) -> void:
	var nombre := clave + "/mixamo_com"
	if animacion_actual == nombre and anim.is_playing():
		return
	animacion_actual = nombre
	anim.play(nombre, mezcla)


func _recargar() -> void:
	if accion > 0.0:
		return
	if armas.recargar():
		animacion_actual = ""
		anim.play("recargar/mixamo_com", 0.15)
		accion = 1.2


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
		animacion_actual = ""
		anim.play("cuchillada/mixamo_com", 0.1)
		accion = 0.5
		_golpe_cuerpo(info)
		return
	animacion_actual = ""
	anim.play("disparar/mixamo_com", 0.05)
	anim.seek(0.0, true)
	_disparo_lejano(info)


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


func _marcar_impacto(punto: Vector3) -> void:
	var chispa := OmniLight3D.new()
	chispa.light_color = Color(1.0, 0.78, 0.4)
	chispa.light_energy = 4.0
	chispa.omni_range = 1.8
	add_sibling(chispa)
	chispa.global_position = punto
	get_tree().create_timer(0.07).timeout.connect(chispa.queue_free)
