extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# ── Configuración de combate (editable en el Inspector) ─────────────
@export_group("Vida")
@export var vida_maxima := 100

@export_group("Munición")
@export var cargador_maximo := 30     # balas por cargador
@export var reserva_maxima := 180     # tope de balas que puedes llevar
@export var reserva_inicial := 120

# ── Señales que consume el HUD ─────────────────────────────────────
signal vida_cambiada(actual: int, maxima: int)
signal municion_cambiada(cargador: int, reserva: int)
signal jugador_murio
signal enemigo_abatido

var vida: int
var cargador: int
var reserva: int


func _ready() -> void:
	# El HUD busca al jugador por este grupo si no le asignas el NodePath.
	add_to_group("jugador")
	vida = vida_maxima
	cargador = cargador_maximo
	reserva = reserva_inicial
	emitir_estado()


func emitir_estado() -> void:
	# El HUD llama a esto al arrancar para pintar los valores iniciales.
	vida_cambiada.emit(vida, vida_maxima)
	municion_cambiada.emit(cargador, reserva)


func _unhandled_input(evento: InputEvent) -> void:
	# Clic izquierdo = disparar, tecla R = recargar.
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		disparar()
	elif evento is InputEventKey and evento.pressed and not evento.echo \
			and (evento.keycode == KEY_R or evento.physical_keycode == KEY_R):
		recargar()


func disparar() -> void:
	if cargador <= 0:
		return
	cargador -= 1
	municion_cambiada.emit(cargador, reserva)
	# TODO: aquí va el raycast / instanciar la bala / animación de disparo.


func recargar() -> void:
	if cargador == cargador_maximo or reserva <= 0:
		return
	var faltan := cargador_maximo - cargador
	var mueve: int = min(faltan, reserva)
	cargador += mueve
	reserva -= mueve
	municion_cambiada.emit(cargador, reserva)


func recibir_dano(cantidad: int) -> void:
	if vida <= 0:
		return
	vida = clampi(vida - cantidad, 0, vida_maxima)
	vida_cambiada.emit(vida, vida_maxima)
	if vida == 0:
		jugador_murio.emit()


func curar(cantidad: int) -> void:
	vida = clampi(vida + cantidad, 0, vida_maxima)
	vida_cambiada.emit(vida, vida_maxima)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
