extends CharacterBody3D

enum Estado { PATRULLAR, PERSEGUIR, ATACAR, HUIR }

@export var velocidad: float = 3.0
@export var aceleracion: float = 10.0      # igual que el jugador en la Sesión 9
@export var rango_vision: float = 8.0
@export var rango_ataque: float = 1.5
@export var vida: float = 100.0
@export var vida_huida: float = 30.0
@export var altura_ojos: float = 0.9

# La ruta se guarda como DESPLAZAMIENTOS desde donde se colocó al enemigo, no
# como posiciones absolutas: así cada copia patrulla su propia zona sin tener
# que configurarle nada.
@export var ruta: Array[Vector3] = [Vector3(0, 0, 0), Vector3(8, 0, 0)]

var estado_actual: Estado = Estado.PATRULLAR
var indice_punto: int = 0        # un ÍNDICE del array: la idea de toda la sesión
var jugador: Node3D = null
var puntos: Array[Vector3] = []
@onready var vision: RayCast3D = $Vision
func _ready() -> void:
	jugador = get_tree().get_first_node_in_group("player")
	for desplazamiento in ruta:
		puntos.append(global_position + desplazamiento)
		
func _decidir_estado(distancia: float, lo_veo: bool) -> Estado:
	if vida <= vida_huida and distancia <= rango_vision:
		return Estado.HUIR
	if distancia <= rango_ataque and lo_veo:
		return Estado.ATACAR
	if distancia <= rango_vision and lo_veo:
		return Estado.PERSEGUIR
	return Estado.PATRULLAR
	
func _tiene_linea_vision() -> bool:
	if jugador == null:
		return false
	# Se apunta al PECHO del jugador, no a su origen: el origen está en los
	# pies, a ras del suelo, y el rayo terminaría rozando el piso.
	var objetivo: Vector3 = jugador.global_position + Vector3(0, altura_ojos, 0)
	# target_position se mide en coordenadas LOCALES al rayo, no globales.
	vision.target_position = vision.to_local(objetivo)
	vision.force_raycast_update()
	if vision.is_colliding():
		# Chocó contra algo: solo hay visión si ese algo ES el jugador y no
		# una pared que se atravesó en el camino.
		return vision.get_collider() == jugador
	return true
	
func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta
	# 1. Medir el mundo
	var distancia := INF
	if jugador != null:
		distancia = _distancia_plana(global_position, jugador.global_position)
	var lo_veo := _tiene_linea_vision()
	# 2. Decidir
	var nuevo := _decidir_estado(distancia, lo_veo)
	if nuevo != estado_actual:
		estado_actual = nuevo
		# Solo en el CAMBIO, no cada frame: si no son 60 líneas por segundo
		# y la consola deja de servir para depurar.
		print("Enemigo -> ", Estado.keys()[estado_actual])
	# 3. Actuar
	match estado_actual:
		Estado.PATRULLAR: _patrullar(delta)
		Estado.PERSEGUIR: _moverse_hacia(jugador.global_position, 1.0, delta)
		Estado.ATACAR:    _frenar(delta)
		Estado.HUIR:      _moverse_lejos_de(jugador.global_position, delta)
	move_and_slide()
## Distancia ignorando la altura: si no, un jugador saltando "se aleja".
func _distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
	
func _patrullar(delta: float) -> void:
	if puntos.is_empty():
		_frenar(delta)
		return
	var destino: Vector3 = puntos[indice_punto]
	_moverse_hacia(destino, 1.0, delta)
	if _distancia_plana(global_position, destino) < 0.5:
		# El operador % (módulo) es el RESTO de la división. Con 4 puntos el
		# índice va 0,1,2,3,0,1,2,3... y nunca se sale del array: es la forma
		# corta de escribir "si me pasé del último, vuelvo al primero".
		indice_punto = (indice_punto + 1) % puntos.size()

func _moverse_hacia(destino: Vector3, factor: float, delta: float) -> void:
	var direccion := destino - global_position
	direccion.y = 0.0
	var objetivo := Vector3.ZERO
	if direccion.length() > 0.05:
		objetivo = direccion.normalized() * velocidad * factor
	# Mismo move_toward de la Sesión 9: el enemigo también acelera y frena.
	velocity.x = move_toward(velocity.x, objetivo.x, aceleracion * delta)
	velocity.z = move_toward(velocity.z, objetivo.z, aceleracion * delta)
	if objetivo.length() > 0.1:
		basis = basis.slerp(Basis.looking_at(objetivo), delta * 8.0).orthonormalized()

func _moverse_lejos_de(amenaza: Vector3, delta: float) -> void:
	# Huir es perseguir CON LA DIRECCIÓN AL REVÉS: en vez de (destino - yo),
	# se calcula (yo - amenaza). Nada más cambia, y por eso se reutiliza
	# _moverse_hacia en lugar de escribir una función casi idéntica.
	var direccion := global_position - amenaza
	direccion.y = 0.0
	_moverse_hacia(global_position + direccion, 1.3, delta)
	
func _frenar(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, aceleracion * delta)
	velocity.z = move_toward(velocity.z, 0.0, aceleracion * delta)
