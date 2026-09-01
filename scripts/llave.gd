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
