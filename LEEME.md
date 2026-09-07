# S.W.A.T Hunter — Nivel 1

Escena principal: `escenas/nivel_1.tscn` (ya está puesta como main scene, se ejecuta con F5).

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

En el menú de pausa (Esc): Reanudar, Opciones (sensibilidad del ratón y
volumen), Reiniciar nivel y Salir del juego.

## Armas

| Nº | Arma | Daño | Cargador |
|---|---|---|---|
| 1 | HK416 (automática) | 24 | 30 / 180 |
| 2 | Pistola (semiautomática) | 18 | 12 / 96 |
| 3 | Cuchillo (cuerpo a cuerpo, alcance 2.4 m) | 65 | — |

Los valores se editan en el array `ARMAS` de `scripts/armas.gd`.

## Enemigos (`scripts/enemigo.gd`)

IA sencilla de 3 estados, sin navegación (se mueven en línea recta):

- **patrulla**: se pasea por puntos al azar alrededor de su sitio. Te detecta a
  menos de `rango_vision` si tiene línea de visión.
- **alerta**: sabe que andas cerca (te vio de lejos, oyó un disparo, o le
  avisó un compañero) → camina hacia esa posición a buscarte.
- **combate**: a `distancia_combate` o menos y con línea de visión → se planta,
  te encara y dispara con su `cadencia`; si te le pegas demasiado, retrocede.

Los disparos hacen ruido: los enemigos a menos de ~11 m pasan a alerta, pero
tardan `reaccion_min`-`reaccion_max` segundos en espabilar (se quedan mirando).
Matar a uno alerta a sus compañeros dentro de `radio_aviso` (9 m). Si te pierde
de vista te busca solo `memoria` segundos (2.5) y vuelve a patrullar. Mientras
patrulla tiene un punto ciego a la espalda (`angulo_vision`). Todo se ajusta en
el Inspector de `escenas/enemigo.tscn` (o por enemigo en `nivel_1.tscn`):
`velocidad`, `distancia_combate`, `rango_vision`, `precision`, `radio_patrulla`,
`radio_aviso`, `memoria`.

## Objetivo del nivel

1. Entrar al escondite y eliminar a los sicarios del cartel.
2. Uno de ellos (Enemigo4, marcado con `suelta_llave`) deja caer la llave al morir. Se recoge al pasar por encima.
3. Con la llave, acercarse a la puerta con candado y pulsar E: se reproduce la animación del candado y la puerta se abre.
4. En la sala del fondo está la libreta. Pulsar E para leer la nota que revela que el cartel mató a su familia.

## Estructura

```
escenas/nivel_1.tscn   nivel jugable (un solo piso)
escenas/jugador.tscn   personaje TPS con las 3 armas en la mano
escenas/enemigo.tscn   sicario con AK-47
escenas/puerta.tscn    puerta + candado animado
escenas/llave.tscn     llave que sueltan los enemigos
escenas/nota.tscn      libreta con la nota
scripts/               player.gd, armas.gd, enemigo.gd, puerta.gd, llave.gd, nota.gd
hud.gd / hud.tscn      interfaz (vida, munición, mira, mira de zoom, avisos, nota)
assets3d/armas/        hk416, pistola, ak47
assets3d/props/        nota, candado + llave
```

## Notas sobre los assets

- El cuchillo solo venía en formato `.blend` y Godot necesita Blender instalado para importar ese formato, así que el cuchillo está hecho con cajas simples en `escenas/jugador.tscn` (nodo `Armas/Cuchillo`). Si exportas el `.blend` a `.fbx` o `.glb`, basta con reemplazar esas tres mallas por el modelo.
- El AK-47 se usa para los enemigos. Su textura venía repetida cuatro veces con el mismo nombre dentro del zip, así que se le aplica un material de metal y madera por código en `enemigo.gd`.
- Las armas se enganchan al hueso `mixamorig_RightHand` con un `BoneAttachment3D` creado en `_ready()`.
- Las animaciones son de Mixamo *con* desplazamiento de raíz (el hueso `Hips` se mueve). En `_ready()` (player.gd y enemigo.gd) se elimina ese track de posición para que el modelo no "patine": el movimiento lo maneja el código con `velocity`.
- Agacharse (Ctrl izq.) encoge la cápsula, baja la cámara, baja la cadera del
  esqueleto e inclina el modelo hacia adelante (no hay clip de crouch en los
  assets). En el Inspector del Jugador, grupo "Agacharse", puedes subir
  `crouch_muslo` / `crouch_rodilla` / `crouch_tobillo` (empiezan en 0) si quieres
  que además doble las piernas; míralo en marcha porque la animación que suene
  puede pelearse con esos huesos.
- Al disparar desde la cadera, un temporizador (`disparo_timer`) mantiene visible la pose de disparo ~0,2 s para que la animación de caminar no la tape en el mismo frame.

## Configurar el HUD

Selecciona el nodo `HUD` dentro de `escenas/nivel_1.tscn` y abre el Inspector. Todo es editable por grupos: **Elementos visibles** (vida, arma, bajas, objetivo, mira, viñeta de daño), **Mira**, **Colores**, **Tipografía y márgenes**. Tras cambiar algo, relanza la escena con F5. El HUD se dibuja por código en `hud.gd`, no hay que tocar nodos.

La **mira siempre está visible**: tenue y abierta disparando desde la cadera
(`mira_hueco`, `mira_color_cadera`) y más cerrada y marcada al apuntar
(`mira_hueco_apuntando`, `mira_color`). El disparo sale del centro exacto de la
pantalla, así que la mira marca justo a dónde vas a pegar.
