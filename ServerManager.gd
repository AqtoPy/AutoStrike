extends Node

signal server_list_updated(servers)

var active_servers = []

func create_server(config: Dictionary):
    var server_info = {
        "name": config.name,
        "map": config.map,
        "mode": config.mode,
        "max_players": config.max_players,
        "current_players": 1,
        "creator_id": config.creator_id,
        "ping": 0,
        "has_password": false,
        "address": "127.0.0.1",  # Для локальных серверов
        "port": 9050
    }
    active_servers.append(server_info)
    server_list_updated.emit(active_servers)
    return server_info

func get_server_list():
    return active_servers

func remove_server(server_name: String):
    for i in range(active_servers.size()):
        if active_servers[i]["name"] == server_name:
            active_servers.remove_at(i)
            break
    server_list_updated.emit(active_servers)
