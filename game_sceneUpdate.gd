extends Node

# ... [предыдущий код] ...

func init_host(player_data: Dictionary):
    # Убедимся, что authority установлен правильно
    local_player_id = multiplayer.get_unique_id()
    var player = spawn_player(local_player_id, player_data)
    if player:
        player.set_multiplayer_authority(local_player_id)
    
    game_initialized.emit()

func init_client(player_data: Dictionary):
    local_player_id = multiplayer.get_unique_id()
    rpc_id(1, "request_spawn", local_player_id, player_data)

@rpc("any_peer", "reliable")
func request_spawn(player_id: int, player_data: Dictionary):
    if multiplayer.is_server():
        var player = spawn_player(player_id, player_data)
        if player:
            player.set_multiplayer_authority(player_id)
        rpc("spawn_player", player_id, player_data)

@rpc("call_local", "reliable")
func spawn_player(player_id: int, player_data: Dictionary):
    if players.has(player_id):
        return
    
    var player_scene = load("res://player_character.tscn").instantiate()
    player_scene.name = str(player_id)
    player_scene.player_name = player_data["name"]
    
    # Передаем данные о купленных предметах
    if player_data.has("unlocked_weapons"):
        player_scene.unlocked_weapons = player_data["unlocked_weapons"]
    if player_data.has("equipped_skin"):
        player_scene.current_weapon_skin = player_data["equipped_skin"]
    if player_data.has("character"):
        player_scene.current_character = player_data["character"]
    
    add_child(player_scene)
    players[player_id] = player_scene
    
    if player_id == local_player_id:
        player_scene.set_multiplayer_authority(player_id)
        setup_player_controls(player_scene)
    
    player_spawned.emit(player_scene)
