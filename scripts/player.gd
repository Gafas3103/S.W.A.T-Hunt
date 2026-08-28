extends CharacterBody3D
const SPEED = 3.0
const JUMP_VELOCITY = 4.5
@onready var anim = $character/AnimationPlayer

func _ready():
	if not anim.has_animation_library("walk"):
		anim.add_animation_library("walk", load("res://assets3d/walking.fbx"))

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
