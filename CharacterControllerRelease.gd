extends CharacterBody3D
class_name CSLikePlayerController

## === Настройки движения === ##
@export_category("Movement Settings")
@export var walk_speed: float = 250.0
@export var run_speed: float = 300.0
@export var crouch_speed: float = 150.0
@export var jump_velocity: float = 8.0
@export var air_accelerate: float = 10.0
@export var ground_accelerate: float = 10.0
@export var friction: float = 4.0
@export var gravity: float = 20.0
@export var max_air_speed: float = 30.0
@export var crouch_depth: float = 0.5
@export var bunnyhop_speed_boost: float = 1.1

## === Настройки игрока === ##
@export_category("Player Settings")
@export var max_health: int = 100
@export var respawn_time: float = 3.0
@export var team: int = 0  # 0 - нет команды, 1 - красные, 2 - синие
@export var player_name: String = "Player"

## === Настройки мыши === ##
@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.3
@export var max_look_angle: float = 90.0
@export var min_look_angle: float = -90.0

## === Компоненты === ##
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var standing_collision: CollisionShape3D = $StandingCollision
@onready var crouching_collision: CollisionShape3D = $CrouchingCollision
@onready var weapon_system: Node = $WeaponSystem
@onready var hitbox: Area3D = $Hitbox
@onready var respawn_timer: Timer = $RespawnTimer
@onready var name_label: Label3D = $NameLabel
@onready var model: MeshInstance3D = $CharacterModel
@onready var first_person_model: Node3D = $CameraPivot/FirstPersonModel

## === Переменные === ##
var is_crouching: bool = false
var is_running: bool = false
var wish_dir: Vector3 = Vector3.ZERO
var player_id: int = 0
var player_role: String = "player"
var bunnyhop_enabled: bool = false
var health: int = max_health
var is_dead: bool = false
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.1

## === Сигналы === ##
signal health_changed(new_health: int)
signal player_died()
signal player_respawned()
signal role_changed(new_role: String)
signal team_changed(new_team: int)

func _ready():
    # Инициализация сети
    if multiplayer.has_multiplayer_peer():
        player_id = multiplayer.get_unique_id()
        set_multiplayer_authority(player_id)
        
        if is_multiplayer_authority():
            _setup_local_player()
        else:
            _setup_remote_player()
    
    _initialize_player()
    update_visuals()

func _setup_local_player():
    camera.current = true
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    name_label.visible = false
    first_person_model.visible = true
    model.visible = false

func _setup_remote_player():
    camera.current = false
    first_person_model.visible = false
    model.visible = true

func _initialize_player():
    respawn_timer.timeout.connect(_on_respawn_timer_timeout)
    hitbox.body_entered.connect(_on_hitbox_body_entered)
    name_label.text = player_name

func _physics_process(delta):
    if is_dead:
        return
    
    if is_multiplayer_authority():
        _handle_movement(delta)
        _handle_jump()
        _handle_crouch()
        move_and_slide()
        
        _sync_player_state(delta)
    else:
        _interpolate_player_state(delta)

func _handle_movement(delta: float):
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    wish_dir = Vector3(direction.x, 0, direction.z)
    
    var target_speed = walk_speed
    if is_running and not is_crouching:
        target_speed = run_speed
    elif is_crouching:
        target_speed = crouch_speed
    
    if is_on_floor():
        _accelerate(delta, target_speed, ground_accelerate)
        _apply_friction(delta)
    else:
        _accelerate(delta, max_air_speed, air_accelerate)
        velocity.y -= gravity * delta

func _accelerate(delta: float, target_speed: float, accel: float):
    var current_speed = velocity.dot(wish_dir)
    var add_speed = target_speed - current_speed
    
    if add_speed > 0:
        var accel_speed = accel * target_speed * delta
        velocity.x += accel_speed * wish_dir.x
        velocity.z += accel_speed * wish_dir.z

func _apply_friction(delta: float):
    var speed = velocity.length()
    if speed > 0.1:
        var control = max(speed, walk_speed if is_on_floor() else air_accelerate)
        var new_speed = max(speed - control * friction * delta, 0) / speed
        velocity *= new_speed
    else:
        velocity = Vector3.ZERO

func _handle_jump():
    if is_on_floor() and Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity * (bunnyhop_speed_boost if bunnyhop_enabled and Input.is_action_pressed("jump") else 1.0)
        _play_jump_effect.rpc()

func _handle_crouch():
    if Input.is_action_just_pressed("crouch") and not is_crouching:
        _start_crouch()
    elif Input.is_action_just_released("crouch") and is_crouching:
        _end_crouch()

func _start_crouch():
    is_crouching = true
    standing_collision.disabled = true
    crouching_collision.disabled = false
    camera_pivot.position.y -= crouch_depth
    _update_crouch_state.rpc(true)

func _end_crouch():
    var space = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.UP * (standing_collision.shape.height + 0.1)
    )
    if not space.intersect_ray(query):
        is_crouching = false
        standing_collision.disabled = false
        crouching_collision.disabled = true
        camera_pivot.position.y += crouch_depth
        _update_crouch_state.rpc(false)

@rpc("call_local", "reliable")
func _update_crouch_state(crouching: bool):
    is_crouching = crouching
    standing_collision.disabled = crouching
    crouching_collision.disabled = not crouching
    camera_pivot.position.y = 0.0 if not crouching else -crouch_depth

func _sync_player_state(delta: float):
    sync_timer += delta
    if sync_timer >= SYNC_INTERVAL:
        sync_timer = 0
        _update_player_state.rpc(
            global_position,
            velocity,
            camera_pivot.rotation,
            is_on_floor(),
            is_crouching,
            is_running
        )

func _interpolate_player_state(delta: float):
    global_position = global_position.lerp(target_position, 10.0 * delta)
    rotation.y = lerp_angle(rotation.y, target_rotation.y, 10.0 * delta)
    camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, target_rotation.x, 10.0 * delta)

@rpc("any_peer", "reliable")
func _update_player_state(pos: Vector3, vel: Vector3, cam_rot: Vector3, grounded: bool, crouching: bool, running: bool):
    if not is_multiplayer_authority():
        target_position = pos
        velocity = vel
        target_rotation = Vector3(cam_rot.x, rotation.y, rotation.z)
        is_crouching = crouching
        is_running = running

func take_damage(amount: int, attacker_id: int):
    if is_dead or not is_multiplayer_authority():
        return
    
    health -= amount
    health = max(health, 0)
    health_changed.emit(health)
    
    if health <= 0:
        die.rpc_id(1, attacker_id)

@rpc("call_local", "reliable")
func die(attacker_id: int):
    if is_dead:
        return
    
    is_dead = true
    standing_collision.disabled = true
    crouching_collision.disabled = true
    visible = false
    respawn_timer.start(respawn_time)
    player_died.emit()

@rpc("call_local", "reliable")
func respawn():
    is_dead = false
    health = max_health
    standing_collision.disabled = false
    crouching_collision.disabled = true
    visible = true
    player_respawned.emit()

func _on_hitbox_body_entered(body: Node):
    if body.is_in_group("projectile") and is_multiplayer_authority() and not is_dead:
        var projectile = body as Projectile
        if projectile and (projectile.team == 0 or projectile.team != team):
            take_damage(projectile.damage, projectile.shooter_id)
            body.queue_free()

func update_visuals():
    match team:
        1: model.material_override.albedo_color = Color.RED
        2: model.material_override.albedo_color = Color.BLUE
        _: model.material_override.albedo_color = Color.WHITE
    
    $VIPCrown.visible = player_role in ["vip", "admin", "developer"]

@rpc("call_local", "reliable")
func set_player_role(role: String):
    player_role = role
    bunnyhop_enabled = role in ["vip", "admin", "developer"]
    update_visuals()
    role_changed.emit(role)

@rpc("call_local", "reliable")
func set_team(new_team: int):
    team = new_team
    update_visuals()
    team_changed.emit(new_team)

func _input(event):
    if is_multiplayer_authority() and not is_dead:
        if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            rotate_y(-event.relative.x * mouse_sensitivity * 0.001)
            camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity * 0.001)
            camera_pivot.rotation.x = clamp(
                camera_pivot.rotation.x,
                deg_to_rad(min_look_angle),
                deg_to_rad(max_look_angle)
            )
        
        if event.is_action_pressed("run"):
            is_running = true
        elif event.is_action_released("run"):
            is_running = false
        
        if event.is_action_pressed("shoot"):
            weapon_system.shoot.rpc_id(1)
