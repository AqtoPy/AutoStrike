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
const SERVER_PORT = 9050
const MAX_PLAYERS = 16

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
@onready var password_dialog = $PasswordDialog
@onready var password_edit = $PasswordDialog/MarginContainer/VBoxContainer/PasswordEdit

# Данные
var player_data = {
    "name": "Player",
    "balance": 1000,
    "is_vip": false,
    "vip_days": 0,
    "player_id": ""
}
var available_maps = ["de_dust2", "de_inferno", "de_nuke"]
var available_modes = ["Deathmatch", "Team Deathmatch"]
var custom_modes = []
var server_list_data = []
var multiplayer_peer: MultiplayerPeer
var current_server_config: Dictionary
var selected_server_info: Dictionary

func _ready():
    # Инициализация
    _setup_directories()
    _generate_player_id()
    _load_player_data()
    _load_custom_modes()
    _setup_ui()
    _connect_signals()
    _refresh_server_list()

func _setup_directories():
    DirAccess.make_dir_recursive_absolute(CUSTOM_MODES_DIR)

func _connect_signals():
    vip_button.pressed.connect(_on_vip_button_pressed)
    purchase_button.pressed.connect(_purchase_vip)
    player_name_edit.text_submitted.connect(_change_player_name)
    player_limit_slider.value_changed.connect(_update_player_limit_label)
    password_dialog.confirmed.connect(_on_password_confirmed)

func _setup_ui():
    player_name_edit.text = player_data["name"]
    _update_balance_ui()
    _update_vip_status_ui()
    _update_player_limit_label(player_limit_slider.value)
    _populate_map_options()
    _populate_mode_options()
    vip_price_label.text = "VIP Status (%d days): %d$" % [VIP_DAYS, VIP_PRICE]

func _load_custom_modes():
    var dir = DirAccess.open(CUSTOM_MODES_DIR)
    if not dir:
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        if file_name.ends_with(".gd"):
            var mode_name = file_name.get_basename()
            if not mode_name in available_modes:
                available_modes.append(mode_name)
                custom_modes.append(mode_name)
        file_name = dir.get_next()

func _populate_mode_options():
    mode_option.clear()
    for i in range(available_modes.size()):
        mode_option.add_item(available_modes[i])
        if available_modes[i] in custom_modes:
            mode_option.set_item_icon(i, load("res://assets/icons/custom_mode.png"))

func _on_create_server_pressed():
    var server_name = server_name_edit.text.strip_edges()
    
    if server_name.length() < 3:
        _show_status("Server name must be at least 3 characters!", Color.RED)
        return
    
    current_server_config = {
        "name": server_name,
        "map": available_maps[map_option.selected],
        "mode": available_modes[mode_option.selected],
        "max_players": int(player_limit_slider.value),
        "port": SERVER_PORT,
        "password": "",
        "players": [],
        "is_vip": player_data["is_vip"],
        "has_password": false
    }
    
    _create_network_server()

func _create_network_server():
    _show_status("Creating server...", Color.YELLOW)
    
    multiplayer_peer = ENetMultiplayerPeer.new()
    var err = multiplayer_peer.create_server(current_server_config["port"], current_server_config["max_players"])
    
    if err != OK:
        _show_status("Failed to create server (error %d)" % err, Color.RED)
        return
    
    multiplayer.multiplayer_peer = multiplayer_peer
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    
    _show_status("Server '%s' created!" % current_server_config["name"], Color.GREEN)
    server_created.emit(current_server_config)
    server_list_data.append(current_server_config)
    _refresh_server_list()
    tabs.current_tab = 0

func _on_player_connected(id: int):
    print("Player connected: ", id)
    current_server_config["players"].append(id)
    rpc_id(id, "receive_server_config", current_server_config)

func _on_player_disconnected(id: int):
    print("Player disconnected: ", id)
    current_server_config["players"].erase(id)

@rpc("reliable")
func receive_server_config(config: Dictionary):
    print("Received server config: ", config)

func _on_server_selected(server_info: Dictionary):
    selected_server_info = server_info
    if server_info["has_password"]:
        password_dialog.popup_centered()
    else:
        _connect_to_server(server_info)

func _on_password_confirmed():
    var password = password_edit.text
    # Здесь должна быть проверка пароля
    _connect_to_server(selected_server_info)
    password_edit.text = ""

func _connect_to_server(server_info: Dictionary):
    _show_status("Connecting to %s..." % server_info["name"], Color.WHITE)
    
    multiplayer_peer = ENetMultiplayerPeer.new()
    var err = multiplayer_peer.create_client("127.0.0.1", server_info["port"])
    
    if err != OK:
        _show_status("Connection failed (error %d)" % err, Color.RED)
        return
    
    multiplayer.multiplayer_peer = multiplayer_peer
    server_selected.emit(server_info)

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
        
        _show_status("VIP activated! You can now create VIP servers.", Color.GREEN)
        balance_updated.emit(player_data["balance"])
    else:
        _show_status("Not enough money to purchase VIP!", Color.RED)

func _show_status(message: String, color: Color):
    status_label.text = message
    status_label.modulate = color

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

func _refresh_server_list():
    for child in server_list.get_children():
        child.queue_free()
    
    for server in server_list_data:
        var server_button = Button.new()
        server_button.text = _format_server_info(server)
        server_button.custom_minimum_size = Vector2(0, 60)
        server_button.align = Label.ALIGN_LEFT
        server_button.pressed.connect(_on_server_selected.bind(server))
        server_list.add_child(server_button)

func _format_server_info(server: Dictionary) -> String:
    var password_icon = "🔒" if server["has_password"] else ""
    return "%s %s\nMap: %s | Mode: %s | Players: %d/%d | %s" % [
        server["name"],
        password_icon,
        server["map"].capitalize(),
        server["mode"],
        server["players"].size(),
        server["max_players"],
        "VIP" if server.get("is_vip", false) else ""
    ]

func _change_player_name(new_name: String):
    new_name = new_name.strip_edges()
    
    if new_name.length() < 3:
        _show_status("Name must be at least 3 characters!", Color.RED)
        return
    
    if new_name.length() > 16:
        _show_status("Name must be ≤16 characters!", Color.RED)
        return
    
    player_data["name"] = new_name
    _save_player_data()
    player_name_changed.emit(new_name)
    _show_status("Name changed to '%s'" % new_name, Color.GREEN)

func add_funds(amount: int):
    if amount <= 0:
        return
    
    player_data["balance"] += amount
    _save_player_data()
    _update_balance_ui()
    balance_updated.emit(player_data["balance"])
    _show_status("Received %d$! New balance: %d$" % [amount, player_data["balance"]], Color.GREEN)

func _save_player_data():
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_var(player_data)
    file.close()

@rpc("any_peer")
func request_vip_purchase():
    if multiplayer.is_server():
        # Проверка баланса и выдача VIP
        pass

@rpc("reliable")
func update_player_data(new_data: Dictionary):
    player_data = new_data
    _update_balance_ui()
    _update_vip_status_ui()
