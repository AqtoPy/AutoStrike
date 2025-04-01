extends Node

# Ошибка 1: Не хватает константы MAPS, которая должна соответствовать меню
const MAPS = {
    "Dust": "res://maps/Dust.tscn",
    "ZeroWall": "res://maps/ZeroWall.tscn"
}

# Ошибка 2: Нет сетевых переменных и сигналов
signal player_spawned(player)
signal game_initialized

# Принимаем данные сервера
var server_info: Dictionary
var players = {}  # Словарь для хранения игроков [id: player_node]
var local_player_id: int = 0

# Ошибка 3: Нет инициализации multiplayer
func _ready():
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.peer_connected.connect(_on_player_connected)
        multiplayer.multiplayer_peer.peer_disconnected.connect(_on_player_disconnected)
        
        if multiplayer.is_server():
            load_map(server_info["map"])

# Ошибка 4: Нет загрузки карты на клиенте
func load_map(map_name: String):
    var map_path = MAPS.get(map_name, "")
    if map_path == "" or not ResourceLoader.exists(map_path):
        push_error("Map not found: " + map_name)
        return
    
    # Удаляем старую карту если есть
    for child in get_children():
        if child.is_in_group("map"):
            child.queue_free()
    
    var map = load(map_path).instantiate()
    map.add_to_group("map")
    add_child(map)
    
    # Оповещаем клиентов о загрузке карты
    if multiplayer.is_server():
        rpc("sync_map", map_name)

@rpc("call_local", "reliable")
func sync_map(map_name: String):
    if not multiplayer.is_server():  # Клиенты загружают карту
        load_map(map_name)

# Инициализация для хоста
func init_host(player_data: Dictionary):
    print("Инициализация хоста")
    
    # Ошибка 5: Нет назначения authority
    local_player_id = multiplayer.get_unique_id()
    spawn_player(local_player_id, player_data)
    
    # Оповещаем о готовности игры
    game_initialized.emit()

# Инициализация для клиента
func init_client(player_data: Dictionary):
    print("Инициализация клиента")
    
    # Ошибка 6: Клиент должен ждать подтверждения от сервера
    local_player_id = multiplayer.get_unique_id()
    rpc_id(1, "request_spawn", local_player_id, player_data)

@rpc("any_peer", "reliable")
func request_spawn(player_id: int, player_data: Dictionary):
    if multiplayer.is_server():
        spawn_player(player_id, player_data)
        # Оповещаем всех о новом игроке
        rpc("spawn_player", player_id, player_data)

# Ошибка 7: Нет сетевой синхронизации игроков
@rpc("call_local", "reliable")
func spawn_player(player_id: int, player_data: Dictionary):
    # Проверяем, не создан ли уже игрок
    if players.has(player_id):
        return
    
    print("Создаем игрока:", player_data["name"])
    
    var player_scene = load("res://player.tscn").instantiate()
    player_scene.name = str(player_id)
    player_scene.player_name = player_data["name"]
    player_scene.is_vip = player_data["is_vip"]
    
    # Ошибка 8: Нет назначения authority
    if player_id == multiplayer.get_unique_id():
        player_scene.set_multiplayer_authority(player_id)
    
    add_child(player_scene)
    players[player_id] = player_scene
    
    # Оповещаем о создании игрока
    player_spawned.emit(player_scene)
    
    # Только для локального игрока
    if player_id == local_player_id:
        setup_player_controls(player_scene)

func setup_player_controls(player):
    # Здесь настройка управления для локального игрока
    pass

# Ошибка 9: Нет обработки подключения/отключения игроков
func _on_player_connected(id: int):
    print("Player connected: ", id)
    if multiplayer.is_server():
        # Сервер может выполнить дополнительные действия
        pass

func _on_player_disconnected(id: int):
    print("Player disconnected: ", id)
    if players.has(id):
        players[id].queue_free()
        players.erase(id)

# Функции для режимов игры
func setup_deathmatch():
    print("Настройка режима Deathmatch")
    if multiplayer.is_server():
        # Конфигурация для Deathmatch
        rpc("sync_game_mode", "deathmatch")

func setup_team_deathmatch():
    print("Настройка режима Team Deathmatch")
    if multiplayer.is_server():
        # Конфигурация для Team Deathmatch
        rpc("sync_game_mode", "team_deathmatch")

func setup_zombie_mode():
    print("Настройка режима ZombieMode")
    if multiplayer.is_server():
        # Конфигурация для ZombieMode
        rpc("sync_game_mode", "zombie_mode")

func setup_default_mode():
    print("Настройка стандартного режима")
    if multiplayer.is_server():
        rpc("sync_game_mode", "default")

@rpc("call_local", "reliable")
func sync_game_mode(mode: String):
    # Клиенты получают информацию о режиме игры
    match mode:
        "deathmatch":
            print("Client: setting up deathmatch")
        "team_deathmatch":
            print("Client: setting up team deathmatch")
        "zombie_mode":
            print("Client: setting up zombie mode")
        _:
            print("Client: setting up default mode")

# Ошибка 10: Нет очистки при завершении игры
func _exit_tree():
    if multiplayer.has_multiplayer_peer():
        multiplayer.multiplayer_peer.peer_connected.disconnect(_on_player_connected)
        multiplayer.multiplayer_peer.peer_disconnected.disconnect(_on_player_disconnected)
