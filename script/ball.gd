extends RigidBody3D

## Rolling ball character controller.
## Attach this script to the root RigidBody3D of your Player scene.
## Expected child nodes:
##   CameraPivot (Node3D)
##     SpringArm3D
##       Camera3D
## Ground detection uses contact monitoring (see _integrate_forces below)
## rather than a raycast, since a raycast child would spin along with the
## ball's rolling rotation and only sweep past "straight down" occasionally.

@export_group("Movement")
@export var move_force: float = 18.0        # how hard we push the ball to roll
@export var max_speed: float = 9.0          # cap on horizontal speed
@export var air_control_multiplier: float = 0.3  # reduced force while airborne

@export_group("Jumping")
@export var jump_impulse: float = 6.5
@export var ground_normal_threshold: float = 0.5  # how "upward" a contact must be to count as ground

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0035
@export var min_pitch_deg: float = -60.0
@export var max_pitch_deg: float = 10.0

@onready var camera_pivot: Node3D = get_parent().get_node("CameraPivot")
@onready var spring_arm: SpringArm3D = camera_pivot.get_node("SpringArm3D")

var _can_jump: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Locking rotation is tempting for a "no wobble" feel, but we WANT the
	# ball's physics rotation so it looks like it's actually rolling.

	# Required for _integrate_forces to receive contact info each frame.
	contact_monitor = true
	max_contacts_reported = 8


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Ground check via contact normals instead of a raycast. A raycast child
	# would rotate along with the ball, so it'd only point "down" for a
	# fraction of each roll. Contact normals are reported in world space, so
	# this stays reliable no matter how the ball is spinning.
	_can_jump = false
	for i in state.get_contact_count():
		var normal: Vector3 = state.get_contact_local_normal(i)
		if normal.dot(Vector3.UP) > ground_normal_threshold:
			_can_jump = true
			break


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw rotates the whole pivot (and therefore movement direction).
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)

		# Pitch rotates only the spring arm, clamped so you can't flip over.
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation.x = clamp(
			spring_arm.rotation.x,
			deg_to_rad(min_pitch_deg),
			deg_to_rad(max_pitch_deg)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(_delta: float) -> void:
	# Keep the camera rig following the ball's position, but NOT its rolling
	# rotation (that's why CameraPivot is a sibling under Player, and we only
	# ever set rotation on it ourselves via mouse look, never copy the ball's).
	camera_pivot.global_position = global_position

	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")

	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()

		# Translate input into world space relative to where the camera is
		# facing, flattened onto the horizontal plane.
		var basis: Basis = camera_pivot.global_transform.basis
		var forward: Vector3 = -basis.z
		var right: Vector3 = basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()

		var direction: Vector3 = (forward * -input_dir.y + right * input_dir.x).normalized()

		var horizontal_speed := Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
		if horizontal_speed < max_speed:
			var force := move_force
			if not _can_jump:
				force *= air_control_multiplier
			apply_central_force(direction * force * mass)

	if Input.is_action_just_pressed("jump") and _can_jump:
		apply_central_impulse(Vector3.UP * jump_impulse)
		_can_jump = false
