extends CharacterBody3D
class_name CSLikePlayerController

## === Настройки движения === ##
@export_category("Movement Settings")
@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var crouch_speed: float = 3.0
@export var jump_velocity: float = 4.5
@export var air_accelerate: float = 0.5
@export var ground_accelerate: float = 2.0
@export var friction: float = 6.0
@export var gravity: float = 9.8
@export var crouch_depth: float = 0.5
@export var bunnyhop_speed_boost: float = 1.1

## === Настройки игрока === ##
@export_category("Player Settings")
@export var max_health: int = 100
@export var respawn_time: float = 3.0
@export var team: int = 0  # 0 - нет команды, 1 - красные, 2 - синие
@export var player_name: String = "Player"

## === Настройки камеры === ##
@export_category("Camera Settings")
@export var mouse_sensitivity: float = 0.1
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
var health: int = max_health
var is_dead: bool = false
var player_id: int = 0
var player_role: String = "player"
var bunnyhop_enabled: bool = false
var sync_timer: float = 0.0
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
const SYNC_INTERVAL: float = 0.1

## === Сигналы === ##
signal health_changed(new_health: int)
signal player_died()
signal player_respawned()
signal role_changed(new_role: String)
signal team_changed(new_team: int)

func _ready():
    initialize_network()
    setup_player()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func initialize_network():
    if multiplayer.has_multiplayer_peer():
        player_id = multiplayer.get_unique_id()
        set_multiplayer_authority(player_id)
        multiplayer.peer_connected.connect(_on_peer_connected)
        multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func setup_player():
    if is_multiplayer_authority():
        setup_local_player()
    else:
        setup_remote_player()
    
    name_label.text = player_name
    respawn_timer.timeout.connect(_on_respawn_timer_timeout)
    hitbox.body_entered.connect(_on_hitbox_body_entered)
    _check_player_role()

func setup_local_player():
    camera.current = true
    first_person_model.visible = true
    model.visible = false
    name_label.visible = false

func setup_remote_player():
    camera.current = false
    first_person_model.visible = false
    model.visible = true

func _physics_process(delta):
    if is_dead: return
    
    if is_multiplayer_authority():
        handle_movement(delta)
        handle_jump()
        handle_crouch()
        move_and_slide()
        update_network_state(delta)
    else:
        interpolate_state(delta)

func handle_movement(delta):
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    var target_speed = run_speed if is_running else walk_speed
    target_speed = crouch_speed if is_crouching else target_speed
    
    if is_on_floor():
        velocity.x = lerp(velocity.x, direction.x * target_speed, ground_accelerate * delta)
        velocity.z = lerp(velocity.z, direction.z * target_speed, ground_accelerate * delta)
    else:
        velocity.x = lerp(velocity.x, direction.x * target_speed, air_accelerate * delta)
        velocity.z = lerp(velocity.z, direction.z * target_speed, air_accelerate * delta)
    
    velocity.y -= gravity * delta

func handle_jump():
    if Input.is_action_just_pressed("jump") and is_on_floor():
        var speed_boost = 1.0
        if bunnyhop_enabled and Input.is_action_pressed("jump"):
            var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
            speed_boost = bunnyhop_speed_boost if horizontal_speed > run_speed * 0.8 else 1.0
        
        velocity.y = jump_velocity * speed_boost
        rpc("_play_jump_effect", speed_boost > 1.0)

@rpc("call_local", "reliable")
func _play_jump_effect(is_bunnyhop: bool):
    # Эффекты прыжка
    pass

func handle_crouch():
    if Input.is_action_just_pressed("crouch") and not is_crouching:
        start_crouch()
    elif Input.is_action_just_released("crouch") and is_crouching:
        end_crouch()

func start_crouch():
    is_crouching = true
    standing_collision.disabled = true
    crouching_collision.disabled = false
    camera_pivot.position.y -= crouch_depth
    rpc("_update_crouch_state", true)

func end_crouch():
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
        rpc("_update_crouch_state", false)

@rpc("call_local", "reliable")
func _update_crouch_state(crouching: bool):
    is_crouching = crouching
    standing_collision.disabled = crouching
    crouching_collision.disabled = not crouching
    camera_pivot.position.y = 0.0 if not crouching else -crouch_depth

func update_network_state(delta):
    sync_timer += delta
    if sync_timer >= SYNC_INTERVAL:
        sync_timer = 0
        rpc("_update_player_state", 
            global_position,
            velocity,
            Vector2(rotation.y, camera_pivot.rotation.x),
            is_crouching,
            is_running)

@rpc("any_peer", "reliable")
func _update_player_state(pos: Vector3, vel: Vector3, rot: Vector2, crouching: bool, running: bool):
    if not is_multiplayer_authority():
        target_position = pos
        velocity = vel
        target_rotation = Vector3(rot.y, rot.x, 0)
        is_crouching = crouching
        is_running = running

func interpolate_state(delta):
    global_position = global_position.lerp(target_position, 10 * delta)
    rotation.y = lerp_angle(rotation.y, target_rotation.y, 10 * delta)
    camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, target_rotation.x, 10 * delta)

func _input(event):
    if not is_multiplayer_authority() or is_dead: return
    
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * mouse_sensitivity * 0.01)
        camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity * 0.01)
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

func take_damage(amount: int, attacker_id: int, hit_position: Vector3):
    if is_dead or not is_multiplayer_authority(): return
    
    health -= amount
    health = clamp(health, 0, max_health)
    health_changed.emit(health)
    rpc("_play_hit_effect", hit_position)
    
    if health <= 0:
        die.rpc_id(1, attacker_id)

@rpc("call_local", "reliable")
func _play_hit_effect(position: Vector3):
    # Эффекты попадания
    pass

@rpc("call_local", "reliable")
func die(attacker_id: int):
    if is_dead: return
    
    is_dead = true
    health = 0
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
            take_damage(projectile.damage, projectile.shooter_id, projectile.global_position)
            body.queue_free()

func _on_respawn_timer_timeout():
    respawn.rpc_id(1)

func _on_peer_connected(id):
    print("Player connected: ", id)

func _on_peer_disconnected(id):
    print("Player disconnected: ", id)
    if multiplayer.is_server():
        # Обработка отключения игрока
        pass

@rpc("call_local", "reliable")
func set_player_role(role: String):
    player_role = role
    bunnyhop_enabled = role in ["vip", "admin", "developer"]
    role_changed.emit(role)
    update_visuals()

@rpc("call_local", "reliable")
func set_team(new_team: int):
    team = new_team
    team_changed.emit(new_team)
    update_visuals()

@rpc("call_local", "reliable")
func teleport_to(position: Vector3):
    global_position = position
    velocity = Vector3.ZERO
    target_position = position

func _check_player_role():
    if multiplayer.has_multiplayer_peer():
        if is_multiplayer_authority():
            # Запрос роли у сервера
            rpc_id(1, "_request_player_role", player_id)
    else:
        set_player_role("player")

@rpc("any_peer", "reliable")
func _request_player_role(id: int):
    if multiplayer.is_server():
        # Логика назначения роли на сервере
        var role = "player"
        if id == 123: role = "admin"
        elif id == 456: role = "vip"
        rpc_id(id, "set_player_role", role)

func update_visuals():
    match team:
        1: model.material_override.albedo_color = Color.RED
        2: model.material_override.albedo_color = Color.BLUE
        _: model.material_override.albedo_color = Color.WHITE
    
    $VIPCrown.visible = player_role in ["vip", "admin", "developer"]
