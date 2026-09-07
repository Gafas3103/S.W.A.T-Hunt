class_name Efectos
extends RefCounted


static func particulas(sistema: GPUParticles3D) -> bool:
	if sistema == null:
		return false
	sistema.restart()
	sistema.emitting = true
	return true
