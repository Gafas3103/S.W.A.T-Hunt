extends Area3D

@export var titulo := "NOTA MANCHADA"
@export_multiline var texto := ""
@export var aviso := "[E]  Leer la nota"
@export var gira := true

var leida := false


func _ready() -> void:
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)


func _process(delta: float) -> void:
	if gira:
		rotate_y(delta * 0.6)


func _al_entrar(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("fijar_interaccion"):
		cuerpo.fijar_interaccion(self, aviso)


func _al_salir(cuerpo: Node3D) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("quitar_interaccion"):
		cuerpo.quitar_interaccion(self)


func interactuar(jugador: Node) -> void:
	leida = true
	if jugador.has_method("abrir_nota"):
		jugador.abrir_nota(titulo, texto)
