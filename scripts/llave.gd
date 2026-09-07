extends Area3D

@export var altura_flotar := 0.12
@export var velocidad_giro := 1.6

@onready var modelo: Node3D = $Modelo

var tiempo := 0.0
var base_y := 0.0


func _ready() -> void:
	base_y = modelo.position.y
	var candado := modelo.get_node_or_null(^"Padlock")
	if candado != null:
		candado.visible = false
	body_entered.connect(_al_entrar)
	_colocar_en_suelo.call_deferred()


func _colocar_en_suelo() -> void:
	# La llave es un Area3D (no le afecta la gravedad): si se suelta desde una
	# altura, quedaría flotando. La anclamos al suelo con un raycast.
	var desde := global_position + Vector3.UP
	var consulta := PhysicsRayQueryParameters3D.create(desde, global_position - Vector3.UP * 8.0)
	consulta.exclude = [get_rid()]
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	if not golpe.is_empty():
		global_position.y = golpe.position.y + 0.05


func _process(delta: float) -> void:
	tiempo += delta
	modelo.rotate_y(delta * velocidad_giro)
	modelo.position.y = base_y + sin(tiempo * 2.0) * altura_flotar


func _al_entrar(cuerpo: Node3D) -> void:
	if not cuerpo.is_in_group("jugador"):
		return
	if cuerpo.has_method("recoger_llave"):
		cuerpo.recoger_llave()
	if cuerpo.has_method("mostrar_aviso"):
		cuerpo.mostrar_aviso("Llave conseguida")
	queue_free()
