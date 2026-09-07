extends CharacterBody3D

signal murio(enemigo: Node)

const ANIMACIONES := {
	"quieto": "res://assets3d/rifle aiming idle.fbx",
	"caminar": "res://assets3d/walking.fbx",
	"disparar": "res://assets3d/firing rifle.fbx",
	"golpeado": "res://assets3d/hit reaction.fbx",
	"morir": "res://assets3d/walking to dying.fbx"
}
const CICLICAS := ["quieto", "caminar"]

@export var vida_maxima := 100
@export var dano := 8
@export var cadencia := 0.95
@export var rango_vision := 17.0
@export var angulo_vision := 220.0        ## cono de visión en grados: tiene un punto ciego a la espalda
@export var precision := 0.38
@export var altura_ojos := 1.55
@export var velocidad := 2.4              ## lo rápido que camina
@export var distancia_combate := 8.0      ## a esta distancia se planta a disparar
@export var memoria := 2.5                ## segundos que te sigue buscando tras perderte
@export var reaccion_min := 0.5           ## lo que tarda en espabilar tras oír algo
@export var reaccion_max := 1.4
@export var radio_patrulla := 4.0         ## cuánto se aleja de su sitio al vigilar
@export var radio_aviso := 9.0            ## a qué distancia avisa a un compañero al caer
@export var suelta_llave := false
@export var escena_llave: PackedScene

@onready var modelo: Node3D = $character
@onready var esqueleto: Skeleton3D = $character/Skeleton3D
@onready var anim: AnimationPlayer = $character/AnimationPlayer
@onready var arma: Node3D = $Arma
@onready var colision: CollisionShape3D = $Colision
@onready var navegante: NavigationAgent3D = $Navegante

var vida := 0
var jugador: Node3D = null
var espera := 0.0
var accion := 0.0
var muerto := false
var animacion_actual := ""
var _pista := {}

# IA sencilla con 3 estados. Se mueve por el navmesh del nivel: rodea esquinas
# y persigue por los pasillos en vez de chocar contra las paredes.
var estado := "patrulla"                 # patrulla | alerta | combate
var sitio := Vector3.ZERO                # dónde empezó (centro de su patrulla)
var destino := Vector3.ZERO              # a dónde camina ahora mismo
var _destino_objetivo := Vector3.ZERO    # punto al que se dirige vía la navegación
var _retarget := 0.0                     # evita re-pedir ruta cada frame
var ultima_vista := Vector3.ZERO         # última posición conocida del jugador
var sin_ver := 0.0
var descanso := 0.0
var reaccion := 0.0                      # mientras sea mayor que 0 aún está espabilando (no dispara)


func _ready() -> void:
	add_to_group("enemigo")
	vida = vida_maxima
	_preparar_animaciones()
	_montar_arma()
	_pintar()
	_pintar_arma()
	espera = randf_range(0.3, 1.2)
	jugador = get_tree().get_first_node_in_group("jugador") as Node3D
	sitio = global_position
	destino = global_position
	navegante.avoidance_enabled = false
	navegante.radius = 0.5
	navegante.path_desired_distance = 0.6
	navegante.target_desired_distance = 0.7


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
		if pista != null:
			for i in range(pista.get_track_count() - 1, -1, -1):
				if pista.track_get_type(i) != Animation.TYPE_POSITION_3D:
					continue
				var ruta := String(pista.track_get_path(i))
				if not (ruta.ends_with(":mixamorig_Hips") or ruta.ends_with(":Hips")):
					continue
				if clave == "morir":
					_conservar_desplome(pista, i)
				else:
					pista.remove_track(i)
	for clave in CICLICAS:
		if _pista.has(clave):
			var a := anim.get_animation(_pista[clave])
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
	_reproducir("quieto", 0.1)


## El clip de morir necesita desplomar la cadera hasta el suelo; si lo quitamos
## entero, el cuerpo queda "flotando". Le dejamos solo el eje Y (el descenso),
## anulando el avance x/z para que el cadáver no patine.
func _conservar_desplome(a: Animation, track: int) -> void:
	for k in range(a.track_get_key_count(track)):
		var v: Vector3 = a.track_get_key_value(track, k)
		a.track_set_key_value(track, k, Vector3(0.0, v.y, 0.0))


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
	if muerto:
		# ya no colisiona con el suelo (le quitamos la colisión al morir), así que
		# si aplicamos gravedad el cuerpo se hunde. Lo dejamos clavado donde cayó.
		_frenar(delta)
		velocity.y = 0.0
		move_and_slide()
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if accion > 0.0:
		accion -= delta
	if espera > 0.0:
		espera -= delta
	if _retarget > 0.0:
		_retarget -= delta
	if reaccion > 0.0:
		reaccion -= delta
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("jugador") as Node3D

	# ¿decidimos el estado?
	if _ve_al_jugador():
		ultima_vista = jugador.global_position
		sin_ver = 0.0
		reaccion = minf(reaccion, 0.15)   # si te ve, deja de dudar casi al instante
		estado = "combate" if _distancia() <= distancia_combate else "alerta"
	elif estado != "patrulla":
		sin_ver += delta
		if sin_ver >= memoria:
			estado = "patrulla"
			_nuevo_destino_patrulla()

	# todavía espabilando: se queda quieto mirando hacia el ruido
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
	var d := _distancia()
	if d < distancia_combate * 0.5:
		# le pisa los talones: se retira sin dejar de apuntarle
		var huida := global_position + (global_position - jugador.global_position)
		huida.y = global_position.y
		_destino_objetivo = huida
		_avanzar(delta, velocidad * 0.7)
	elif d > distancia_combate * 0.9:
		# el jugador se aleja: lo persigue sin dejar de vigilarlo
		_destino_objetivo = ultima_vista
		_avanzar(delta, velocidad)
	else:
		_frenar(delta)
	if espera <= 0.0 and accion <= 0.0:
		_disparar()


func _hacer_alerta(delta: float) -> void:
	# Si el último punto visto no cae sobre el navmesh, la ruta es vacía y el
	# enemigo se queda plantado mirando: lo clavamos al punto navegable más
	# cercano.
	_destino_objetivo = NavigationServer3D.map_get_closest_point(navegante.get_navigation_map(), ultima_vista)
	_mirar_a(ultima_vista, delta)
	if navegante.is_navigation_finished():
		_frenar(delta)      # llegó a donde lo vio por última vez y mira alrededor
		return
	_avanzar(delta, velocidad)


func _hacer_patrulla(delta: float) -> void:
	descanso -= delta
	var plano := destino - global_position
	plano.y = 0.0
	if plano.length() < 0.6 or navegante.is_navigation_finished():
		_frenar(delta)
		if descanso <= 0.0:
			_nuevo_destino_patrulla()
			descanso = randf_range(1.5, 4.0)
		return
	_avanzar(delta, velocidad * 0.55, true)


func _nuevo_destino_patrulla() -> void:
	var ang := randf() * TAU
	var r := randf() * radio_patrulla
	destino = sitio + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	_destino_objetivo = destino
	navegante.target_position = destino


func _mover(dir: Vector3, delta: float, vel: float) -> void:
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * vel, 12.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * vel, 12.0 * delta)


func _frenar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)


## Avanza hacia _destino_objetivo siguiendo la ruta del NavigationAgent3D.
## 'girar' hace que el modelo mire hacia donde camina (úsalo en patrulla; en
## combate/alerta la mirada la controla _mirar_a).
func _avanzar(delta: float, vel: float, girar := false) -> void:
	if _retarget <= 0.0 and navegante.target_position.distance_to(_destino_objetivo) > 0.3:
		navegante.target_position = _destino_objetivo
		_retarget = 0.35
	if navegante.is_navigation_finished():
		_frenar(delta)
		return
	var siguiente := navegante.get_next_path_position()
	var dir := siguiente - global_position
	dir.y = 0.0
	if girar and dir.length() > 0.1:
		_mirar_hacia(dir, delta)
	_mover(dir, delta, vel)


func _distancia() -> float:
	return global_position.distance_to(jugador.global_position) if jugador != null else 9999.0


func _ve_al_jugador() -> bool:
	if jugador == null or jugador.get("muerto") == true:
		return false
	if _distancia() > rango_vision:
		return false
	# mientras patrulla no ve lo que tiene justo detrás; ya alertado, te sigue
	# aunque te muevas a su espalda.
	if estado == "patrulla":
		var hacia := jugador.global_position - global_position
		hacia.y = 0.0
		var frente := Vector3(sin(modelo.rotation.y), 0.0, cos(modelo.rotation.y))
		if hacia.normalized().dot(frente) < cos(deg_to_rad(angulo_vision * 0.5)):
			return false
	return _lo_veo()


## Lo llama un compañero al caer, o el jugador al disparar cerca. El enemigo
## no sabe exactamente dónde estás: investiga una zona aproximada.
func alertar(punto: Vector3, propagar := true) -> void:
	if muerto:
		return
	# solo reacciona si estaba tranquilo; si ya andaba buscando, ni caso
	# (así no es imposible perderlo).
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
	modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(dir.x, dir.z), delta * 12.0)


func _animar_movimiento() -> void:
	if accion > 0.0:
		return
	if Vector2(velocity.x, velocity.z).length() > 0.35:
		_reproducir("caminar", 0.15)
	else:
		_reproducir("quieto", 0.2)


func _lo_veo() -> bool:
	var origen := global_position + Vector3(0.0, altura_ojos, 0.0)
	var destino := jugador.global_position + Vector3(0.0, 1.2, 0.0)
	var consulta := PhysicsRayQueryParameters3D.create(origen, destino)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if golpe.is_empty():
		return true
	return golpe["collider"] == jugador


func _disparar() -> void:
	if jugador == null:
		return
	if jugador.get("muerto") == true:
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
	var foco: Vector3 = atacante.global_position if atacante is Node3D else global_position
	alertar(foco, false)   # reacciona él, pero no llama a toda la casa
	if vida <= 0:
		_morir(atacante)
		return
	if accion <= 0.0:
		accion = 0.4
		_reproducir("golpeado", 0.1, true)


func _morir(atacante: Node) -> void:
	muerto = true
	vida = 0
	colision.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)
	_reproducir("morir", 0.2, true)
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
	# un compañero cayendo pone en alerta a los de al lado
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
