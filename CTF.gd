class_name CTFMode
extends GameModeAPI.GameMode

## Режим "Захват флага" ##

# Конфигурация режима
var flag_positions := {}
var flag_carriers := {}
var capture_scores := {}

func _init():
    name = "CTF"
    description = "Захвати флаг противника и принеси на свою базу чтобы заработать очки!"
    team_based = true
    default_teams = [
        {"name": "red", "color": Color.RED},
        {"name": "blue", "color": Color.BLUE}
    ]
    scoreboard_stats = ["kills", "deaths", "score", "captures", "returns"]
    default_lives = 3  # У игроков будет 3 жизни

func setup(api: GameModeAPI) -> void:
    super.setup(api)
    
    # Инициализация флагов
    flag_positions = {
        "red": Vector3(0, 0, 0),   # Позиция флага красных
        "blue": Vector3(100, 0, 0) # Позиция флага синих
    }
    
    # Инициализация счетчиков захватов
    for team in default_teams:
        capture_scores[team.name] = 0
    
    # Настройка API
    api.show_timer = true
    api.set_custom_stats(scoreboard_stats)

func get_scoreboard_data(player_stats: Dictionary) -> Dictionary:
    var data = super.get_scoreboard_data(player_stats)
    
    # Добавляем информацию о командах (очки захвата)
    for team in teams:
        if capture_scores.has(team):
            data["team_" + team] = {
                "name": team.to_upper(),
                "score": capture_scores[team],
                "flag_status": _get_flag_status(team)
            }
    
    return data

func _get_flag_status(team: String) -> String:
    if flag_carriers.has(team):
        return "Унесен игроком %s" % flag_carriers[team]
    return "На базе"

## === Обработчики событий (вызываются из основного кода игры) === ##
func on_player_spawn(player_id: String, spawn_position: Vector3):
    # Устанавливаем стандартные статы для нового игрока
    if not api.player_data[player_id].stats.has("captures"):
        api.player_data[player_id].stats["captures"] = 0
        api.player_data[player_id].stats["returns"] = 0
    
    # Размещаем игрока на своей базе
    var team = api.player_data[player_id].team
    if team == "red":
        spawn_position = Vector3(-50, 0, 0)
    elif team == "blue":
        spawn_position = Vector3(150, 0, 0)
    
    return spawn_position

func on_player_death(player_id: String, killer_id: String):
    # Если игрок нес флаг - флаг возвращается на базу
    for team in flag_carriers:
        if flag_carriers[team] == player_id:
            flag_carriers.erase(team)
            api.update_player_stat(killer_id, "returns", api.player_data[killer_id].stats["returns"] + 1)
            api.emit_signal("flag_returned", team)
            break
    
    # Стандартная обработка смертей
    api.modify_player_lives(player_id, -1)
    if api.player_data[player_id].lives <= 0:
        api.player_data[player_id].lives = default_lives
        return true  # Разрешить респавн
    return false

func on_flag_taken(player_id: String, flag_team: String):
    var player_team = api.player_data[player_id].team
    
    # Нельзя взять свой флаг
    if player_team == flag_team:
        return
    
    # Запоминаем кто взял флаг
    flag_carriers[flag_team] = player_id
    api.emit_signal("flag_taken", flag_team, player_id)

func on_flag_captured(player_id: String, flag_team: String):
    var player_team = api.player_data[player_id].team
    
    # Проверяем что игрок доставил флаг противника на свою базу
    if player_team != flag_team and flag_carriers.has(flag_team) and flag_carriers[flag_team] == player_id:
        # Начисляем очки
        capture_scores[player_team] += 1
        api.update_player_stat(player_id, "captures", api.player_data[player_id].stats["captures"] + 1)
        
        # Возвращаем флаг на базу
        flag_carriers.erase(flag_team)
        api.emit_signal("flag_captured", flag_team, player_id)
        
        # Проверяем условия победы
        if capture_scores[player_team] >= 3:
            api.mode_state = 3  # POSTGAME
            api.emit_signal("game_over", player_team)

func on_player_connected(player_id: String):
    # При подключении игрока добавляем его в команду с меньшим количеством игроков
    var team_counts = {}
    for team in teams:
        team_counts[team] = teams[team].players.size()
    
    var smallest_team = "red"
    for team in team_counts:
        if team_counts[team] < team_counts[smallest_team]:
            smallest_team = team
    
    api.set_player_team(player_id, smallest_team)
    api.set_player_lives(player_id, default_lives)
    
    # Инициализируем статистику
    api.player_data[player_id].stats = {
        "kills": 0,
        "deaths": 0,
        "score": 0,
        "captures": 0,
        "returns": 0
    }

func on_player_disconnected(player_id: String):
    # Если игрок нес флаг - возвращаем флаг на базу
    for team in flag_carriers:
        if flag_carriers[team] == player_id:
            flag_carriers.erase(team)
            api.emit_signal("flag_returned", team)
            break
