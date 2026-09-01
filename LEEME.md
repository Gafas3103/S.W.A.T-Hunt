# S.W.A.T Hunter — Nivel 1

Escena principal: `escenas/nivel_1.tscn` (ya está puesta como main scene, se ejecuta con F5).

## Controles

| Acción | Tecla |
|---|---|
| Moverse | W A S D |
| Correr | Shift |
| Saltar | Espacio |
| Mirar | Mouse |
| Disparar | Clic izquierdo |
| Apuntar / zoom (sale la mira) | Clic derecho |
| Recargar | R |
| Interactuar (nota / puerta) | E |
| Cambiar de arma | 1, 2, 3 o rueda del mouse |
| Liberar el mouse | Esc |
| Reintentar tras morir | Enter |

## Armas

| Nº | Arma | Daño | Cargador |
|---|---|---|---|
| 1 | HK416 (automática) | 24 | 30 / 180 |
| 2 | Pistola (semiautomática) | 18 | 12 / 96 |
| 3 | Cuchillo (cuerpo a cuerpo, alcance 2.4 m) | 65 | — |

Los valores se editan en el array `ARMAS` de `scripts/armas.gd`.

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
