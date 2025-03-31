extends Node3D
class_name WeaponManager

## === Сигналы === ##
signal weapon_changed(weapon_name: String)
signal update_ammo(current: int, reserve: int)
signal update_weapon_stack(weapons: Array)
signal hit_successful(damage: float, position: Vector3)
signal hud_ammo_update(current: int, reserve: int)
signal hud_weapon_added(weapon: WeaponResource)

## === Настройки оружия === ##
@export_category("Weapon Settings")
@export var animation_player: AnimationPlayer
@export var melee_hitbox: ShapeCast3D
@export var max_weapons: int = 3
@export var network_update_rate: float = 0.1

## === Компоненты === ##
@onready var bullet_point = %BulletPoint
@onready var debug_bullet = preload("res://Player_Controller/Spawnable_Objects/hit_debug.tscn")

## === Переменные === ##
var weapon_stack: Array[WeaponSlot] = []
var current_weapon_slot: WeaponSlot = null
var next_weapon: WeaponSlot = null
var spray_profiles: Dictionary = {}
var shot_count: int = 0
var shot_tween: Tween
var network_timer: float = 0.0
var is_reloading: bool = false
var is_melee_attacking: bool = false

func _ready() -> void:
    if weapon_stack.is_empty():
        push_error("Weapon Stack is empty, please populate with weapons")
    else:
        _initialize_weapons()
        current_weapon_slot = weapon_stack[0]
        _enter_weapon()
        
        if multiplayer.has_multiplayer_peer():
            set_multiplayer_authority(get_parent().get_parent().player_id)

func _process(delta: float) -> void:
    if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
        network_timer += delta
        if network_timer >= network_update_rate:
            network_timer = 0
            _sync_weapon_state()

## === Основные функции === ##
func _initialize_weapons() -> void:
    animation_player.animation_finished.connect(_on_animation_finished)
    for weapon_slot in weapon_stack:
        _setup_weapon(weapon_slot)

func _setup_weapon(weapon_slot: WeaponSlot) -> void:
    if not weapon_slot or not weapon_slot.weapon:
        return
        
    if weapon_slot.weapon.weapon_spray:
        spray_profiles[weapon_slot.weapon.weapon_name] = weapon_slot.weapon.weapon_spray.instantiate()
    
    hud_weapon_added.emit(weapon_slot.weapon)

func _enter_weapon() -> void:
    if not _validate_weapon_slot():
        return
        
    animation_player.queue(current_weapon_slot.weapon.pick_up_animation)
    weapon_changed.emit(current_weapon_slot.weapon.weapon_name)
    _update_ammo_display()

func _exit_weapon(next_weapon_slot: WeaponSlot) -> void:
    if next_weapon_slot != current_weapon_slot and _validate_weapon_slot():
        if animation_player.current_animation != current_weapon_slot.weapon.change_animation:
            animation_player.queue(current_weapon_slot.weapon.change_animation)
            next_weapon = next_weapon_slot

func _change_weapon(weapon_slot: WeaponSlot) -> void:
    current_weapon_slot = weapon_slot
    next_weapon = null
    _enter_weapon()

## === Функции стрельбы === ##
func shoot() -> void:
    if not _validate_weapon_slot() or not _can_shoot():
        return
        
    if current_weapon_slot.weapon.incremental_reload and is_reloading:
        animation_player.stop()
        is_reloading = false
    
    animation_player.play(current_weapon_slot.weapon.shoot_animation)
    
    if current_weapon_slot.weapon.has_ammo:
        current_weapon_slot.current_ammo -= 1
        _update_ammo_display()
    
    if shot_tween:
        shot_tween.kill()
    
    var spread = Vector2.ZERO
    if current_weapon_slot.weapon.weapon_spray:
        shot_count += 1
        spread = spray_profiles[current_weapon_slot.weapon.weapon_name].Get_Spray(
            shot_count, 
            current_weapon_slot.weapon.magazine
        )
    
    _fire_projectile(spread)

func _fire_projectile(spread: Vector2) -> void:
    if multiplayer.has_multiplayer_peer():
        if is_multiplayer_authority():
            rpc("_spawn_projectile", spread, bullet_point.global_transform)
    else:
        _spawn_projectile(spread, bullet_point.global_transform)

@rpc("call_local", "reliable")
func _spawn_projectile(spread: Vector2, fire_transform: Transform3D) -> void:
    var projectile: Projectile = current_weapon_slot.weapon.projectile_to_load.instantiate()
    bullet_point.add_child(projectile)
    
    projectile.global_transform = fire_transform
    projectile._Set_Projectile(
        current_weapon_slot.weapon.damage,
        spread,
        current_weapon_slot.weapon.fire_range,
        bullet_point.global_position
    )
    
    hud_ammo_update.emit(current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo)

## === Функции перезарядки === ##
func reload() -> void:
    if not _validate_weapon_slot() or not _can_reload():
        return
        
    if current_weapon_slot.weapon.incremental_reload:
        animation_player.queue(current_weapon_slot.weapon.reload_animation)
    else:
        animation_player.queue(current_weapon_slot.weapon.reload_animation)
    
    is_reloading = true

func _calculate_reload() -> void:
    if not _validate_weapon_slot():
        return
        
    var reload_amount = min(
        current_weapon_slot.weapon.magazine - current_weapon_slot.current_ammo,
        current_weapon_slot.reserve_ammo
    )
    
    current_weapon_slot.current_ammo += reload_amount
    current_weapon_slot.reserve_ammo -= reload_amount
    
    _update_ammo_display()
    _reset_shot_count()

## === Функции ближнего боя === ##
func melee() -> void:
    if not _validate_weapon_slot() or is_melee_attacking:
        return
        
    animation_player.play(current_weapon_slot.weapon.melee_animation)
    is_melee_attacking = true
    
    if melee_hitbox.is_colliding():
        _process_melee_hits()

func _process_melee_hits() -> void:
    for i in melee_hitbox.get_collision_count():
        var target = melee_hitbox.get_collider(i)
        if target.is_in_group("Damageable"):
            var hit_position = melee_hitbox.get_collision_point(i)
            var hit_direction = (target.global_position - global_position).normalized()
            
            hit_successful.emit(current_weapon_slot.weapon.melee_damage, hit_position)
            
            if multiplayer.has_multiplayer_peer():
                rpc("_apply_melee_damage", target.get_path(), current_weapon_slot.weapon.melee_damage, hit_direction, hit_position)
            else:
                target.take_damage(current_weapon_slot.weapon.melee_damage, hit_direction, hit_position)

@rpc("call_local", "reliable")
func _apply_melee_damage(target_path: NodePath, damage: float, direction: Vector3, position: Vector3) -> void:
    var target = get_node_or_null(target_path)
    if target and target.has_method("take_damage"):
        target.take_damage(damage, direction, position)

## === Сетевые функции === ##
func _sync_weapon_state() -> void:
    if not _validate_weapon_slot():
        return
        
    rpc("_update_weapon_state", 
        current_weapon_slot.weapon.weapon_name,
        current_weapon_slot.current_ammo,
        current_weapon_slot.reserve_ammo,
        animation_player.current_animation,
        animation_player.current_animation_position
    )

@rpc("reliable")
func _update_weapon_state(weapon_name: String, current_ammo: int, reserve_ammo: int, anim_name: String, anim_pos: float) -> void:
    if is_multiplayer_authority():
        return
        
    for weapon in weapon_stack:
        if weapon.weapon.weapon_name == weapon_name:
            current_weapon_slot = weapon
            break
    
    current_weapon_slot.current_ammo = current_ammo
    current_weapon_slot.reserve_ammo = reserve_ammo
    
    if animation_player.current_animation != anim_name:
        animation_player.play(anim_name)
    animation_player.seek(anim_pos)
    
    _update_ammo_display()

## === Вспомогательные функции === ##
func _validate_weapon_slot() -> bool:
    if not current_weapon_slot or not current_weapon_slot.weapon:
        push_warning("Invalid weapon slot or missing weapon resource")
        return false
    return true

func _can_shoot() -> bool:
    return (current_weapon_slot.current_ammo > 0 or not current_weapon_slot.weapon.has_ammo) and \
           not is_reloading and \
           not is_melee_attacking and \
           not animation_player.is_playing()

func _can_reload() -> bool:
    return current_weapon_slot.current_ammo < current_weapon_slot.weapon.magazine and \
           current_weapon_slot.reserve_ammo > 0 and \
           not is_melee_attacking

func _update_ammo_display() -> void:
    update_ammo.emit(current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo)
    hud_ammo_update.emit(current_weapon_slot.current_ammo, current_weapon_slot.reserve_ammo)

func _reset_shot_count() -> void:
    shot_count = 0
    shot_tween = create_tween()
    shot_tween.tween_property(self, "shot_count", 0, 1.0)

## === Обработчики событий === ##
func _on_animation_finished(anim_name: String) -> void:
    if not _validate_weapon_slot():
        return
        
    if anim_name == current_weapon_slot.weapon.shoot_animation:
        if current_weapon_slot.weapon.auto_fire and Input.is_action_pressed("Shoot"):
            shoot()
    
    elif anim_name == current_weapon_slot.weapon.change_animation:
        _change_weapon(next_weapon)
    
    elif anim_name == current_weapon_slot.weapon.reload_animation:
        if not current_weapon_slot.weapon.incremental_reload:
            _calculate_reload()
        is_reloading = false
    
    elif anim_name == current_weapon_slot.weapon.melee_animation:
        is_melee_attacking = false

## === Ввод с клавиатуры === ##
func _unhandled_input(event: InputEvent) -> void:
    if not _validate_weapon_slot():
        return
        
    if event.is_action_pressed("Shoot"):
        shoot()
    
    if event.is_action_released("Shoot"):
        _reset_shot_count()
    
    if event.is_action_pressed("Reload"):
        reload()
    
    if event.is_action_pressed("Melee"):
        melee()
    
    if event.is_action_pressed("Drop_Weapon"):
        drop_current_weapon()
    
    if event.is_action_pressed("WeaponUp"):
        _switch_weapon(1)
    
    if event.is_action_pressed("WeaponDown"):
        _switch_weapon(-1)
    
    if event is InputEventKey and event.pressed:
        if KEY_1 <= event.keycode and event.keycode <= KEY_9:
            var slot = event.keycode - KEY_1
            if slot < weapon_stack.size():
                _exit_weapon(weapon_stack[slot])

func _switch_weapon(direction: int) -> void:
    var current_index = weapon_stack.find(current_weapon_slot)
    var new_index = clamp(current_index + direction, 0, weapon_stack.size() - 1)
    if new_index != current_index:
        _exit_weapon(weapon_stack[new_index])

## === Функции работы с оружием === ##
func drop_current_weapon() -> void:
    if weapon_stack.size() <= 1 or not current_weapon_slot.weapon.can_be_dropped:
        return
        
    var dropped_weapon = current_weapon_slot.weapon.weapon_drop.instantiate()
    dropped_weapon.weapon_slot = current_weapon_slot.duplicate()
    dropped_weapon.global_transform = bullet_point.global_transform
    get_parent().get_parent().add_child(dropped_weapon)
    
    var current_index = weapon_stack.find(current_weapon_slot)
    weapon_stack.remove_at(current_index)
    update_weapon_stack.emit(weapon_stack)
    
    animation_player.play(current_weapon_slot.weapon.drop_animation)
    _exit_weapon(weapon_stack[max(current_index - 1, 0)])

func add_ammo(weapon_slot: WeaponSlot, amount: int) -> int:
    var needed = weapon_slot.weapon.max_ammo - weapon_slot.reserve_ammo
    var remaining = max(amount - needed, 0)
    weapon_slot.reserve_ammo += min(amount, needed)
    
    if weapon_slot == current_weapon_slot:
        _update_ammo_display()
    
    return remaining

func _on_pick_up_detection_body_entered(body: Node3D) -> void:
    if body.is_in_group("WeaponPickup"):
        _try_pick_up_weapon(body)

func _try_pick_up_weapon(pickup: Node3D) -> void:
    var weapon_slot = pickup.weapon_slot
    
    # Пополнение боеприпасов для существующего оружия
    for slot in weapon_stack:
        if slot.weapon == weapon_slot.weapon:
            var remaining = add_ammo(slot, weapon_slot.current_ammo + weapon_slot.reserve_ammo)
            
            if remaining <= 0:
                pickup.queue_free()
            else:
                weapon_slot.current_ammo = min(remaining, slot.weapon.magazine)
                weapon_slot.reserve_ammo = max(remaining - weapon_slot.current_ammo, 0)
            return
    
    # Подбор нового оружия
    if weapon_stack.size() < max_weapons and pickup.Pick_Up_Ready:
        var insert_index = weapon_stack.find(current_weapon_slot)
        weapon_stack.insert(insert_index, weapon_slot)
        update_weapon_stack.emit(weapon_stack)
        _exit_weapon(weapon_slot)
        _setup_weapon(weapon_slot)
        pickup.queue_free()
