extends Node3D

@export var nota_path: NodePath

@onready var nota: Area3D = get_node_or_null(nota_path)


func _ready() -> void:
	if nota != null:
		nota.visible = false
	for e in get_tree().get_nodes_in_group("enemigo"):
		if e.has_signal("murio") and not e.murio.is_connected(_revisar):
			e.murio.connect(_revisar)


func _revisar(enemigo: Node = null) -> void:
	for e in get_tree().get_nodes_in_group("enemigo"):
		if is_instance_valid(e) and e.get("muerto") != true:
			return
	_mostrar_nota(enemigo)


func _mostrar_nota(ultimo: Node) -> void:
	if nota == null:
		return
	var punto: Vector3 = ultimo.global_position if ultimo is Node3D else Vector3.ZERO
	var caja: Node3D = _caja_mas_cercana(punto)
	if caja == null:
		nota.visible = true
		return
	var tope := _tope_caja(caja)
	nota.global_position = tope
	nota.visible = true


func _caja_mas_cercana(punto: Vector3) -> Node3D:
	var cobertura := get_node_or_null("Cobertura") as Node3D
	if cobertura == null:
		return null
	var mejor: Node3D = null
	var mejor_d := INF
	for hijo in cobertura.get_children():
		if not hijo is StaticBody3D:
			continue
		var centro: Vector3 = (hijo.get_node("Colision") as CollisionShape3D).global_transform.origin
		var d := centroid_horizontal(punto, centro)
		if d < mejor_d:
			mejor_d = d
			mejor = hijo
	return mejor


func centroid_horizontal(a: Vector3, b: Vector3) -> float:
	var p := a - b
	p.y = 0.0
	return p.length()


func _tope_caja(caja: Node3D) -> Vector3:
	var shape := (caja.get_node("Colision") as CollisionShape3D)
	var c: Vector3 = shape.global_transform.origin
	var alto := 0.5
	if shape.shape is BoxShape3D:
		alto = (shape.shape as BoxShape3D).size.y * 0.5
	return Vector3(c.x, c.y + alto + 0.12, c.z)