extends CanvasLayer
## HUD — vida, munición, mira y marcador de bajas.
##
## CÓMO CONFIGURARLO
##   1. En la escena selecciona el nodo "HUD" y abre el Inspector.
##   2. Cambia lo que quieras en los grupos de abajo (qué se muestra,
##      colores, tamaños, márgenes, tamaño de la mira...).
##   3. En el grupo "Referencias" arrastra tu CharacterBody3D al campo
##      "Jugador Path" (si no lo haces, el HUD lo busca solo por el
##      grupo "jugador").
##   4. El HUD se dibuja por código a partir de esta configuración: al
##      cambiar un valor en el Inspector, vuelve a lanzar la escena
##      (F6) para verlo, o llama a hud.reconstruir() desde otro script.

@export_group("Elementos visibles")
@export var mostrar_mira := true
@export var mostrar_vida := true
@export var mostrar_municion := true
@export var mostrar_bajas := true

@export_group("Mira")
@export var mira_largo := 10.0        ## largo de cada línea de la cruz
@export var mira_grosor := 2.0        ## grosor de cada línea
@export var mira_hueco := 6.0         ## espacio vacío en el centro
@export var mira_punto_central := false
@export var mira_color := Color(1, 1, 1, 0.85)

@export_group("Colores")
@export var color_texto := Color(1, 1, 1)
@export var color_vida_ok := Color(0.30, 0.82, 0.40)     ## vida > 50%
@export var color_vida_media := Color(0.95, 0.75, 0.20)  ## vida 25%-50%
@export var color_vida_baja := Color(0.90, 0.25, 0.25)   ## vida <= 25%
@export var color_panel := Color(0, 0, 0, 0.45)          ## fondo de la barra

@export_group("Tipografía y márgenes")
@export var fuente_normal := 18
@export var fuente_grande := 30
@export var margen := 28              ## separación con el borde de la pantalla

@export_group("Referencias")
@export var jugador_path: NodePath

var _jugador: Node
var _raiz: Control
var _mira: Control
var _vida_barra: ProgressBar
var _vida_texto: Label
var _municion_texto: Label
var _bajas_texto: Label
var _bajas := 0


func _ready() -> void:
	reconstruir()


## Rehace toda la interfaz con la configuración actual. Útil si cambias
## propiedades en caliente desde otro script.
func reconstruir() -> void:
	for hijo in get_children():
		hijo.queue_free()
	_bajas = 0
	_construir_ui()
	_conectar_jugador()


# ── Construcción de la interfaz ─────────────────────────────────────

func _construir_ui() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	# Vida — abajo a la izquierda
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

	# Munición — abajo a la derecha
	_municion_texto = _nueva_label("-- / --", fuente_grande, HORIZONTAL_ALIGNMENT_RIGHT)
	_municion_texto.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_municion_texto.offset_left = -margen - 240
	_municion_texto.offset_right = -margen
	_municion_texto.offset_top = -margen - 44
	_municion_texto.offset_bottom = -margen
	_municion_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_municion_texto.visible = mostrar_municion
	_raiz.add_child(_municion_texto)

	# Bajas — arriba a la derecha
	_bajas_texto = _nueva_label("BAJAS: 0", fuente_normal, HORIZONTAL_ALIGNMENT_RIGHT)
	_bajas_texto.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_bajas_texto.offset_left = -margen - 240
	_bajas_texto.offset_right = -margen
	_bajas_texto.offset_top = margen
	_bajas_texto.offset_bottom = margen + 28
	_bajas_texto.visible = mostrar_bajas
	_raiz.add_child(_bajas_texto)

	# Mira — centro exacto de la pantalla
	_mira = Control.new()
	_mira.set_anchors_preset(Control.PRESET_CENTER)
	_mira.size = Vector2.ZERO
	_mira.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mira.visible = mostrar_mira
	_raiz.add_child(_mira)
	_construir_mira()


func _construir_mira() -> void:
	var brazo := mira_hueco + mira_largo * 0.5
	if mira_punto_central:
		_mira.add_child(_linea_mira(mira_grosor, mira_grosor, 0, 0))
	_mira.add_child(_linea_mira(mira_grosor, mira_largo, 0, -brazo))  # arriba
	_mira.add_child(_linea_mira(mira_grosor, mira_largo, 0, brazo))   # abajo
	_mira.add_child(_linea_mira(mira_largo, mira_grosor, -brazo, 0))  # izquierda
	_mira.add_child(_linea_mira(mira_largo, mira_grosor, brazo, 0))   # derecha


func _linea_mira(ancho: float, alto: float, cx: float, cy: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = mira_color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(ancho, alto)
	# _mira está en el centro de la pantalla, así que colocamos cada
	# línea respecto a ese origen (0,0).
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


# ── Conexión con el jugador ────────────────────────────────────────

func _conectar_jugador() -> void:
	_jugador = null
	if jugador_path != NodePath(""):
		_jugador = get_node_or_null(jugador_path)
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador")
	if _jugador == null:
		push_warning("HUD: no encontré al jugador. Asigna 'Jugador Path' en el Inspector o añade el jugador al grupo 'jugador'.")
		return

	if _jugador.has_signal("vida_cambiada"):
		_jugador.vida_cambiada.connect(_on_vida_cambiada)
	if _jugador.has_signal("municion_cambiada"):
		_jugador.municion_cambiada.connect(_on_municion_cambiada)
	if _jugador.has_signal("jugador_murio"):
		_jugador.jugador_murio.connect(_on_jugador_murio)
	if _jugador.has_signal("enemigo_abatido"):
		_jugador.enemigo_abatido.connect(_on_enemigo_abatido)

	# Pedimos el estado inicial para pintar los valores reales.
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
	_municion_texto.text = "%d / %d" % [cargador, reserva]


func _on_jugador_murio() -> void:
	_vida_texto.text = "ABATIDO"
	_municion_texto.text = "-- / --"


func _on_enemigo_abatido() -> void:
	_bajas += 1
	_bajas_texto.text = "BAJAS: %d" % _bajas
