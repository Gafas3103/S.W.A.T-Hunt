extends Node3D

@export var grosor_min := 0.04
@export var grosor_max := 0.55
@export var altura_centro_max := 0.5
@export var grupo_mallas := &"geometria_nav"


func _ready() -> void:
	add_to_group("navegacion")
	_etiquetar_geometria()
	call_deferred("crear_region")


func _etiquetar_geometria() -> void:
	var raiz := get_tree().current_scene
	if raiz == null:
		return
	for nodo in raiz.find_children("*", "StaticBody3D", true, false):
		nodo.add_to_group(grupo_mallas)


func crear_region() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion"
	add_child(region)
	var malla := NavigationMesh.new()
	var vertices := PackedVector3Array()
	var poligonos: Array[PackedInt32Array] = []
	for cuerpo in get_tree().get_nodes_in_group(grupo_mallas):
		if not (cuerpo is StaticBody3D):
			continue
		for hijo in cuerpo.get_children():
			if not (hijo is CollisionShape3D):
				continue
			var forma := (hijo as CollisionShape3D).shape
			if forma is BoxShape3D:
				var tam := (forma as BoxShape3D).size
				var centro := (hijo as CollisionShape3D).global_position
				if absf(centro.y) <= altura_centro_max and tam.y >= grosor_min and tam.y <= grosor_max:
					_agregar_superficie((hijo as CollisionShape3D).global_transform, tam, vertices, poligonos)
	malla.set_vertices(vertices)
	for p in poligonos:
		malla.add_polygon(p)
	region.navigation_mesh = malla


func _agregar_superficie(tf: Transform3D, tam: Vector3, vertices: PackedVector3Array, poligonos: Array[PackedInt32Array]) -> void:
	var sx := tam.x * 0.5
	var sy := tam.y * 0.5
	var sz := tam.z * 0.5
	var esq := [
		Vector3(-sx, sy, -sz),
		Vector3(sx, sy, -sz),
		Vector3(sx, sy, sz),
		Vector3(-sx, sy, sz),
	]
	var base := vertices.size()
	for e in esq:
		vertices.append(tf * e)
	poligonos.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))