extends SpringArm3D
@export var objetivo: Node3D          # el personaje al que sigue
@export var sensibilidad: float = 0.004
@export var suavizado: float = 0.0   # más alto = cámara más pegada
@export var altura: float = 1.4       # apunta a la cabeza, no a los pies
func _ready() -> void:
	if objetivo == null:
		objetivo = get_parent() as Node3D
	# top_level hace que este nodo IGNORE la posición y rotación de su padre.
	# Sin esto, como el personaje gira hacia donde camina, la cámara giraría
	# con él y la pantalla daría vueltas sola.
	top_level = true
	# El brazo nace DENTRO del cuerpo del personaje, así que lo primero contra
	# lo que choca es el personaje mismo: sin esta línea el brazo se encoge a
	# cero y la cámara se queda pegada a la nuca.
	if objetivo is CollisionObject3D:
		add_excluded_object(objetivo.get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"):     # ESC libera el mouse
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if evento is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# relative = cuántos píxeles se movió el mouse DESDE EL FRAME ANTERIOR
		rotation.y -= evento.relative.x * sensibilidad
		# OJO CON EL SIGNO: el brazo lleva la cámara sobre su +Z local, así
		# que rotation.x NEGATIVO la sube y POSITIVO la baja hasta el suelo.
		# Se RESTA relative.y —que el mouse da positivo hacia abajo— para que
		# empujar el mouse hacia arriba baje la cámara y se mire al cielo.
		rotation.x -= evento.relative.y * sensibilidad
		# clamp encierra un valor entre un mínimo y un máximo: sin esto la
		# cámara se voltea boca abajo, o se hunde bajo el piso.
		# -55 = bien arriba mirando abajo ... +25 = un poco por debajo.
		rotation.x = clamp(rotation.x, deg_to_rad(-55.0), deg_to_rad(25.0))
func _physics_process(delta: float) -> void:
	if objetivo == null:
		return
	var destino: Vector3 = objetivo.global_position + Vector3(0.0, altura, 0.0)
	# lerp = interpolación lineal: en vez de saltar de golpe al destino, avanza
	# una fracción del camino cada frame. Eso es lo que la hace sentir suave.
	global_position = global_position.lerp(destino, delta * suavizado)
