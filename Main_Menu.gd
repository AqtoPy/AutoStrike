extends Control

signal vip_purchased(player_id)
signal server_created(server_config)
signal server_selected(server_info)
signal player_name_changed(new_name)
signal balance_updated(new_balance)

# Настройки
const VIP_PRICE = 500
const VIP_DAYS = 30
const SAVE_PATH = "user://player_data.dat"
const CUSTOM_MODES_DIR = "user://game_modes/"

# Ноды интерфейса
@onready var tabs = $TabContainer
@onready var player_name_edit = $TabContainer/Main/PlayerInfo/NameEdit
@onready var balance_label = $TabContainer/Main/PlayerInfo/BalanceLabel
@onready var vip_button = $TabContainer/Main/PlayerInfo/VIPButton
@onready var vip_status_label = $TabContainer/Main/PlayerInfo/VIPStatusLabel
@onready var server_list = $TabContainer/Browse/ServersScroll/ServerList
@onready var server_name_edit = $TabContainer/Create/ServerConfig/NameEdit
@onready var player_limit_slider = $TabContainer/Create/ServerConfig/PlayerLimitSlider
@onready var player_limit_label = $TabContainer/Create/ServerConfig/PlayerLimitLabel
@onready var map_option = $TabContainer/Create/ServerConfig/MapOption
@onready var mode_option = $TabContainer/Create/ServerConfig/ModeOption
@onready var status_label = $StatusLabel
@onready var vip_dialog = $VIPDialog
@onready var vip_price_label = $VIPDialog/MarginContainer/VBoxContainer/PriceLabel
@onready var purchase_button = $VIPDialog/MarginContainer/VBoxContainer/PurchaseButton

# Данные игрока
var player_data = {
    "name": "Player",
    "balance": 1000,
    "is_vip": false,
    "vip_days": 0,
    "player_id": ""
}

# Данные серверов
var available_maps = ["de_dust2", "de_inferno", "de_nuke"]
var available_modes = ["Deathmatch", "Team Deathmatch"]
var custom_modes = []
var server_list_data = []

func _ready():
    # Инициализация
    _generate_player_id()
    _load_player_data()
    _load_custom_modes()
    _setup_ui()
    
    # Подключение сигналов
    vip_button.pressed.connect(_on_vip_button_pressed)
    purchase_button.pressed.connect(_purchase_vip)
    player_name_edit.text_submitted.connect(_change_player_name)
    player_limit_slider.value_changed.connect(_update_player_limit_label)
    
    # Тестовые данные
    _refresh_server_list()

func _generate_player_id():
    if player_data["player_id"] == "":
        randomize()
        player_data["player_id"] = "player_%d" % randi_range(100000, 999999)

func _load_player_data():
    if FileAccess.file_exists(SAVE_PATH):
        var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
        var saved_data = file.get_var()
        if saved_data is Dictionary:
            # Сохраняем сгенерированный ID если он уже есть
            var old_id = player_data["player_id"]
            player_data = saved_data
            if old_id != "":
                player_data["player_id"] = old_id
        file.close()

func _save_player_data():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_var(player_data)
    file.close()

func _load_custom_modes():
    var dir = DirAccess.open(CUSTOM_MODES_DIR)
    if not dir:
        DirAccess.make_dir_recursive_absolute(CUSTOM_MODES_DIR)
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".gd"):
            var mode_name = file_name.get_basename()
            if not mode_name in available_modes:
                custom_modes.append(mode_name)
        file_name = dir.get_next()
    
    available_modes += custom_modes

func _setup_ui():
    # Основная информация игрока
    player_name_edit.text = player_data["name"]
    _update_balance_ui()
    _update_vip_status_ui()
    
    # Настройки создания сервера
    _update_player_limit_label(player_limit_slider.value)
    
    # Заполняем опции карт и режимов
    _populate_map_options()
    _populate_mode_options()
    
    # Диалог VIP
    vip_price_label.text = "Purchase VIP Status (%d days) for %d$" % [VIP_DAYS, VIP_PRICE]

func _update_balance_ui():
    balance_label.text = "Balance: %d$" % player_data["balance"]
    purchase_button.disabled = player_data["balance"] < VIP_PRICE || player_data["is_vip"]

func _update_vip_status_ui():
    if player_data["is_vip"]:
        vip_button.text = "VIP Active"
        vip_button.disabled = true
        vip_status_label.text = "VIP expires in %d days" % player_data["vip_days"]
        vip_status_label.modulate = Color.GREEN
    else:
        vip_button.text = "Buy VIP"
        vip_button.disabled = false
        vip_status_label.text = "Regular Player"
        vip_status_label.modulate = Color.WHITE

func _update_player_limit_label(value: float):
    player_limit_label.text = "Max Players: %d" % value

func _populate_map_options():
    map_option.clear()
    for map in available_maps:
        map_option.add_item(map.capitalize())

func _populate_mode_options():
    mode_option.clear()
    for mode in available_modes:
        mode_option.add_item(mode)
    
    # Выделяем кастомные режимы цветом
    for i in range(available_modes.size()):
        if available_modes[i] in custom_modes:
            mode_option.set_item_disabled(i, false)
            mode_option.set_item_icon(i, load("res://assets/icons/custom_mode.png"))

func _refresh_server_list():
    # Очищаем список
    for child in server_list.get_children():
        child.queue_free()
    
    # Загружаем сервера (в реальной игре - запрос к мастер-серверу)
    server_list_data = _get_test_servers()
    
    # Добавляем сервера в список
    for server in server_list_data:
        var server_button = Button.new()
        server_button.text = _format_server_info(server)
        server_button.custom_minimum_size = Vector2(0, 60)
        server_button.align = Label.ALIGN_LEFT
        server_button.pressed.connect(_on_server_selected.bind(server))
        server_list.add_child(server_button)

func _get_test_servers() -> Array:
    return [
        {
            "name": "Classic Deathmatch",
            "map": "de_dust2",
            "mode": "Deathmatch",
            "players": "4/12",
            "ping": 32,
            "has_password": false
        },
        {
            "name": "Zombie Apocalypse",
            "map": "de_inferno",
            "mode": "ZombieMode",
            "players": "8/16",
            "ping": 56,
            "has_password": true
        },
        {
            "name": "Competitive Match",
            "map": "de_nuke",
            "mode": "Team Deathmatch",
            "players": "10/10",
            "ping": 24,
            "has_password": true
        }
    ]

func _format_server_info(server: Dictionary) -> String:
    var password_icon = "🔒" if server["has_password"] else ""
    return "%s %s\nMap: %s | Mode: %s | Players: %s | Ping: %dms" % [
        server["name"],
        password_icon,
        server["map"].capitalize(),
        server["mode"],
        server["players"],
        server["ping"]
    ]

func _on_vip_button_pressed():
    if player_data["is_vip"]:
        return
    
    vip_dialog.popup_centered()

func _purchase_vip():
    if player_data["is_vip"]:
        return
    
    if player_data["balance"] >= VIP_PRICE:
        player_data["balance"] -= VIP_PRICE
        player_data["is_vip"] = true
        player_data["vip_days"] = VIP_DAYS
        
        _save_player_data()
        _update_balance_ui()
        _update_vip_status_ui()
        
        vip_purchased.emit(player_data["player_id"])
        vip_dialog.hide()
        status_label.text = "VIP status purchased! Expires in %d days." % VIP_DAYS
        status_label.modulate = Color.GREEN
        balance_updated.emit(player_data["balance"])
    else:
        status_label.text = "Not enough money to purchase VIP!"
        status_label.modulate = Color.RED

func _change_player_name(new_name: String):
    new_name = new_name.strip_edges()
    
    if new_name.length() < 3:
        status_label.text = "Name must be at least 3 characters long!"
        status_label.modulate = Color.RED
        return
    
    if new_name.length() > 16:
        status_label.text = "Name must be no more than 16 characters!"
        status_label.modulate = Color.RED
        return
    
    player_data["name"] = new_name
    _save_player_data()
    player_name_changed.emit(new_name)
    status_label.text = "Name changed to '%s'" % new_name
    status_label.modulate = Color.GREEN

func _on_server_selected(server_info: Dictionary):
    if server_info["has_password"]:
        _show_password_dialog(server_info)
    else:
        _connect_to_server(server_info)

func _show_password_dialog(server_info: Dictionary):
    # В реальной игре нужно реализовать диалог ввода пароля
    status_label.text = "This server requires a password!"
    status_label.modulate = Color.YELLOW

func _connect_to_server(server_info: Dictionary):
    server_selected.emit(server_info)
    status_label.text = "Connecting to %s..." % server_info["name"]
    status_label.modulate = Color.WHITE

func _on_create_server_pressed():
    var server_name = server_name_edit.text.strip_edges()
    
    if server_name.length() < 3:
        status_label.text = "Server name must be at least 3 characters!"
        status_label.modulate = Color.RED
        return
    
    var server_config = {
        "name": server_name,
        "map": available_maps[map_option.selected],
        "mode": available_modes[mode_option.selected],
        "max_players": int(player_limit_slider.value),
        "password": "",
        "is_public": true,
        "creator_id": player_data["player_id"],
        "creator_is_vip": player_data["is_vip"]
    }
    
    server_created.emit(server_config)
    status_label.text = "Creating server '%s'..." % server_name
    status_label.modulate = Color.WHITE

func add_funds(amount: int):
    if amount <= 0:
        return
    
    player_data["balance"] += amount
    _save_player_data()
    _update_balance_ui()
    balance_updated.emit(player_data["balance"])
    
    status_label.text = "Received %d$! New balance: %d$" % [amount, player_data["balance"]]
    status_label.modulate = Color.GREEN

# Сетевые функции
@rpc("any_peer")
func request_vip_purchase():
    if multiplayer.is_server():
        # Проверяем баланс и выдаем VIP
        pass

@rpc("reliable")
func update_player_data(new_data: Dictionary):
    player_data = new_data
    _update_balance_ui()
    _update_vip_status_ui()
