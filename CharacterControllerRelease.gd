extends CharacterBody3D
class_name CSLikePlayerController

## === Movement Settings === ##
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

## === Player Settings === ##
@export_category("Player Settings")
@export var max_health: int = 100
@export var respawn_time: float = 3.0
@export var team: int = 0  # 0 - no team, 1 - red, 2 - blue

## === Mouse Settings === ##
@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.3
@export var max_look_angle: float = 90.0
@export var min_look_angle: float = -90.0

## === Components === ##
@onready var camera_pivot: Node3D = %Camera
@onready var camera: Camera3D = %MainCamera
@onready var standing_collision: CollisionShape3D = $BodyCollision
@onready var crouching_collision: CollisionShape3D = $CrouchingCollision
@onready var weapon_system: Node = $Camera/LeanPivot/MainCamera/Weapons_Manager
@onready var hitbox: Area3D = $Area3D
@onready var respawn_timer: Timer = $RespawnTimer
@onready var name_label: Label3D = $NameLabel
@onready var model: Node3D = $CharacterModel

## === Variables === ##
var current_speed: float = 0.0
var is_crouching: bool = false
var is_running: bool = false
var wish_dir: Vector3 = Vector3.ZERO
var player_id: int = 0
var player_role: String = "player"
var bunnyhop_enabled: bool = false
var is_grounded: bool = false
var was_grounded: bool = false
var health: int = max_health
var is_dead: bool = false
var jump_pressed: bool = false
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.1
var player_name: String = "Player"
var ping: int = 0
var last_damage_source: int = 0

## === Signals === ##
signal health_changed(new_health: int)
signal player_died()
signal player_respawned()
signal role_changed(new_role: String)
signal team_changed(new_team: int)

func _ready():
    # Network initialization
    if multiplayer.has_multiplayer_peer():
        player_id = multiplayer.get_unique_id()
        set_multiplayer_authority(player_id)
        
        if is_multiplayer_authority():
            camera.current = true
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            name_label.visible = false
        else:
            # For other players, hide first person elements
            $Camera/LeanPivot/MainCamera/FirstPersonModel.visible = false
    
    _check_player_role()
    target_position = global_position
    target_rotation = rotation
    
    # Connections
    respawn_timer.timeout.connect(_on_respawn_timer_timeout)
    hitbox.body_entered.connect(_on_hitbox_body_entered)
    
    # Initial setup
    update_visuals()

func start_network_as_client(ip: String, port: int) -> void:
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(ip, port)
    if error == OK:
        multiplayer.multiplayer_peer = peer
    else:
        push_error("Failed to create client: " + str(error))

func start_network_as_server(port: int) -> void:
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(port)
    if error == OK:
        multiplayer.multiplayer_peer = peer
    else:
        push_error("Failed to create server: " + str(error))

func _physics_process(delta: float) -> void:
    if is_dead:
        return
    
    # Handle input only for local player
    if is_multiplayer_authority():
        jump_pressed = Input.is_action_pressed("jump")
        
        _handle_movement(delta)
        _handle_jump()
        _handle_crouch()
        move_and_slide()
        
        # Network synchronization
        if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
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
    else:
        # Interpolation for other players
        global_position = global_position.lerp(target_position, 10.0 * delta)
        rotation.y = lerp_angle(rotation.y, target_rotation.y, 10.0 * delta)
        camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, target_rotation.x, 10.0 * delta)
    
    was_grounded = is_grounded
    is_grounded = is_on_floor()

func _handle_jump() -> void:
    if is_grounded:
        # Bunnyhop auto-jump
        if bunnyhop_enabled and jump_pressed:
            _perform_jump(true)
        # Normal jump
        elif Input.is_action_just_pressed("jump"):
            _perform_jump(false)

func _perform_jump(is_bunnyhop: bool) -> void:
    var speed_boost = 1.0
    if is_bunnyhop:
        var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
        speed_boost = bunnyhop_speed_boost if horizontal_speed > run_speed * 0.8 else 1.0
    
    velocity.y = jump_velocity * speed_boost
    _play_jump_effect.rpc(is_bunnyhop)

@rpc("call_local", "reliable")
func _play_jump_effect(is_bunnyhop: bool) -> void:
    # Add jump effects here (particles, sounds)
    $JumpSound.play()
    if is_bunnyhop:
        $BunnyhopParticles.emitting = true

func _handle_movement(delta: float) -> void:
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    wish_dir = Vector3(direction.x, 0, direction.z)
    
    var target_speed = walk_speed
    if is_running and not is_crouching:
        target_speed = run_speed
    elif is_crouching:
        target_speed = crouch_speed
    
    if is_grounded:
        _accelerate(delta, target_speed, ground_accelerate)
        _apply_friction(delta)
    else:
        _accelerate(delta, max_air_speed, air_accelerate)
    
    if not is_grounded:
        velocity.y -= gravity * delta

func _accelerate(delta: float, target_speed: float, accel: float) -> void:
    var current_speed = velocity.dot(wish_dir)
    var add_speed = target_speed - current_speed
    
    if add_speed <= 0:
        return
    
    var accel_speed = accel * target_speed * delta
    accel_speed = min(accel_speed, add_speed)
    
    velocity.x += accel_speed * wish_dir.x
    velocity.z += accel_speed * wish_dir.z

func _apply_friction(delta: float) -> void:
    var speed = velocity.length()
    
    if speed < 0.1:
        velocity = Vector3.ZERO
        return
    
    var control = max(speed, walk_speed if is_grounded else air_accelerate)
    var drop = control * friction * delta
    
    var new_speed = max(speed - drop, 0)
    if new_speed > 0:
        new_speed /= speed
    
    velocity *= new_speed

func _handle_crouch() -> void:
    if Input.is_action_pressed("crouch") and not is_crouching:
        _start_crouch()
    elif not Input.is_action_pressed("crouch") and is_crouching:
        _end_crouch()

func _start_crouch() -> void:
    is_crouching = true
    standing_collision.disabled = true
    crouching_collision.disabled = false
    camera_pivot.position.y -= crouch_depth
    _update_crouch_state.rpc(true)

func _end_crouch() -> void:
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.UP * (standing_collision.shape.height + 0.1),
        0xFFFFFFFF  # All layers
    )
    var result = space_state.intersect_ray(query)
    
    if result.is_empty():
        is_crouching = false
        standing_collision.disabled = false
        crouching_collision.disabled = true
        camera_pivot.position.y += crouch_depth
        _update_crouch_state.rpc(false)

@rpc("call_local", "reliable")
func _update_crouch_state(crouching: bool) -> void:
    is_crouching = crouching
    standing_collision.disabled = crouching
    crouching_collision.disabled = not crouching
    camera_pivot.position.y = 0.0 if not crouching else -crouch_depth

func _input(event: InputEvent) -> void:
    if not is_multiplayer_authority() or is_dead:
        return
    
    # Camera control
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
        camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
        camera_pivot.rotation.x = clamp(
            camera_pivot.rotation.x,
            deg_to_rad(min_look_angle),
            deg_to_rad(max_look_angle)
        )
    
    # Running
    if event.is_action_pressed("run"):
        is_running = true
    if event.is_action_released("run"):
        is_running = false
    
    # Weapon interaction
    if event.is_action_pressed("shoot"):
        weapon_system.shoot.rpc_id(1)  # Send to server

@rpc("call_local", "reliable")
func set_player_name(new_name: String) -> void:
    player_name = new_name
    name_label.text = new_name
    update_visuals()

@rpc("call_local", "reliable")
func set_player_role(role: String) -> void:
    player_role = role
    bunnyhop_enabled = role in ["vip", "admin", "developer"]
    role_changed.emit(role)
    update_visuals()

@rpc("call_local", "reliable")
func set_team(new_team: int) -> void:
    team = new_team
    team_changed.emit(new_team)
    update_visuals()

@rpc("call_local", "reliable")
func teleport_to(position: Vector3) -> void:
    global_position = position
    velocity = Vector3.ZERO
    target_position = position

@rpc("any_peer", "reliable")
func _update_player_state(pos: Vector3, vel: Vector3, cam_rot: Vector3, 
                        grounded: bool, crouching: bool, running: bool) -> void:
    if not is_multiplayer_authority() and multiplayer.has_multiplayer_peer():
        target_position = pos
        velocity = vel
        target_rotation = Vector3(cam_rot.x, rotation.y, rotation.z)
        is_grounded = grounded
        is_crouching = crouching
        is_running = running

func take_damage(amount: int, attacker_id: int, hit_position: Vector3) -> void:
    if is_dead or not is_multiplayer_authority():
        return
    
    health -= amount
    health = max(health, 0)
    last_damage_source = attacker_id
    health_changed.emit(health)
    
    # Hit effects
    _play_hit_effect.rpc(hit_position)
    
    if health <= 0:
        die.rpc_id(1, attacker_id)  # Send to server

@rpc("call_local", "reliable")
func _play_hit_effect(position: Vector3) -> void:
    # Add hit effects here
    $HitSound.play()
    var particles = $HitParticles.duplicate()
    add_child(particles)
    particles.global_position = position
    particles.emitting = true
    particles.finished.connect(particles.queue_free)

@rpc("any_peer", "call_local", "reliable")
func die(attacker_id: int) -> void:
    if is_dead:
        return
    
    is_dead = true
    health = 0
    health_changed.emit(health)
    player_died.emit()
    
    # Disable collisions and visibility
    standing_collision.disabled = true
    crouching_collision.disabled = true
    visible = false
    
    # Start respawn timer
    respawn_timer.start(respawn_time)
    
    # Death effects
    $DeathSound.play()
    $DeathParticles.emitting = true

func _on_respawn_timer_timeout() -> void:
    respawn.rpc_id(1)  # Request server for respawn

@rpc("any_peer", "call_local", "reliable")
func respawn() -> void:
    is_dead = false
    health = max_health
    health_changed.emit(health)
    player_respawned.emit()
    
    # Enable collisions and visibility
    standing_collision.disabled = false
    crouching_collision.disabled = true
    visible = true
    
    # Reset state
    is_crouching = false
    is_running = false
    
    # Respawn effects
    $RespawnSound.play()
    $RespawnParticles.emitting = true

func _on_hitbox_body_entered(body: Node) -> void:
    if body.is_in_group("projectile") and is_multiplayer_authority() and not is_dead:
        var projectile: Projectile = body as Projectile
        if projectile:
            # Team damage check
            if projectile.team != 0 and projectile.team == team:
                return
                
            take_damage(projectile.damage, projectile.shooter_id, projectile.global_position)
            projectile.queue_free()

func _check_player_role() -> void:
    # This should be replaced with actual server request
    if multiplayer.has_multiplayer_peer():
        if is_multiplayer_authority():
            # Request role from server
            get_node("/root/Game").request_player_role.rpc_id(1, player_id)
    else:
        # Single player mode
        set_player_role("player")

func update_visuals() -> void:
    # Update player appearance based on role/team
    match team:
        1:  # Red team
            model.get_surface_override_material(0).albedo_color = Color.RED
        2:  # Blue team
            model.get_surface_override_material(0).albedo_color = Color.BLUE
        _:  # No team/default
            model.get_surface_override_material(0).albedo_color = Color.WHITE
    
    # VIP/admin visuals
    if player_role in ["vip", "admin", "developer"]:
        $VIPCrown.visible = true
    else:
        $VIPCrown.visible = false
