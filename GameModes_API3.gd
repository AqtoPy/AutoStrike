class_name GameModeAPI
extends Node

## === Сигналы === ##
signal mode_loaded(mode_name)
signal mode_unloaded(mode_name)
signal player_joined(player_id, team)
signal player_left(player_id)
signal team_updated(team_name, property, value)
signal window_opened(window_id, window_data)
signal window_closed(window_id)
signal currency_changed(player_id, amount, new_balance)
signal item_purchased(player_id, item_id)
signal ui_element_updated(element_type, value)  # Для обновления элементов UI
signal score_display_changed(new_format)  # Для изменения формата счета
signal timer_display_changed(new_format)  # Для изменения формата таймера

## === Классы данных === ##
class TeamData:
    var name: String
    var color: Color
    var score: int = 0
    var players: Array = []
    var score_display: String = "{score}"  # Формат отображения счета
    
    func _init(_name: String, _color: Color):
        name = _name
        color = _color
    
    func get_display_score() -> String:
        return score_display.format({"score": score})

class PlayerModeData:
    var team: String = ""
    var stats: Dictionary = {}
    var is_vip: bool = false
    var currency: int = 0
    var inventory: Array = []
    var custom_ui: Dictionary = {}  # Кастомные UI элементы для игрока
    
    func update_stat(stat_name: String, value):
        stats[stat_name] = value
        
    func add_currency(amount: int) -> int:
        currency += amount
        return currency
        
    func remove_currency(amount: int) -> bool:
        if currency >= amount:
            currency -= amount
            return true
        return false
        
    func add_item(item_id: String) -> void:
        if not inventory.has(item_id):
            inventory.append(item_id)
    
    func set_ui_element(element: String, value: String) -> void:
        custom_ui[element] = value

## === Основные переменные === ##
var current_mode: GameMode = null
var available_modes: Dictionary = {}
var teams: Dictionary = {}
var player_data: Dictionary = {}
var mode_state: int = 0 # 0-lobby, 1-pregame, 2-ingame, 3-postgame
var active_windows: Dictionary = {}
var shop_items: Dictionary = {}

# Настройки UI из изображения
var ui_settings: Dictionary = {
    "score_display": "{score}",  # По умолчанию просто число
    "timer_display": "{minutes}:{seconds}",  # Формат таймера
    "main_color": Color(0.2, 0.4, 0.8),  # Основной синий цвет
    "secondary_color": Color(0.8, 0.2, 0.2),  # Вторичный красный цвет
    "text_style": {
        "font": "dynamic",
        "outline": true,
        "outline_color": Color.BLACK,
        "shadow": true
    },
    "special_effects": []  # Спецэффекты типа "ATAKVİTE BPAFOB!"
}

## === Классы для UI === ##
class WindowData:
    # [Предыдущая реализация остается без изменений...]
    pass

class ShopItemData:
    # [Предыдущая реализация остается без изменений...]
    pass

## === Базовый класс режима === ##
class GameMode:
    var name: String = "Unnamed"
    var description: String = ""
    var team_based: bool = false
    var default_teams: Array = [
        {"name": "red", "color": Color.RED},
        {"name": "blue", "color": Color.BLUE}
    ]
    var scoreboard_stats: Array = ["kills", "deaths", "score", "ping"]
    var starting_currency: int = 0
    var custom_ui_settings: Dictionary = {}  # Настройки UI для режима
    
    func setup(api: GameModeAPI) -> void:
        if team_based:
            for team in default_teams:
                api.create_team(team.name, team.color)
        
        for player_id in api.player_data:
            api.player_data[player_id].currency = starting_currency
        
        # Применяем кастомные настройки UI
        api.apply_ui_settings(custom_ui_settings)
    
    # [Остальные предыдущие методы остаются...]
    
    ## Новые методы для кастомизации UI ##
    func update_score_display(api: GameModeAPI, team_name: String, format: String) -> void:
        if api.teams.has(team_name):
            api.teams[team_name].score_display = format
            api.score_display_changed.emit(format)
    
    func update_timer_display(api: GameModeAPI, format: String) -> void:
        api.ui_settings["timer_display"] = format
        api.timer_display_changed.emit(format)
    
    func set_ui_style(api: GameModeAPI, style: Dictionary) -> void:
        api.ui_settings.merge(style, true)
        api.ui_element_updated.emit("all", null)
    
    func add_special_effect(api: GameModeAPI, effect_text: String, duration: float = 3.0) -> void:
        if not api.ui_settings["special_effects"].has(effect_text):
            api.ui_settings["special_effects"].append(effect_text)
            api.ui_element_updated.emit("effect", effect_text)
            
            # Автоматическое удаление через duration секунд
            if duration > 0:
                var timer = Timer.new()
                api.add_child(timer)
                timer.wait_time = duration
                timer.one_shot = true
                timer.timeout.connect(func(): 
                    api.ui_settings["special_effects"].erase(effect_text)
                    api.ui_element_updated.emit("effect_remove", effect_text)
                    timer.queue_free()
                )
                timer.start()
    
    func set_player_ui_element(api: GameModeAPI, player_id: String, element: String, value: String) -> void:
        if api.player_data.has(player_id):
            api.player_data[player_id].set_ui_element(element, value)
            api.ui_element_updated.emit("player_" + element, {"player_id": player_id, "value": value})

## === Основной API === ##
func _ready():
    _load_builtin_modes()
    _scan_custom_modes()

func apply_ui_settings(settings: Dictionary) -> void:
    ui_settings.merge(settings, true)
    ui_element_updated.emit("all", null)

func register_mode(mode_script: GDScript) -> bool:
    var mode = mode_script.new()
    if not mode is GameMode:
        push_error("Invalid mode script: must inherit from GameMode class")
        return false
    
    available_modes[mode.name] = mode
    mode_loaded.emit(mode.name)
    return true

func load_mode(mode_name: String) -> bool:
    if mode_name in available_modes:
        if current_mode:
            unload_current_mode()
        
        current_mode = available_modes[mode_name]
        current_mode.setup(self)
        mode_state = 0 # LOBBY
        return true
    return false

func create_team(team_name: String, team_color: Color) -> void:
    if not teams.has(team_name):
        teams[team_name] = TeamData.new(team_name, team_color)
        team_updated.emit(team_name, "created", null)

func set_team_score_display(team_name: String, format: String) -> void:
    if teams.has(team_name):
        teams[team_name].score_display = format
        score_display_changed.emit(format)

func update_team_score(team_name: String, amount: int) -> void:
    if teams.has(team_name):
        teams[team_name].score += amount
        team_updated.emit(team_name, "score", teams[team_name].score)
        score_display_changed.emit(teams[team_name].get_display_score())

func get_formatted_timer(time_seconds: int) -> String:
    var minutes = time_seconds / 60
    var seconds = time_seconds % 60
    return ui_settings["timer_display"].format({
        "minutes": "%02d" % minutes,
        "seconds": "%02d" % seconds,
        "total": time_seconds
    })

# [Остальные предыдущие методы остаются...]

## === Пример использования для стилизации под ваше изображение === ##
class CustomGameMode extends GameMode:
    func _init():
        name = "CustomMode"
        description = "Режим с кастомным UI как на картинке"
        team_based = true
        starting_currency = 100
        
        # Настройки UI в стиле изображения
        custom_ui_settings = {
            "score_display": "## {score} ##",  # Как "## 100 ##" на изображении
            "timer_display": "{minutes}/{seconds}",  # Как "14/999" на изображении
            "main_color": Color(0.1, 0.1, 0.3),
            "secondary_color": Color(0.6, 0.1, 0.1),
            "text_style": {
                "font": "bold",
                "outline": true,
                "outline_color": Color(0, 0, 0, 0.7),
                "shadow": true,
                "shadow_color": Color(0.3, 0, 0.5)
            }
        }
    
    func setup(api: GameModeAPI) -> void:
        super.setup(api)
        
        # Устанавливаем особый формат счета для команд
        update_score_display(api, "red", "КРАСНЫЕ: {score}")
        update_score_display(api, "blue", "СИНИЕ: {score}")
        
        # Добавляем спецэффект как на изображении
        add_special_effect(api, "ATAKVİTE BPAFOB!")
        
        # Устанавливаем кастомные элементы UI для игроков
        for player_id in api.player_data:
            set_player_ui_element(api, player_id, "status", "1x-x-кабанёнок-x-кi убился!")
    
    func handle_window_action(api: GameModeAPI, window_id: String, action: String, args: Dictionary) -> void:
        if action == "update_ui":
            # Пример обработки действия для обновления UI
            if args.has("score_format"):
                update_score_display(api, args.get("team", ""), args["score_format"])
            if args.has("timer_format"):
                update_timer_display(api, args["timer_format"])

## === Полная реализация API === ##
func unload_current_mode() -> void:
    if current_mode:
        var mode_name = current_mode.name
        current_mode = null
        mode_unloaded.emit(mode_name)
        
        # Очищаем команды
        for team_name in teams:
            remove_team(team_name)
        
        # Сбрасываем UI настройки
        apply_ui_settings({
            "score_display": "{score}",
            "timer_display": "{minutes}:{seconds}",
            "main_color": Color(0.2, 0.4, 0.8),
            "secondary_color": Color(0.8, 0.2, 0.2),
            "text_style": {},
            "special_effects": []
        })

func _load_builtin_modes() -> void:
    var builtin_modes = [
        load("res://game_modes/DeathmatchMode.gd"),
        load("res://game_modes/TeamDeathmatchMode.gd"),
        load("res://game_modes/CustomMode.gd")  # Режим с кастомным UI
    ]
    for mode_script in builtin_modes:
        if mode_script:
            register_mode(mode_script)

func _scan_custom_modes() -> void:
    var dir = DirAccess.open("user://game_modes/")
    if not dir:
        DirAccess.make_dir_recursive_absolute("user://game_modes/")
        return
    
    dir.list_dir_begin()
    var file = dir.get_next()
    while file != "":
        if file.ends_with(".gd"):
            var script = load("user://game_modes/" + file)
            if script:
                register_mode(script)
        file = dir.get_next()
