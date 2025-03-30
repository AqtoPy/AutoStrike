class_name GameModeAPI
extends Node

# Дополнительные сигналы
signal score_updated(team_scores: Dictionary)
signal timer_updated(time_left: int)
signal hint_shown(text: String, duration: float)
signal popup_shown(title: String, message: String)
signal zone_entered(zone_name: String, player_id: String)
signal currency_earned(player_id: String, amount: int)

# Добавляем в класс TeamData
class TeamData:
    # ... существующий код ...
    var ui_position: Vector2 = Vector2.ZERO # Позиция на экране
    
    func set_ui_position(x: float, y: float):
        ui_position = Vector2(x, y)

# Новый класс для зон
class Zone:
    var name: String
    var area: Area3D
    var reward: int
    var cooldown: float
    var last_used: Dictionary = {} # player_id: timestamp
    
    func _init(_name: String, _area: Area3D, _reward: int = 0, _cooldown: float = 5.0):
        name = _name
        area = _area
        reward = _reward
        cooldown = _cooldown
        area.body_entered.connect(_on_body_entered)
    
    func _on_body_entered(body: Node):
        if body.has_method("get_player_id"):
            var player_id = body.get_player_id()
            var current_time = Time.get_unix_time_from_system()
            if not last_used.has(player_id) or (current_time - last_used[player_id]) > cooldown:
                last_used[player_id] = current_time
                zone_entered.emit(name, player_id)

# Новые переменные
var zones: Dictionary = {}
var game_timer: Timer
var team_scores_visible: bool = false
var current_hint: String = ""
var shop_zones: Dictionary = {}

func _ready():
    # ... существующий код ...
    game_timer = Timer.new()
    add_child(game_timer)
    game_timer.timeout.connect(_on_timer_timeout)

# === Новые методы для UI ===
func show_team_scores(visible: bool):
    team_scores_visible = visible
    if visible:
        var scores = {}
        for team_name in teams:
            scores[team_name] = {
                "score": teams[team_name].score,
                "color": teams[team_name].color,
                "position": teams[team_name].ui_position
            }
        score_updated.emit(scores)

func display_text(text: String, duration: float = 5.0):
    current_hint = text
    hint_shown.emit(text, duration)

func show_popup(title: String, message: String):
    popup_shown.emit(title, message)

# === Таймер ===
func start_timer(duration: int):
    game_timer.start(duration)

func stop_timer():
    game_timer.stop()

func _on_timer_timeout():
    timer_updated.emit(int(game_timer.time_left))

# === Система зон ===
func create_zone(name: String, area: Area3D, reward: int = 0, is_shop: bool = false):
    if not zones.has(name):
        zones[name] = Zone.new(name, area, reward)
        if is_shop:
            shop_zones[name] = zones[name]

func remove_zone(name: String):
    if zones.has(name):
        zones.erase(name)
    if shop_zones.has(name):
        shop_zones.erase(name)

func _on_zone_entered(zone_name: String, player_id: String):
    if zones.has(zone_name):
        var zone = zones[zone_name]
        if zone.reward > 0 and mode_state == 2: # Только в игровом режиме
            update_player_stat(player_id, "coins", zone.reward)
            currency_earned.emit(player_id, zone.reward)
            display_text("%s получил %d монет!" % [player_id, zone.reward])

# === Магазин в зонах ===
func add_shop_item(zone_name: String, item_name: String, cost: int, action: Callable):
    if shop_zones.has(zone_name):
        # Реализуйте логику магазина
        pass

func purchase_item(player_id: String, item_name: String):
    if player_data.has(player_id) and player_data[player_id].stats.has("coins"):
        # Проверка баланса и применение действия
        pass

# === Обновленный метод для режима игры ===
func set_game_state(new_state: int):
    mode_state = new_state
    match new_state:
        0: # Lobby
            stop_timer()
        1: # Pregame
            start_timer(10) # 10 сек на подготовку
        2: # Ingame
            start_timer(600) # 10 минут игры
        3: # Postgame
            stop_timer()
            display_text("Игра завершена!")

# Пример использования в режиме игры:
func setup_capture_zones():
    var zone1 = create_zone("GoldMine", $Map/GoldMineArea, 10)
    var zone2 = create_zone("Shop", $Map/ShopArea, 0, true)
    
    add_shop_item("Shop", "Health", 50, func(player_id): 
        update_player_stat(player_id, "health", 25)
    )
# Добавляем в GameModeAPI
signal shop_item_purchased(player_id: String, item_id: String)
signal shop_tab_added(tab_name: String, items: Dictionary)

var shop_tabs = {}

func register_shop_tab(tab_name: String, items: Dictionary):
    shop_tabs[tab_name] = items
    shop_tab_added.emit(tab_name, items)

func purchase_item(player_id: String, item_id: String):
    shop_item_purchased.emit(player_id, item_id)
