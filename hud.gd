extends CanvasLayer

@export_group("Elementos visibles")
@export var mostrar_mira := true
@export var mostrar_vida := true
@export var mostrar_municion := true
@export var mostrar_bajas := true

@export_group("Mira")
@export var mira_largo := 10.0
@export var mira_grosor := 2.0
@export var mira_hueco := 6.0
@export var mira_punto_central := false
@export var mira_color := Color(1, 1, 1, 0.85)

@export_group("Colores")
@export var color_texto := Color(1, 1, 1)
@export var color_vida_ok := Color(0.30, 0.82, 0.40)
@export var color_vida_media := Color(0.95, 0.75, 0.20)
@export var color_vida_baja := Color(0.90, 0.25, 0.25)
@export var color_panel := Color(0, 0, 0, 0.45)

@export_group("Tipografia y margenes")
@export var fuente_pequena := 15
@export var fuente_normal := 18
@export var fuente_grande := 30
@export var margen := 28

@export_group("Referencias")
@export var jugador_path: NodePath

var _jugador: Node
var _raiz: Control
var _mira: Control
var _vida_barra: ProgressBar
var _vida_texto: Label
var _municion_texto: Label
var _bajas_texto: Label
var _aviso_texto: Label
var _nota_capa: Control
var _nota_titulo: Label
var _nota_cuerpo: Label
var _bajas := 0
var _muerto := false


func _ready() -> void:
	reconstruir()


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_bajas = 0
	_construir_ui()
	_conectar_jugador.call_deferred()


func _input(evento: InputEvent) -> void:
	if _muerto and evento.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _construir_ui() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var caja_vida := VBoxContainer.new()
	caja_vida.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	caja_vida.offset_left = margen
	caja_vida.offset_right = margen + 260
	caja_vida.offset_top = -margen - 52
	caja_vida.offset_bottom = -margen
	caja_vida.add_theme_constant_override("separation", 4)
	caja_vida.visible = mostrar_vida
	_raiz.add_child(caja_vida)

	_vida_texto = _nueva_label("VIDA", fuente_normal, HORIZONTAL_ALIGNMENT_LEFT)
	caja_vida.add_child(_vida_texto)

	_vida_barra = ProgressBar.new()
	_vida_barra.custom_minimum_size = Vector2(260, 16)
	_vida_barra.show_percentage = false
	_vida_barra.max_value = 100
	_vida_barra.value = 100
	_aplicar_estilo_barra(color_vida_ok)
	caja_vida.add_child(_vida_barra)

	_municion_texto = _nueva_label("-- / --", fuente_grande, HORIZONTAL_ALIGNMENT_RIGHT)
	_municion_texto.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_municion_texto.offset_left = -margen - 240
	_municion_texto.offset_right = -margen
	_municion_texto.offset_top = -margen - 44
	_municion_texto.offset_bottom = -margen
	_municion_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_municion_texto.visible = mostrar_municion
	_raiz.add_child(_municion_texto)

	_bajas_texto = _nueva_label("BAJAS: 0", fuente_normal, HORIZONTAL_ALIGNMENT_RIGHT)
	_bajas_texto.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bajas_texto.offset_left = -margen - 240
	_bajas_texto.offset_right = -margen
	_bajas_texto.offset_top = margen
	_bajas_texto.offset_bottom = margen + 28
	_bajas_texto.visible = mostrar_bajas
	_raiz.add_child(_bajas_texto)

	_aviso_texto = _nueva_label("", fuente_normal, HORIZONTAL_ALIGNMENT_CENTER)
	_aviso_texto.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_aviso_texto.offset_left = -300
	_aviso_texto.offset_right = 300
	_aviso_texto.offset_top = -150
	_aviso_texto.offset_bottom = -118
	_raiz.add_child(_aviso_texto)

	_mira = Control.new()
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.size = Vector2.ZERO
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.visible = mostrar_mira
	_raiz.add_child(_mira)
	_construir_mira()

	_construir_nota()


func _construir_mira() -> void:
	var brazo := mira_hueco + mira_largo * 0.5
	if mira_punto_central:
		_mira.add_child(_linea_mira(mira_grosor, mira_grosor, 0, 0))
	_mira.add_child(_linea_mira(mira_grosor, mira_largo, 0, -brazo))
	_mira.add_child(_linea_mira(mira_grosor, mira_largo, 0, brazo))
	_mira.add_child(_linea_mira(mira_largo, mira_grosor, -brazo, 0))
	_mira.add_child(_linea_mira(mira_largo, mira_grosor, brazo, 0))


func _construir_nota() -> void:
	_nota_capa = Control.new()
	_nota_capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nota_capa.visible = false
	add_child(_nota_capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0, 0, 0, 0.78)
	_nota_capa.add_child(fondo)

	var hoja := PanelContainer.new()
	hoja.set_anchors_preset(Control.PRESET_CENTER)
	hoja.offset_left = -360
	hoja.offset_right = 360
	hoja.offset_top = -220
	hoja.offset_bottom = 220
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.90, 0.87, 0.78)
	estilo.border_color = Color(0.35, 0.29, 0.20)
	estilo.set_border_width_all(4)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(28)
	hoja.add_theme_stylebox_override("panel", estilo)
	_nota_capa.add_child(hoja)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	hoja.add_child(columna)

	_nota_titulo = Label.new()
	_nota_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nota_titulo.add_theme_font_size_override("font_size", fuente_grande)
	_nota_titulo.add_theme_color_override("font_color", Color(0.16, 0.11, 0.07))
	columna.add_child(_nota_titulo)

	_nota_cuerpo = Label.new()
	_nota_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nota_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nota_cuerpo.add_theme_font_size_override("font_size", fuente_normal)
	_nota_cuerpo.add_theme_color_override("font_color", Color(0.14, 0.10, 0.06))
	columna.add_child(_nota_cuerpo)

	var pie := Label.new()
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.text = "[E]  cerrar"
	pie.add_theme_font_size_override("font_size", fuente_pequena)
	pie.add_theme_color_override("font_color", Color(0.35, 0.29, 0.20))
	columna.add_child(pie)


func _linea_mira(ancho: float, alto: float, cx: float, cy: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = mira_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(ancho, alto)
	r.position = Vector2(cx - ancho * 0.5, cy - alto * 0.5)
	return r


func _nueva_label(texto: String, tam: int, alineacion: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = alineacion
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color_texto)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _aplicar_estilo_barra(color_relleno: Color) -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = color_panel
	fondo.set_corner_radius_all(3)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = color_relleno
	relleno.set_corner_radius_all(3)
	_vida_barra.add_theme_stylebox_override("background", fondo)
	_vida_barra.add_theme_stylebox_override("fill", relleno)


func _conectar_jugador() -> void:
	_jugador = null
	if jugador_path != NodePath(""):
		_jugador = get_node_or_null(jugador_path)
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador")
	if _jugador == null:
		push_warning("HUD: no encontre al jugador. Asigna Jugador Path en el Inspector.")
		return

	_jugador.vida_cambiada.connect(_on_vida_cambiada)
	_jugador.municion_cambiada.connect(_on_municion_cambiada)
	_jugador.aviso_cambiado.connect(_on_aviso_cambiado)
	_jugador.nota_abierta.connect(_on_nota_abierta)
	_jugador.nota_cerrada.connect(_on_nota_cerrada)
	_jugador.jugador_murio.connect(_on_jugador_murio)
	_jugador.enemigo_abatido.connect(_on_enemigo_abatido)
	if _jugador.has_method("emitir_estado"):
		_jugador.emitir_estado()


func _on_vida_cambiada(actual: int, maxima: int) -> void:
	_vida_barra.max_value = maxima
	_vida_barra.value = actual
	var frac := float(actual) / maxf(1.0, float(maxima))
	var col := color_vida_ok
	if frac <= 0.25:
		col = color_vida_baja
	elif frac <= 0.5:
		col = color_vida_media
	_aplicar_estilo_barra(col)
	_vida_texto.text = "VIDA  %d / %d" % [actual, maxima]


func _on_municion_cambiada(cargador: int, reserva: int) -> void:
	if cargador == 0 and reserva == 0:
		_municion_texto.text = "- -"
	else:
		_municion_texto.text = "%d / %d" % [cargador, reserva]


func _on_aviso_cambiado(texto: String) -> void:
	_aviso_texto.text = texto


func _on_nota_abierta(titulo: String, texto: String) -> void:
	_nota_titulo.text = titulo
	_nota_cuerpo.text = texto
	_nota_capa.visible = true
	_mira.visible = false
	_aviso_texto.visible = false


func _on_nota_cerrada() -> void:
	_nota_capa.visible = false
	_mira.visible = mostrar_mira
	_aviso_texto.visible = true


func _on_jugador_murio() -> void:
	_muerto = true
	_vida_texto.text = "ABATIDO"
	_municion_texto.text = "- -"


func _on_enemigo_abatido() -> void:
	_bajas += 1
	_bajas_texto.text = "BAJAS: %d" % _bajas
