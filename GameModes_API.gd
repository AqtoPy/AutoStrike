class_name GameModeAPI
extends Node

## === Сигналы === ##
signal mode_loaded(mode_name)                # Режим загружен
signal mode_unloaded(mode_name)              # Режим выгружен
signal player_joined(player_id, mode_data)   # Игрок присоединился
signal player_left(player_id)                # Игрок вышел
signal weapon_modified(weapon_slot)          # Оружие модифицировано
signal score_updated(player_id, new_score)   # Обновлены очки
signal team_updated(player_id, new_team)     # Изменена команда

## === Константы === ##
enum ModeState {
    LOBBY,          # Ожидание игроков
    PREGAME,        # Подготовка
    INGAME,         # Идет игра
    POSTGAME        # Завершение
}

## === Классы данных === ##
class WeaponModifiers:
    var damage_mult: float = 1.0
    var fire_rate_mult: float = 1.0
    var reload_speed_mult: float = 1.0
    var ammo_mult: float = 1.0
    var spread_mult: float = 1.0
    
    func apply_to(weapon_slot: WeaponSlot) -> void:
        var w = weapon_slot.weapon
        w.damage *= damage_mult
        w.fire_rate *= fire_rate_mult
        w.reload_time *= reload_speed_mult
        w.magazine = ceil(w.magazine * ammo_mult)
        w.max_ammo = ceil(w.max_ammo * ammo_mult)
        w.spread *= spread_mult

class PlayerModeData:
    var team: String = "neutral"
    var role: String = "player"
    var score: int = 0
    var kills: int = 0
    var deaths: int = 0
    var custom_data: Dictionary = {}

## === Переменные API === ##
var current_mode: GameMode = null
var available_modes: Dictionary = {}
var player_data: Dictionary = {}       # player_id: PlayerModeData
var mode_state: ModeState = ModeState.LOBBY
var weapon_modifiers: WeaponModifiers = WeaponModifiers.new()

## === Базовый класс режима === ##
class GameMode:
    var name: String = "Unnamed"
    var description: String = ""
    var author: String = "Unknown"
    var version: String = "1.0"
    var max_players: int = 16
    var required_weapons: Array = []    # ["pistol", "rifle"]
    var default_weapons: Array = []     # Альтернатива required_weapons
    var supported_maps: Array = []
    var team_based: bool = false
    var weapon_modifiers: WeaponModifiers = WeaponModifiers.new()
    
    # Виртуальные методы
    func setup(api: GameModeAPI) -> void: pass
    func cleanup() -> void: pass
    func start() -> void: pass
    func end() -> void: pass
    
    func on_player_join(player_id: String) -> void: pass
    func on_player_leave(player_id: String) -> void: pass
    func on_player_spawn(player_id: String) -> void: pass
    func on_player_death(player_id: String, killer_id: String) -> void: pass
    func on_weapon_fire(player_id: String, weapon_slot: WeaponSlot) -> void: pass
    func on_weapon_reload(player_id: String, weapon_slot: WeaponSlot) -> void: pass
    func on_score_update(player_id: String, delta: int) -> void: pass

## === Основной API === ##

# Инициализация
func _ready():
    _load_builtin_modes()
    _scan_custom_modes()

# Регистрация режимов
func register_mode(mode_script: GDScript) -> bool:
    var mode = mode_script.new()
    if not mode is GameMode:
        push_error("Invalid mode script: must inherit from GameMode class")
        return false
    
    available_modes[mode.name] = mode
    mode_loaded.emit(mode.name)
    return true

func unregister_mode(mode_name: String) -> bool:
    if mode_name in available_modes:
        if current_mode and current_mode.name == mode_name:
            unload_current_mode()
        available_modes.erase(mode_name)
        mode_unloaded.emit(mode_name)
        return true
    return false

# Управление текущим режимом
func load_mode(mode_name: String) -> bool:
    if mode_name in available_modes:
        if current_mode:
            unload_current_mode()
        
        current_mode = available_modes[mode_name]
        current_mode.setup(self)
        mode_state = ModeState.LOBBY
        return true
    return false

func unload_current_mode() -> void:
    if current_mode:
        current_mode.cleanup()
        current_mode = null
    mode_state = ModeState.LOBBY

func start_mode() -> void:
    if current_mode and mode_state == ModeState.LOBBY:
        current_mode.start()
        mode_state = ModeState.INGAME

func end_mode() -> void:
    if current_mode and mode_state == ModeState.INGAME:
        current_mode.end()
        mode_state = ModeState.POSTGAME

# Управление игроками
func add_player(player_id: String) -> void:
    if not player_id in player_data:
        player_data[player_id] = PlayerModeData.new()
        
        if current_mode:
            current_mode.on_player_join(player_id)
            player_joined.emit(player_id, player_data[player_id])

func remove_player(player_id: String) -> void:
    if player_id in player_data:
        if current_mode:
            current_mode.on_player_leave(player_id)
        player_data.erase(player_id)
        player_left.emit(player_id)

func spawn_player(player_id: String) -> void:
    if player_id in player_data and current_mode:
        current_mode.on_player_spawn(player_id)
        _setup_player_weapons(player_id)

func _setup_player_weapons(player_id: String) -> void:
    # Здесь должна быть интеграция с вашим WeaponSystem
    # Примерный псевдокод:
    var weapon_system = get_player_weapon_system(player_id)
    if weapon_system:
        if current_mode.required_weapons.size() > 0:
            weapon_system.reset_weapons()
            for weapon_name in current_mode.required_weapons:
                var weapon_slot = _create_weapon_slot(weapon_name)
                weapon_system.add_weapon(weapon_slot)
        current_mode.weapon_modifiers.apply_to_weapons(weapon_system)

# Работа с оружием (интеграция с WeaponSystem)
func on_weapon_fired(player_id: String, weapon_slot: WeaponSlot) -> void:
    if current_mode and player_id in player_data:
        current_mode.on_weapon_fire(player_id, weapon_slot)

func on_weapon_reloaded(player_id: String, weapon_slot: WeaponSlot) -> void:
    if current_mode and player_id in player_data:
        current_mode.on_weapon_reload(player_id, weapon_slot)

# Система команд/очков
func update_score(player_id: String, delta: int) -> void:
    if player_id in player_data:
        player_data[player_id].score += delta
        if current_mode:
            current_mode.on_score_update(player_id, delta)
        score_updated.emit(player_id, player_data[player_id].score)

func set_player_team(player_id: String, team: String) -> void:
    if player_id in player_data:
        player_data[player_id].team = team
        team_updated.emit(player_id, team)

# Внутренние методы
func _load_builtin_modes() -> void:
    var builtin_modes = [
        load("res://game_modes/DeathmatchMode.gd"),
        load("res://game_modes/TeamDeathmatchMode.gd"),
        load("res://game_modes/ZombieMode.gd")
    ]
    
    for mode_script in builtin_modes:
        if mode_script:
            register_mode(mode_script)

func _scan_custom_modes() -> void:
    var custom_dir = DirAccess.open("user://game_modes/")
    if not custom_dir:
        DirAccess.make_dir_recursive_absolute("user://game_modes/")
        return
    
    custom_dir.list_dir_begin()
    var file = custom_dir.get_next()
    while file != "":
        if file.ends_with(".gd"):
            var script = load("user://game_modes/" + file)
            if script:
                register_mode(script)
        file = custom_dir.get_next()
