extends CharacterBody3D
const SPEED = 3.0
const JUMP_VELOCITY = 4.5
@onready var anim = $character/AnimationPlayer

@export var vida_maxima := 100
@export var cargador_maximo := 30
@export var reserva_maxima := 180
@export var reserva_inicial := 120

signal vida_cambiada(actual: int, maxima: int)
signal municion_cambiada(cargador: int, reserva: int)
signal jugador_murio

var vida: int
var cargador: int
var reserva: int

func _ready():
	add_to_group("jugador")
	vida = vida_maxima
	cargador = cargador_maximo
	reserva = reserva_inicial
	emitir_estado()
	if not anim.has_animation_library("walk"):
		anim.add_animation_library("walk", load("res://assets3d/walking.fbx"))

func emitir_estado() -> void:
	vida_cambiada.emit(vida, vida_maxima)
	municion_cambiada.emit(cargador, reserva)

func disparar() -> void:
	if cargador <= 0:
		return
	cargador -= 1
	municion_cambiada.emit(cargador, reserva)

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

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		disparar()
	elif evento is InputEventKey and evento.pressed and not evento.echo and (evento.keycode == KEY_R or evento.physical_keycode == KEY_R):
		recargar()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Get the input direction and handle the movement/deceleration.
	var input_dir := Input.get_vector("move_right", "move_left", "move_down", "move_up")
	# Ya no usamos transform.basis (la orientación del propio personaje) para
	# calcular la dirección, porque eso era lo que generaba el ciclo: el
	# personaje giraba, eso cambiaba la dirección, la dirección lo hacía
	# girar de nuevo... Ahora la dirección es fija respecto al mundo.
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	if direction.length() > 0:
		basis = basis.slerp(Basis.looking_at(-direction), delta * 10.0)
		anim.play("walk/mixamo_com")
	move_and_slide()
