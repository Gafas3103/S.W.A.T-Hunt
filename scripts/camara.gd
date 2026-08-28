extends SpringArm3D
@export var objetivo: Node3D          # el personaje al que sigue
@export var suavizado_posicion: float = 4.0   # más alto = cámara más pegada en posición
@export var suavizado_giro: float = 6.0       # más alto = gira más rápido hacia el personaje
@export var altura: float = 1.4       # apunta a la cabeza, no a los pies
@export var sensibilidad: float = 0.004       # solo para el pitch (subir/bajar) con mouse, opcional
func _ready() -> void:
	if objetivo == null:
		objetivo = get_parent() as Node3D
	top_level = true
	if objetivo is CollisionObject3D:
		add_excluded_object(objetivo.get_rid())
	# Ya no capturamos el mouse para rotar la cámara horizontalmente.
	# Si quieres controlar solo la inclinación (arriba/abajo) con el mouse,
	# puedes dejar mouse capturado; si no quieres mouse para nada, comenta esto.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Si quieres mantener control de inclinación (mirar arriba/abajo) con el
	# mouse, descomenta este bloque. Si no lo necesitas, bórralo.
	# if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
	# 	rotation.x += evento.relative.y * sensibilidad
	# 	rotation.x = clamp(rotation.x, deg_to_rad(-55.0), deg_to_rad(25.0))
func _physics_process(delta: float) -> void:
	if objetivo == null:
		return
	# Posición: igual que antes, sigue suavemente al personaje.
	var destino: Vector3 = objetivo.global_position + Vector3(0.0, altura, 0.0)
	global_position = global_position.lerp(destino, delta * suavizado_posicion)
	# Rotación horizontal: en vez de moverla con el mouse, la hacemos girar
	# suavemente hasta que coincida con hacia dónde mira el personaje
	# (objetivo.rotation.y), que es lo que tu script del jugador ya actualiza
	# cuando camina (Basis.looking_at). El +PI compensa que el jugador usa
	# Basis.looking_at(-direction), lo que deja su rotation.y "invertida"
	# respecto a hacia dónde mira visualmente el modelo.
	rotation.y = lerp_angle(rotation.y, objetivo.rotation.y + PI, delta * suavizado_giro)
