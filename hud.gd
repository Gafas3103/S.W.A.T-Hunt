extends CanvasLayer

@export_group("Elementos visibles")
@export var mostrar_vida := true
@export var mostrar_arma := true
@export var mostrar_bajas := true
@export var mostrar_objetivo := true
@export var mostrar_mira := true
@export var mostrar_vineta_dano := true
@export var mostrar_estado := true

@export_group("Mira")
@export var mira_largo := 9.0
@export var mira_grosor := 2.0
@export var mira_hueco := 9.0
@export var mira_hueco_apuntando := 3.0
@export var mira_color := Color(0.9, 1.0, 0.95, 0.95)
@export var mira_color_cadera := Color(0.85, 0.9, 0.9, 0.5)
@export var mira_punto_central := true

@export_group("Colores")
@export var color_texto := Color(0.92, 0.95, 0.96)
@export var color_apagado := Color(0.55, 0.58, 0.6)
@export var color_acento := Color(0.95, 0.75, 0.2)
@export var color_vida_ok := Color(0.35, 0.82, 0.45)
@export var color_vida_media := Color(0.95, 0.72, 0.2)
@export var color_vida_baja := Color(0.9, 0.27, 0.24)
@export var color_panel := Color(0.05, 0.06, 0.07, 0.62)
@export var color_borde := Color(1, 1, 1, 0.08)

@export_group("Tipografia y margenes")
@export var fuente_micro := 13
@export var fuente_pequena := 15
@export var fuente_normal := 18
@export var fuente_grande := 34
@export var margen := 26

@export_group("Referencias")
@export var jugador_path: NodePath

var _jugador: Node
var _raiz: Control

var _vida_barra: ProgressBar
var _vida_num: Label
var _vida_previa := 100
var _estado_txt: Label

var _arma_nombre: Label
var _arma_cargador: Label
var _arma_reserva: Label
var _pips: Array[Label] = []

var _bajas_num: Label
var _objetivo_txt: Label
var _llave_pip: Label
var _bajas := 0

var _mira: Control
var _punto: ColorRect
var _lineas: Array[ColorRect] = []
var _marca: Control
var _marca_t := 0.0
var _apuntando := false

var _aviso: PanelContainer
var _aviso_txt: Label
var _nota_capa: Control
var _nota_titulo: Label
var _nota_cuerpo: Label

var _vineta: TextureRect
var _flash := 0.0
var _vida_frac := 1.0
var _muerte_capa: Control
var _muerto := false
var _reloj := 0.0

var _pausa_capa: Control
var _pausa_opciones: Control
var _pausa_visible := false
var _sens_base := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reconstruir()


func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_pips.clear()
	_lineas.clear()
	_bajas = 0
	_muerto = false
	_pausa_visible = false
	get_tree().paused = false
	_construir_ui()
	_conectar_jugador.call_deferred()


func _input(evento: InputEvent) -> void:
	if _muerto:
		if evento.is_action_pressed("ui_accept"):
			get_tree().reload_current_scene()
		return
	if evento.is_action_pressed("pausa"):
		if _jugador != null and _jugador.get("leyendo") == true:
			return
		if _pausa_visible:
			_reanudar()
		else:
			_pausar()
		get_viewport().set_input_as_handled()


func _pausar() -> void:
	_pausa_visible = true
	_pausa_capa.visible = true
	_pausa_opciones.visible = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _reanudar() -> void:
	_pausa_visible = false
	_pausa_capa.visible = false
	get_tree().paused = false
	if _jugador != null and _jugador.get("leyendo") != true and not _muerto:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_reloj += delta

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.2)
	var pulso := 0.0
	if _vida_frac <= 0.3 and not _muerto:
		pulso = 0.22 + 0.12 * sin(_reloj * 7.0)
	if _vineta != null:
		_vineta.modulate.a = clampf(maxf(_flash, pulso), 0.0, 1.0)

	if _marca_t > 0.0:
		_marca_t = maxf(0.0, _marca_t - delta)
		if _marca != null:
			_marca.modulate.a = _marca_t / 0.35
			_marca.scale = Vector2.ONE * lerpf(1.35, 1.0, _marca_t / 0.35)

	if _muerte_capa != null:
		var objetivo := 1.0 if _muerto else 0.0
		_muerte_capa.modulate.a = lerpf(_muerte_capa.modulate.a, objetivo, delta * 4.0)
		_muerte_capa.visible = _muerte_capa.modulate.a > 0.01



func _construir_ui() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_construir_vineta()
	_construir_vida()
	_construir_arma()
	_construir_marcador()
	_construir_mira()
	_construir_aviso()
	_construir_nota()
	_construir_muerte()
	_construir_pausa()


func _construir_vineta() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.0, 0.0, 0.0))
	grad.set_color(1, Color(0.55, 0.0, 0.0, 0.75))
	grad.set_offset(0, 0.35)
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_vineta = TextureRect.new()
	_vineta.texture = tex
	_vineta.stretch_mode = TextureRect.STRETCH_SCALE
	_vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vineta.modulate.a = 0.0
	_vineta.visible = mostrar_vineta_dano
	_raiz.add_child(_vineta)


func _construir_vida() -> void:
	var panel := _panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = margen
	panel.offset_right = margen + 264
	panel.offset_bottom = -margen
	panel.offset_top = -margen - 70
	panel.visible = mostrar_vida
	_raiz.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var fila := HBoxContainer.new()
	col.add_child(fila)
	var etq := _label("VIDA", fuente_micro, color_apagado)
	fila.add_child(etq)
	var esp := Control.new()
	esp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(esp)
	_vida_num = _label("100", fuente_pequena, color_texto, HORIZONTAL_ALIGNMENT_RIGHT)
	fila.add_child(_vida_num)

	_vida_barra = ProgressBar.new()
	_vida_barra.custom_minimum_size = Vector2(236, 12)
	_vida_barra.show_percentage = false
	_vida_barra.max_value = 100
	_vida_barra.value = 100
	_estilo_barra(color_vida_ok)
	col.add_child(_vida_barra)

	_estado_txt = _label("", fuente_micro, color_acento)
	_estado_txt.visible = mostrar_estado
	col.add_child(_estado_txt)


func _construir_arma() -> void:
	var panel := _panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_right = -margen
	panel.offset_bottom = -margen
	panel.offset_left = -margen - 220
	panel.offset_top = -margen - 108
	panel.visible = mostrar_arma
	_raiz.add_child(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)

	_arma_nombre = _label("HK416", fuente_pequena, color_acento, HORIZONTAL_ALIGNMENT_RIGHT)
	col.add_child(_arma_nombre)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 4)
	col.add_child(fila)
	_arma_cargador = _label("30", fuente_grande, color_texto, HORIZONTAL_ALIGNMENT_RIGHT)
	fila.add_child(_arma_cargador)
	_arma_reserva = _label("/ 180", fuente_pequena, color_apagado, HORIZONTAL_ALIGNMENT_RIGHT)
	_arma_reserva.size_flags_vertical = Control.SIZE_SHRINK_END
	fila.add_child(_arma_reserva)

	var pips := HBoxContainer.new()
	pips.alignment = BoxContainer.ALIGNMENT_END
	pips.add_theme_constant_override("separation", 6)
	col.add_child(pips)
	for i in 3:
		var p := _label(str(i + 1), fuente_micro, color_apagado)
		pips.add_child(p)
		_pips.append(p)


func _construir_marcador() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.offset_right = -margen
	col.offset_left = -margen - 320
	col.offset_top = margen
	col.offset_bottom = margen + 90
	col.grow_vertical = Control.GROW_DIRECTION_END
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 4)
	_raiz.add_child(col)

	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	fila.add_theme_constant_override("separation", 8)
	col.add_child(fila)
	_llave_pip = _label("LLAVE", fuente_micro, color_apagado, HORIZONTAL_ALIGNMENT_RIGHT)
	fila.add_child(_llave_pip)
	var sep := _label("BAJAS", fuente_micro, color_apagado, HORIZONTAL_ALIGNMENT_RIGHT)
	fila.add_child(sep)
	_bajas_num = _label("00", fuente_normal, color_texto, HORIZONTAL_ALIGNMENT_RIGHT)
	fila.add_child(_bajas_num)
	_bajas_num.visible = mostrar_bajas
	sep.visible = mostrar_bajas

	_objetivo_txt = _label("Elimina a los sicarios del cartel", fuente_micro, color_apagado, HORIZONTAL_ALIGNMENT_RIGHT)
	_objetivo_txt.visible = mostrar_objetivo
	col.add_child(_objetivo_txt)


func _construir_mira() -> void:
	_mira = Control.new()
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.size = Vector2.ZERO
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.visible = mostrar_mira
	_raiz.add_child(_mira)
	if mira_punto_central:
		_punto = _linea(mira_grosor, mira_grosor, 0, 0)
		_mira.add_child(_punto)
	for i in 4:
		var l := _linea(1, 1, 0, 0)
		_mira.add_child(l)
		_lineas.append(l)
	_actualizar_mira(false)

	_marca = Control.new()
	_marca.set_anchors_preset(Control.PRESET_CENTER)
	_marca.size = Vector2.ZERO
	_marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marca.modulate.a = 0.0
	_raiz.add_child(_marca)
	for a in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var b := ColorRect.new()
		b.color = Color(1, 1, 1, 0.95)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.size = Vector2(7, 2)
		b.rotation = a.x * a.y * PI / 4.0
		b.position = a * 7.0 - Vector2(3.5, 1)
		_marca.add_child(b)


func _actualizar_mira(apuntando: bool) -> void:
	var col := mira_color if apuntando else mira_color_cadera
	for r in _lineas:
		r.color = col
	if _punto != null:
		_punto.color = Color(col, minf(1.0, col.a + 0.35))
	_colocar_mira(mira_hueco_apuntando if apuntando else mira_hueco)


func _colocar_mira(hueco: float) -> void:
	var brazo := hueco + mira_largo * 0.5
	var datos := [
		[mira_grosor, mira_largo, 0.0, -brazo],
		[mira_grosor, mira_largo, 0.0, brazo],
		[mira_largo, mira_grosor, -brazo, 0.0],
		[mira_largo, mira_grosor, brazo, 0.0],
	]
	for i in _lineas.size():
		var d = datos[i]
		var r := _lineas[i]
		r.size = Vector2(d[0], d[1])
		r.position = Vector2(d[2] - d[0] * 0.5, d[3] - d[1] * 0.5)


func _construir_aviso() -> void:
	_aviso = _panel()
	_aviso.set_anchors_preset(Control.PRESET_CENTER)
	_aviso.offset_top = 118
	_aviso.offset_bottom = 152
	_aviso.offset_left = -240
	_aviso.offset_right = 240
	_aviso.visible = false
	_raiz.add_child(_aviso)
	_aviso_txt = _label("", fuente_normal, color_texto, HORIZONTAL_ALIGNMENT_CENTER)
	_aviso_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aviso.add_child(_aviso_txt)


func _construir_nota() -> void:
	_nota_capa = Control.new()
	_nota_capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nota_capa.visible = false
	add_child(_nota_capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0, 0, 0, 0.8)
	_nota_capa.add_child(fondo)

	var hoja := PanelContainer.new()
	hoja.set_anchors_preset(Control.PRESET_CENTER)
	hoja.offset_left = -360
	hoja.offset_right = 360
	hoja.offset_top = -230
	hoja.offset_bottom = 230
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.9, 0.87, 0.78)
	estilo.border_color = Color(0.35, 0.29, 0.2)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(3)
	estilo.set_content_margin_all(30)
	hoja.add_theme_stylebox_override("panel", estilo)
	_nota_capa.add_child(hoja)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 16)
	hoja.add_child(columna)

	_nota_titulo = _label("", fuente_grande, Color(0.16, 0.11, 0.07), HORIZONTAL_ALIGNMENT_CENTER)
	columna.add_child(_nota_titulo)
	_nota_cuerpo = _label("", fuente_normal, Color(0.14, 0.1, 0.06))
	_nota_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nota_cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(_nota_cuerpo)
	var pie := _label("[E] o [Esc]  cerrar", fuente_pequena, Color(0.35, 0.29, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	columna.add_child(pie)


func _construir_muerte() -> void:
	_muerte_capa = Control.new()
	_muerte_capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muerte_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_muerte_capa.modulate.a = 0.0
	_muerte_capa.visible = false
	add_child(_muerte_capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.03, 0.0, 0.0, 0.72)
	_muerte_capa.add_child(fondo)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.offset_left = -260
	col.offset_right = 260
	col.offset_top = -60
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	_muerte_capa.add_child(col)
	col.add_child(_label("ABATIDO", 56, color_vida_baja, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(_label("Pulsa  Enter  para reintentar", fuente_normal, color_texto, HORIZONTAL_ALIGNMENT_CENTER))


func _construir_pausa() -> void:
	_pausa_capa = Control.new()
	_pausa_capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pausa_capa.visible = false
	add_child(_pausa_capa)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.02, 0.03, 0.04, 0.85)
	_pausa_capa.add_child(fondo)

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.offset_left = -150
	caja.offset_right = 150
	caja.offset_top = -170
	caja.alignment = BoxContainer.ALIGNMENT_BEGIN
	caja.add_theme_constant_override("separation", 12)
	_pausa_capa.add_child(caja)

	var titulo := _label("PAUSA", 42, color_acento, HORIZONTAL_ALIGNMENT_CENTER)
	titulo.custom_minimum_size.y = 60
	caja.add_child(titulo)

	caja.add_child(_boton("Reanudar", _reanudar))
	caja.add_child(_boton("Opciones", func(): _pausa_opciones.visible = not _pausa_opciones.visible))
	caja.add_child(_boton("Reiniciar nivel", func():
		get_tree().paused = false
		get_tree().reload_current_scene()))
	caja.add_child(_boton("Salir del juego", func(): get_tree().quit()))

	_pausa_opciones = _panel()
	_pausa_opciones.mouse_filter = Control.MOUSE_FILTER_STOP
	_pausa_opciones.set_anchors_preset(Control.PRESET_CENTER)
	_pausa_opciones.offset_left = 180
	_pausa_opciones.offset_right = 500
	_pausa_opciones.offset_top = -110
	_pausa_opciones.offset_bottom = 110
	_pausa_opciones.visible = false
	_pausa_capa.add_child(_pausa_opciones)

	var op := VBoxContainer.new()
	op.add_theme_constant_override("separation", 10)
	_pausa_opciones.add_child(op)
	op.add_child(_label("OPCIONES", fuente_normal, color_texto, HORIZONTAL_ALIGNMENT_CENTER))

	op.add_child(_label("Sensibilidad del ratón", fuente_micro, color_apagado))
	var sens := HSlider.new()
	sens.min_value = 0.3
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = 1.0
	sens.custom_minimum_size.y = 20
	sens.value_changed.connect(func(v):
		if _jugador != null:
			if _sens_base <= 0.0:
				_sens_base = _jugador.get("sensibilidad")
			_jugador.set("sensibilidad", _sens_base * v))
	op.add_child(sens)

	op.add_child(_label("Volumen", fuente_micro, color_apagado))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	vol.custom_minimum_size.y = 20
	vol.value_changed.connect(func(v):
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(0, v <= 0.001))
	op.add_child(vol)


func _boton(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 44)
	b.add_theme_font_size_override("font_size", fuente_normal)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.12, 0.14, 0.9)
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = color_borde
	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.2, 0.24, 0.95)
	hover.border_color = color_acento
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", normal)
	b.pressed.connect(accion)
	return b



func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = color_panel
	e.border_color = color_borde
	e.set_border_width_all(1)
	e.set_corner_radius_all(4)
	e.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", e)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(texto: String, tam: int, color: Color, alineacion := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = alineacion
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _linea(ancho: float, alto: float, cx: float, cy: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = mira_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(ancho, alto)
	r.position = Vector2(cx - ancho * 0.5, cy - alto * 0.5)
	return r


func _estilo_barra(relleno: Color) -> void:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.5)
	fondo.set_corner_radius_all(3)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = relleno
	lleno.set_corner_radius_all(3)
	_vida_barra.add_theme_stylebox_override("background", fondo)
	_vida_barra.add_theme_stylebox_override("fill", lleno)



func _conectar_jugador() -> void:
	_jugador = get_node_or_null(jugador_path) if jugador_path != NodePath("") else null
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador")
	if _jugador == null:
		push_warning("HUD: no encontre al jugador. Asigna 'Jugador Path' en el Inspector.")
		return
	_atar("vida_cambiada", _on_vida)
	_atar("municion_cambiada", _on_municion)
	_atar("arma_cambiada", _on_arma)
	_atar("apuntando_cambiado", _on_apuntar)
	_atar("agachado_cambiado", _on_agachado)
	_atar("llave_cambiada", _on_llave)
	_atar("aviso_cambiado", _on_aviso)
	_atar("nota_abierta", _on_nota_abierta)
	_atar("nota_cerrada", _on_nota_cerrada)
	_atar("jugador_murio", _on_murio)
	_atar("enemigo_abatido", _on_baja)
	_atar("impacto", _on_impacto)
	if _jugador.has_method("emitir_estado"):
		_jugador.emitir_estado()


func _atar(senal: String, funcion: Callable) -> void:
	if _jugador.has_signal(senal) and not _jugador.is_connected(senal, funcion):
		_jugador.connect(senal, funcion)



func _on_vida(actual: int, maxima: int) -> void:
	_vida_frac = float(actual) / maxf(1.0, float(maxima))
	if actual < _vida_previa:
		_flash = 1.0
	_vida_previa = actual
	_vida_barra.max_value = maxima
	_vida_barra.value = actual
	_vida_num.text = str(actual)
	var col := color_vida_ok
	if _vida_frac <= 0.25:
		col = color_vida_baja
	elif _vida_frac <= 0.5:
		col = color_vida_media
	_estilo_barra(col)


func _on_municion(cargador: int, reserva: int) -> void:
	if cargador == 0 and reserva == 0:
		_arma_cargador.text = "—"
		_arma_reserva.text = ""
	else:
		_arma_cargador.text = str(cargador)
		_arma_reserva.text = "/ %d" % reserva
	_arma_cargador.add_theme_color_override("font_color", color_vida_baja if cargador == 0 else color_texto)


func _on_arma(nombre: String, indice: int) -> void:
	_arma_nombre.text = nombre.to_upper()
	for i in _pips.size():
		var activo := i == indice
		_pips[i].add_theme_color_override("font_color", color_acento if activo else color_apagado)


func _on_apuntar(activo: bool) -> void:
	_apuntando = activo
	_actualizar_mira(activo)


func _on_agachado(activo: bool) -> void:
	if _estado_txt != null:
		_estado_txt.text = "AGACHADO" if activo else ""


func _on_llave(tiene: bool) -> void:
	_llave_pip.add_theme_color_override("font_color", color_acento if tiene else color_apagado)
	if tiene and mostrar_objetivo:
		_objetivo_txt.text = "Abre la puerta con candado  [E]"


func _on_aviso(texto: String) -> void:
	_aviso_txt.text = texto
	_aviso.visible = texto != ""


func _on_nota_abierta(titulo: String, texto: String) -> void:
	_nota_titulo.text = titulo
	_nota_cuerpo.text = texto
	_nota_capa.visible = true
	_mira.visible = false
	if mostrar_objetivo:
		_objetivo_txt.text = "Sal de aqui"


func _on_nota_cerrada() -> void:
	_nota_capa.visible = false
	_mira.visible = mostrar_mira


func _on_murio() -> void:
	_muerto = true
	_aviso.visible = false
	_mira.visible = false


func _on_baja() -> void:
	_bajas += 1
	_bajas_num.text = "%02d" % _bajas


func _on_impacto(en_enemigo: bool) -> void:
	if _marca == null:
		return
	_marca_t = 0.35
	var c := color_vida_baja if en_enemigo else Color(1, 1, 1, 0.9)
	for hijo in _marca.get_children():
		(hijo as ColorRect).color = c
