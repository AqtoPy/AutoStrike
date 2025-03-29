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

## === Настройки мыши === ##
@export_category("Mouse Settings")
@export var mouse_sensitivity: float = 0.3
@export var max_look_angle: float = 90.0
@export var min_look_angle: float = -90.0

## === Компоненты === ##
@onready var camera_pivot = $CameraPivot
@onready var camera = $CameraPivot/Camera3D
@onready var standing_collision = $StandingCollision
@onready var crouching_collision = $CrouchingCollision
@onready var weapon_system = $WeaponSystem

## === Переменные === ##
var current_speed: float = 0.0
var is_crouching: bool = false
var is_running: bool = false
var wish_dir: Vector3 = Vector3.ZERO
var player_id: String = ""
var player_role: String = "player" # player/vip/admin/developer
var bunnyhop_enabled: bool = false
var is_grounded: bool = false
var was_grounded: bool = false
var move_direction: Vector3 = Vector3.ZERO
var last_velocity: Vector3 = Vector3.ZERO

func _ready():
    # Настройки для онлайн-режима
    if multiplayer.is_server():
        player_id = str(multiplayer.get_unique_id())
    else:
        player_id = "local_player"
    
    # Проверка роли игрока (должно приходить с сервера)
    _check_player_role()
    
    # Скрываем курсор
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _check_player_role():
    # Здесь должна быть проверка роли игрока через сервер
    # Для примера жестко задаем
    if player_id == "developer_123":
        player_role = "developer"
        bunnyhop_enabled = true
    elif player_id == "vip_456":
        player_role = "vip"
        bunnyhop_enabled = true

func _physics_process(delta):
    if not multiplayer.is_server() and not is_multiplayer_authority():
        return
    
    _handle_movement(delta)
    _handle_jump()
    _handle_crouch()
    
    # Применяем движение
    move_and_slide()
    
    # Обновляем состояние на земле
    was_grounded = is_grounded
    is_grounded = is_on_floor()
    
    # Синхронизация позиции для мультиплеера
    if multiplayer.is_server():
        rpc("_update_position", global_transform.origin)

@rpc("reliable", "any_peer")
func _update_position(new_position: Vector3):
    if not is_multiplayer_authority():
        global_transform.origin = new_position

func _handle_movement(delta):
    # Получаем ввод
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Определяем желаемое направление
    wish_dir = Vector3(direction.x, 0, direction.z)
    
    # Выбираем скорость в зависимости от состояния
    var target_speed = walk_speed
    if is_running and not is_crouching:
        target_speed = run_speed
    elif is_crouching:
        target_speed = crouch_speed
    
    # Применяем ускорение
    if is_grounded:
        _accelerate(delta, target_speed, ground_accelerate)
        _apply_friction(delta)
    else:
        _accelerate(delta, max_air_speed, air_accelerate)
    
    # Применяем гравитацию
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

func _handle_jump():
    if Input.is_action_just_pressed("jump") and is_grounded:
        velocity.y = jump_velocity
        
        # Bunnyhop для VIP/разработчиков
        if bunnyhop_enabled and Input.is_action_pressed("jump"):
            var speed = Vector3(velocity.x, 0, velocity.z).length()
            if speed > run_speed * 0.8:
                velocity.y = jump_velocity * 1.1

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

func _end_crouch():
    # Проверяем, есть ли место над головой
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

func _input(event):
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
    if event.is_action_pressed("shoot"):
        weapon_system.shoot.rpc_id(1)  # Отправляем на сервер

@rpc("call_local")
func set_player_role(role: String):
    player_role = role
    bunnyhop_enabled = role in ["vip", "admin", "developer"]
    print("Player role set to: ", role, " | Bunnyhop: ", bunnyhop_enabled)

@rpc("call_local")
func teleport_to(position: Vector3):
    global_transform.origin = position
    velocity = Vector3.ZERO

# Сетевые функции для синхронизации
func _on_movement_state_changed():
    rpc("_update_movement_state", velocity, is_grounded, is_crouching)

@rpc("reliable", "any_peer")
func _update_movement_state(new_velocity: Vector3, new_grounded: bool, new_crouching: bool):
    if not is_multiplayer_authority():
        velocity = new_velocity
        is_grounded = new_grounded
        is_crouching = new_crouching
