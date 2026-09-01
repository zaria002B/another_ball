extends RigidBody3D
@onready var camera_3d: Camera3D = $"../Camera3D"

@export var speed := 5
@export var jump_velocity := 5
@export var camera_speed := 10
@export var air_friction := 1.01

func _process(delta: float):
 angular_velocity += speed * delta * Vector3(Input.get_axis("ui_up", "ui_down"), 0, Input.get_axis("ui_right", "ui_left"))
 if Input.is_action_just_pressed("ui_accept"): linear_velocity.y += jump_velocity
 angular_velocity /= air_friction
 camera_3d.position = lerp(camera_3d.position, position, camera_speed * delta)
