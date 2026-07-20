extends CharacterBody3D
class_name PlayTestCharacterController

const MOVE_SPEED := 5.0


func _physics_process(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()
