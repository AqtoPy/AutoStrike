extends CharacterBody3D

# Movement settings
@export_category("Movement Settings")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var air_control: float = 0.3
@export var acceleration: float = 10.0
@export var friction: float = 8.0
@export var gravity: float = 9.8
@export var crouch_height: float = 1.0
@export var stand_height: float = 1.8

# Mouse settings
@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.2
@export var max_look_angle: float = 89.0
@export var min_look_angle: float = -89.0

# Components
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var standing_collider: CollisionShape3D = $StandingCollider
@onready var crouching_collider: CollisionShape3D = $CrouchingCollider
@onready var player_mesh: MeshInstance3D = $PlayerMesh
@onready var nickname_label: Label3D = $NicknameLabel

# Player state
var current_speed: float = 0.0
var is_sprinting: bool = false
var is_crouching: bool = false
var is_grounded: bool = false
var movement_direction: Vector3 = Vector3.ZERO
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.1  # 10 times per second

func _enter_tree():
    # Set multiplayer authority based on node name
    if multiplayer.has_multiplayer_peer():
        set_multiplayer_authority(str(name).to_int())

func _ready():
    # Initialize player
    if is_multiplayer_authority():
        # Setup for local player
        camera.current = true
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        player_mesh.visible = false  # Hide own mesh
    else:
        # Setup for remote players
        camera.current = false
        set_process_input(false)
        player_mesh.visible = true
    
    # Initialize collision shape
    standing_collider.disabled = is_crouching
    crouching_collider.disabled = not is_crouching
    nickname_label.visible = not is_multiplayer_authority()

func _physics_process(delta):
    if not is_multiplayer_authority():
        return
    
    # Handle movement
    _handle_movement_input(delta)
    _handle_gravity(delta)
    _handle_jump()
    _handle_crouch()
    
    # Apply movement
    move_and_slide()
    is_grounded = is_on_floor()
    
    # Network sync
    sync_timer += delta
    if sync_timer >= SYNC_INTERVAL:
        sync_timer = 0.0
        _sync_player_state()

func _handle_movement_input(delta):
    # Get input direction
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    movement_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Determine target speed
    var target_speed = walk_speed
    if is_sprinting and not is_crouching:
        target_speed = sprint_speed
    elif is_crouching:
        target_speed = crouch_speed
    
    # Calculate acceleration
    var current_velocity = Vector3(velocity.x, 0, velocity.z)
    var target_velocity = movement_direction * target_speed
    
    if is_grounded:
        # Ground movement with friction
        current_velocity = current_velocity.lerp(target_velocity, acceleration * delta)
        current_velocity = current_velocity.move_toward(Vector3.ZERO, friction * delta)
    else:
        # Air movement with less control
        current_velocity = current_velocity.lerp(target_velocity, air_control * acceleration * delta)
    
    velocity.x = current_velocity.x
    velocity.z = current_velocity.z

func _handle_gravity(delta):
    if not is_grounded:
        velocity.y -= gravity * delta

func _handle_jump():
    if Input.is_action_just_pressed("jump") and is_grounded and not is_crouching:
        velocity.y = jump_velocity

func _handle_crouch():
    if Input.is_action_pressed("crouch") and not is_crouching:
        _start_crouch()
    elif not Input.is_action_pressed("crouch") and is_crouching and _can_stand_up():
        _end_crouch()

func _start_crouch():
    is_crouching = true
    standing_collider.disabled = true
    crouching_collider.disabled = false
    camera_pivot.position.y -= (stand_height - crouch_height)
    _sync_crouch_state.rpc(true)

func _end_crouch():
    is_crouching = false
    standing_collider.disabled = false
    crouching_collider.disabled = true
    camera_pivot.position.y += (stand_height - crouch_height)
    _sync_crouch_state.rpc(false)

func _can_stand_up() -> bool:
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.UP * stand_height,
        0xFFFFFFFF
    )
    return space_state.intersect_ray(query).is_empty()

func _sync_player_state():
    rpc("_remote_update_state", 
        global_position,
        Vector2(rotation.y, camera_pivot.rotation.x),
        is_crouching)

@rpc("unreliable", "any_peer")
func _remote_update_state(pos: Vector3, rot: Vector2, crouching: bool):
    if not is_multiplayer_authority():
        global_position = pos
        rotation.y = rot.x
        camera_pivot.rotation.x = rot.y
        
        if crouching != is_crouching:
            if crouching:
                _start_crouch()
            else:
                _end_crouch()

@rpc("call_local")
func _sync_crouch_state(crouching: bool):
    if crouching:
        _start_crouch()
    else:
        _end_crouch()

func _input(event):
    if not is_multiplayer_authority():
        return
    
    # Mouse look
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
        camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
        camera_pivot.rotation.x = clamp(
            camera_pivot.rotation.x,
            deg_to_rad(min_look_angle),
            deg_to_rad(max_look_angle)
        )
    
    # Sprint toggle
    if event.is_action_pressed("sprint"):
        is_sprinting = true
    if event.is_action_released("sprint"):
        is_sprinting = false
    
    # Mouse capture toggle
    if event.is_action_pressed("ui_cancel"):
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Network functions
@rpc("call_local")
func set_player_nickname(new_nickname: String):
    player_nickname = new_nickname
    nickname_label.text = new_nickname

@rpc("call_local")
func teleport_to(position: Vector3):
    global_position = position
    velocity = Vector3.ZERO
