func _create_network_server():
    status_label.text = "Создание сервера..."
    status_label.modulate = Color.YELLOW
    
    multiplayer_peer = ENetMultiplayerPeer.new()
    var error = multiplayer_peer.create_server(current_server_info["port"], current_server_info["max_players"])
    
    if error != OK:
        status_label.text = "Ошибка создания сервера (код %d)" % error
        status_label.modulate = Color.RED
        return
    
    multiplayer.multiplayer_peer = multiplayer_peer
    is_server = true
    
    # Настраиваем обработчики
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    
    status_label.text = "Сервер '%s' создан!" % current_server_info["name"]
    status_label.modulate = Color.GREEN
    
    # Автоматически подключаем создателя к серверу
    _start_game()

func _on_player_connected(id: int):
    print("Игрок подключился:", id)
    current_server_info["players"].append(id)
    
    # Отправляем игроку данные сервера
    rpc_id(id, "receive_server_info", current_server_info)

func _on_player_disconnected(id: int):
    print("Игрок отключился:", id)
    current_server_info["players"].erase(id)

@rpc("reliable")
func receive_server_info(info: Dictionary):
    current_server_info = info
    print("Получены данные сервера:", info)



# Добавьте в начало скрипта с другими константами
const GAME_SCENE_PATH = "res://game_scene.tscn"
const MAP_PATHS = {
    "de_dust2": "res://maps/dust2.tscn",
    "de_inferno": "res://maps/inferno.tscn",
    "de_nuke": "res://maps/nuke.tscn"
}

# Обновленная функция _start_game()
func _start_game():
    # Загружаем сцену игры
    var game_scene = load(GAME_SCENE_PATH).instantiate()
    
    # Передаем параметры сервера в игровую сцену
    game_scene.server_info = current_server_info
    
    # Определяем путь к карте
    var map_path = MAP_PATHS.get(current_server_info["map"], "")
    if map_path == "" or not ResourceLoader.exists(map_path):
        status_label.text = "Ошибка: карта не найдена!"
        status_label.modulate = Color.RED
        return
    
    # Загружаем карту
    var map_scene = load(map_path).instantiate()
    game_scene.add_child(map_scene)
    
    # Настраиваем режим игры
    _setup_game_mode(game_scene)
    
    # Переходим на игровую сцену
    get_tree().root.add_child(game_scene)
    get_tree().current_scene.queue_free()
    get_tree().current_scene = game_scene
    
    # Инициализируем игрока
    if is_server:
        game_scene.init_host(player_data)
    else:
        game_scene.init_client(player_data)

func _setup_game_mode(game_scene):
    # Здесь реализуйте логику для разных режимов игры
    match current_server_info["mode"]:
        "Deathmatch":
            game_scene.setup_deathmatch()
        "Team Deathmatch":
            game_scene.setup_team_deathmatch()
        "ZombieMode":
            game_scene.setup_zombie_mode()
        _:
            game_scene.setup_default_mode()
