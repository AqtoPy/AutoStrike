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

## === Настройки мыши === ##
@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.3
@export var max_look_angle: float = 90.0
@export var min_look_angle: float = -90.0

## === Компоненты === ##
@onready var camera_pivot = %Camera
@onready var camera = %MainCamera
@onready var standing_collision = $BodyCollision
@onready var crouching_collision = $CrouchingCollision
@onready var weapon_system = $Camera/LeanPivot/MainCamera/Weapons_Manager
@onready var hitbox = $HitBox
@onready var respawn_timer = $RespawnTimer

## === Переменные === ##
var current_speed: float = 0.0
var is_crouching: bool = false
var is_running: bool = false
var wish_dir: Vector3 = Vector3.ZERO
var player_id: int = 0
var player_role: String = "player"
var bunnyhop_enabled: bool = false
var is_grounded: bool = false
var was_grounded: bool = false
var move_direction: Vector3 = Vector3.ZERO
var last_velocity: Vector3 = Vector3.ZERO
var health: int = max_health
var is_dead: bool = false
var jump_pressed: bool = false
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.1

## === Сигналы === ##
signal health_changed(new_health: int)
signal player_died()
signal player_respawned()
signal role_changed(new_role: String)

func _ready():
    # Инициализация сетевого игрока
    if multiplayer.has_multiplayer_peer():
        player_id = multiplayer.get_unique_id()
        set_multiplayer_authority(player_id)
        
        if is_multiplayer_authority():
            camera.current = true
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    _check_player_role()
    target_position = global_transform.origin
    target_rotation = rotation
    respawn_timer.timeout.connect(_on_respawn_timer_timeout)
    hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta):
    if is_dead:
        return
    
    jump_pressed = Input.is_action_pressed("jump")
    
    if is_multiplayer_authority():
        _handle_movement(delta)
        _handle_jump()
        _handle_crouch()
        move_and_slide()
        
        # Синхронизация состояния
        sync_timer += delta
        if sync_timer >= SYNC_INTERVAL:
            sync_timer = 0
            rpc("_update_player_state", 
                global_transform.origin,
                velocity,
                camera_pivot.rotation,
                is_grounded,
                is_crouching,
                is_running)
    else:
        # Интерполяция для других игроков
        global_transform.origin = global_transform.origin.lerp(target_position, 10.0 * delta)
        rotation.y = lerp_angle(rotation.y, target_rotation.y, 10.0 * delta)
        camera_pivot.rotation.x = lerp(camera_pivot.rotation.x, target_rotation.x, 10.0 * delta)
    
    was_grounded = is_grounded
    is_grounded = is_on_floor()

func _handle_jump():
    if is_grounded:
        # Автоматический прыжок при Bunnyhop
        if bunnyhop_enabled and jump_pressed:
            _perform_jump(true)
        # Обычный прыжок
        elif Input.is_action_just_pressed("jump"):
            _perform_jump(false)

func _perform_jump(is_bunnyhop: bool):
    var speed_boost = 1.0
    if is_bunnyhop:
        var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
        speed_boost = bunnyhop_speed_boost if horizontal_speed > run_speed * 0.8 else 1.0
    
    velocity.y = jump_velocity * speed_boost
    rpc("_play_jump_effect", is_bunnyhop)

@rpc("call_local")
func _play_jump_effect(is_bunnyhop: bool):
    # Здесь можно добавить эффекты прыжка
    pass

func _handle_movement(delta):
    var input_dir = Input.get_vector("left", "right", "up", "down")
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

func _accelerate(delta: float, target_speed: float, accel: float):
    var current_speed = velocity.dot(wish_dir)
    var add_speed = target_speed - current_speed
    
    if add_speed <= 0:
        return
    
    var accel_speed = accel * target_speed * delta
    accel_speed = min(accel_speed, add_speed)
    
    velocity.x += accel_speed * wish_dir.x
    velocity.z += accel_speed * wish_dir.z

func _apply_friction(delta: float):
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

func _handle_crouch():
    if Input.is_action_pressed("crouch") and not is_crouching:
        _start_crouch()
    elif not Input.is_action_pressed("crouch") and is_crouching:
        _end_crouch()

func _start_crouch():
    is_crouching = true
    standing_collision.disabled = true
    crouching_collision.disabled = false
    camera_pivot.position.y -= crouch_depth
    rpc("_update_crouch_state", true)

func _end_crouch():
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.UP * (standing_collision.shape.height + 0.1),
        1 << 0
    )
    var result = space_state.intersect_ray(query)
    
    if result.is_empty():
        is_crouching = false
        standing_collision.disabled = false
        crouching_collision.disabled = true
        camera_pivot.position.y += crouch_depth
        rpc("_update_crouch_state", false)

@rpc("call_local")
func _update_crouch_state(crouching: bool):
    is_crouching = crouching
    standing_collision.disabled = crouching
    crouching_collision.disabled = not crouching
    camera_pivot.position.y = 0.0 if not crouching else -crouch_depth

func _input(event):
    if not is_multiplayer_authority() or is_dead:
        return
    
    # Управление камерой
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
        camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
        camera_pivot.rotation.x = clamp(
            camera_pivot.rotation.x,
            deg_to_rad(min_look_angle),
            deg_to_rad(max_look_angle)
        )
    
    # Бег
    if event.is_action_pressed("run"):
        is_running = true
    if event.is_action_released("run"):
        is_running = false
    
    # Взаимодействие с оружием
    if event.is_action_pressed("Shoot"):
        weapon_system.request_shoot.rpc_id(1)

@rpc("call_local")
func set_player_role(role: String):
    player_role = role
    bunnyhop_enabled = role in ["vip", "admin", "developer"]
    role_changed.emit(role)

@rpc("call_local")
func teleport_to(position: Vector3):
    global_transform.origin = position
    velocity = Vector3.ZERO

@rpc("reliable")
func _update_player_state(pos: Vector3, vel: Vector3, cam_rot: Vector3, 
                        grounded: bool, crouching: bool, running: bool):
    if not is_multiplayer_authority():
        target_position = pos
        velocity = vel
        target_rotation = Vector3(cam_rot.x, rotation.y, rotation.z)
        is_grounded = grounded
        is_crouching = crouching
        is_running = running

func take_damage(amount: int, attacker_id: int, hit_position: Vector3):
    if is_dead or not is_multiplayer_authority():
        return
    
    health -= amount
    health_changed.emit(health)
    
    # Эффекты попадания
    rpc("_play_hit_effect", hit_position)
    
    if health <= 0:
        die.rpc_id(1, attacker_id)  # Отправляем на сервер

@rpc("call_local")
func _play_hit_effect(position: Vector3):
    # Здесь можно добавить эффекты попадания
    pass

@rpc("call_local", "reliable")
func die(attacker_id: int):
    if is_dead:
        return
    
    is_dead = true
    health = 0
    health_changed.emit(health)
    player_died.emit()
    
    # Отключаем коллизии и видимость
    standing_collision.disabled = true
    crouching_collision.disabled = true
    visible = false
    
    # Запускаем таймер возрождения
    respawn_timer.start(respawn_time)

func _on_respawn_timer_timeout():
    respawn.rpc_id(1)  # Запрос на сервер для возрождения

@rpc("call_local", "reliable")
func respawn():
    is_dead = false
    health = max_health
    health_changed.emit(health)
    player_respawned.emit()
    
    # Включаем коллизии и видимость
    standing_collision.disabled = false
    crouching_collision.disabled = true
    visible = true
    
    # Сбрасываем состояние
    is_crouching = false
    is_running = false

func _on_hitbox_body_entered(body: Node):
    if body.is_in_group("Projectile") and is_multiplayer_authority() and not is_dead:
        var projectile = body as Projectile
        take_damage(projectile.damage, projectile.shooter_id, projectile.global_position)
        projectile.queue_free()

func _check_player_role():
    # Здесь должна быть проверка роли игрока через сервер
    # Для примера жестко задаем
    if player_id == 123:
        set_player_role("developer")
    elif player_id == 456:
        set_player_role("vip")
