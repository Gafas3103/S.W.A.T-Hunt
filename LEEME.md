# S.W.A.T Hunter — Nivel 1

Escena principal: `escenas/nivel_1.tscn` (ya está puesta como main scene, se ejecuta con F5).
Motor: Godot 4.7.

## Antes de abrir el proyecto

Los modelos `.fbx` viajan en **Git LFS**. Si descargas el repositorio como ZIP o clonas
sin LFS, esos archivos llegan como punteros de texto y Godot no puede importarlos: el
juego arrancaría sin personajes, sin armas y sin animaciones.

```bash
git lfs install
git lfs pull
```

Si ya abriste el proyecto con los punteros sin resolver, borra la carpeta `.godot/` y
vuelve a abrirlo para forzar la reimportación.

## Controles

| Acción | Tecla |
|---|---|
| Moverse | W A S D |
| Correr | Shift (hacia adelante, sin apuntar) |
| Agacharse | Ctrl izquierdo (mantener) |
| Saltar | Espacio |
| Mirar | Mouse |
| Disparar | Clic izquierdo |
| Apuntar / zoom (sale la mira) | Clic derecho |
| Recargar | R |
| Interactuar (nota / puerta) | E |
| Cambiar de arma | 1, 2, 3 o rueda del mouse |
| Pausa / menú | Esc |
| Reintentar tras morir | Enter |

En el menú de pausa (Esc): Reanudar, Opciones (sensibilidad del ratón y volumen),
Reiniciar nivel y Salir del juego.

## Armas

| Nº | Arma | Daño | Cargador |
|---|---|---|---|
| 1 | HK416 (automática) | 24 | 30 / 180 |
| 2 | Pistola (semiautomática) | 18 | 12 / 96 |
| 3 | Cuchillo (cuerpo a cuerpo, alcance 2.4 m) | 65 | — |

Los valores se editan en el array `ARMAS` de `scripts/armas.gd`. El cuchillo es
silencioso: usarlo no alerta a los enemigos cercanos, disparar sí.

## Mapa

El nivel se arma con `Mapa.tscn`: un pasillo central (`Piso_Pasillo.tscn`) con módulos de
cuarto reutilizables a los lados (`Cuarto_1/2/3.tscn`), más cobertura repartida por las
salas (`escenas/cobertura.tscn`: cajas y mesas). `scripts/navmap.gd` construye en tiempo de
ejecución un navmesh a partir de los suelos del nivel (sin horneado), que usan los
enemigos para moverse por los pasillos en vez de caminar en línea recta.

## Enemigos (`scripts/enemigo.gd`)

Comportamiento de 3 estados, moviéndose por el navmesh del nivel (`NavigationAgent3D`):

- **patrulla**: se pasea por puntos al azar alrededor de su sitio. Te detecta a menos de
  `rango_vision` si tiene línea de visión.
- **alerta**: sabe que andas cerca (te vio de lejos, oyó un disparo, o le avisó un
  compañero) → recorre el navmesh hasta esa posición a buscarte.
- **combate**: a `distancia_combate` o menos y con línea de visión → se planta, te encara
  y dispara con su `cadencia`; si te le pegas demasiado, retrocede sin dejar de apuntar.

Los disparos hacen ruido: los enemigos a menos de ~11 m pasan a alerta, pero tardan
`reaccion_min`-`reaccion_max` segundos en espabilar (se quedan mirando). Matar a uno
alerta a sus compañeros dentro de `radio_aviso` (9 m). Si te pierde de vista te busca solo
`memoria` segundos (2.5) y vuelve a patrullar. Mientras patrulla tiene un punto ciego a la
espalda (`angulo_vision`). Al morir suelta un chorro de partículas de sangre, deja de
colisionar y el cuerpo se queda tendido en el suelo. Todo se ajusta en el Inspector de
`escenas/enemigo.tscn` (o por enemigo dentro de `nivel_1.tscn`).

## Objetivo del nivel

1. Entrar al escondite y eliminar a los sicarios del cartel.
2. Al eliminar al último, la nota aparece junto a la caja más cercana a la salida.
3. Hay una llave repartida por el mapa; algunas puertas llevan candado
   (`escenas/puerta_candado.tscn`) y necesitan la llave y su animación de apertura, otras
   son puertas simples (`escenas/puerta.tscn`) que abren directamente con E.
4. Leer la nota (E) revela que el cartel mató a la familia del sargento.

## Estructura

```
escenas/nivel_1.tscn        nivel jugable, instancia Mapa.tscn + jugador + enemigos + HUD
Mapa.tscn                   pasillo + cuartos combinados en la disposición final
Cuarto_1/2/3.tscn           módulos de cuarto texturizados, reutilizables
Piso_Pasillo.tscn           pasillo central con sus colisiones
escenas/cobertura.tscn      cajas y mesa como cobertura dentro de las salas
escenas/jugador.tscn        personaje TPS con las 3 armas en la mano
escenas/enemigo.tscn        sicario con AK-47, navmesh y partículas de sangre
escenas/puerta.tscn         puerta simple, sin llave
escenas/puerta_candado.tscn puerta con candado animado, requiere llave
escenas/llave.tscn          llave que se recoge del mapa o al matar a un enemigo marcado
escenas/nota.tscn           libreta con la nota
scripts/                    player.gd, armas.gd, enemigo.gd, puerta.gd, puerta_candado.gd,
                             llave.gd, nota.gd, nivel.gd, navmap.gd, particulas.gd
hud.gd / hud.tscn           interfaz (vida, munición, mira, avisos, nota, pausa)
assets3d/enemigo/           modelo distinto del jugador para los sicarios
assets3d/armas/             hk416, pistola, ak47
assets3d/props/             nota, candado + llave
```

## Notas sobre los assets

- El cuchillo solo venía en `.blend` y Godot necesita Blender instalado para importar ese
  formato, así que está hecho con cajas simples en `escenas/jugador.tscn`
  (nodo `Armas/Cuchillo`). Si exportas el `.blend` a `.fbx` o `.glb`, basta con reemplazar
  esas tres mallas por el modelo.
- El AK-47 se usa para los enemigos y no trae texturas propias: recibe un material de
  metal y madera por código en `enemigo.gd`.
- Las armas se enganchan al hueso `mixamorig_RightHand` con un `BoneAttachment3D` creado
  en `_ready()`.
- Las animaciones de Mixamo llevan desplazamiento de raíz (el hueso `Hips` se mueve). En
  `_ready()` (player.gd y enemigo.gd) se elimina ese track de posición para que el modelo
  no patine: el movimiento lo maneja el código con `velocity`. La animación de morir
  conserva el descenso vertical del hueso para que el cuerpo se desplome hasta el suelo,
  sin arrastrarse en el plano.
- Agacharse (Ctrl izq.) encoge la cápsula, baja la cámara, baja la cadera del esqueleto e
  inclina el modelo hacia adelante (no hay clip de crouch en los assets). En el Inspector
  del Jugador, grupo "Agacharse", puedes subir `crouch_muslo` / `crouch_rodilla` /
  `crouch_tobillo` (empiezan en 0) si quieres que además doble las piernas.
- Al spawnear, tanto el jugador como los enemigos se anclan al suelo con un raycast, para
  no depender de la altura exacta a la que quedó colocado el nodo en la escena.

## Configurar el HUD

Selecciona el nodo `HUD` dentro de `escenas/nivel_1.tscn` y abre el Inspector. Todo es
editable por grupos: **Elementos visibles** (vida, arma, bajas, objetivo, mira, viñeta de
daño, estado), **Mira**, **Colores**, **Tipografía y márgenes**. Tras cambiar algo, relanza
la escena con F5. El HUD se dibuja por código en `hud.gd`, no hay que tocar nodos.

La mira siempre está visible: tenue y abierta disparando desde la cadera (`mira_hueco`,
`mira_color_cadera`) y más cerrada y marcada al apuntar (`mira_hueco_apuntando`,
`mira_color`). El disparo sale del centro exacto de la pantalla, así que la mira marca
justo a dónde vas a pegar.
