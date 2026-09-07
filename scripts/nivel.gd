extends Node3D

@export var nota_path: NodePath
@export var nota_posicion: Vector3

@onready var nota: Area3D = get_node_or_null(nota_path)


func _ready() -> void:
	if nota != null:
		nota.visible = false
	for e in get_tree().get_nodes_in_group("enemigo"):
		if e.has_signal("murio") and not e.murio.is_connected(_revisar):
			e.murio.connect(_revisar)


func _revisar(_enemigo: Node = null) -> void:
	for e in get_tree().get_nodes_in_group("enemigo"):
		if is_instance_valid(e) and e.get("muerto") != true:
			return
	_mostrar_nota()


func _mostrar_nota() -> void:
	if nota == null:
		return
	nota.visible = true
	if not nota_posicion.is_zero_approx():
		nota.global_position = nota_posicion