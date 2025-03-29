extends GameModeAPI.GameMode
class_name TeamDeathmatchMode

## === Конфигурация режима === ##
func _init():
    name = "Team Deathmatch"
    description = "Классический командный бой до достижения лимита очков"
    author = "CSLike Game"
    version = "1.2"
    max_players = 16
    team_based = true
    required_weapons = ["rifle", "pistol", "knife"]
    
    # Модификаторы оружия для баланса
    weapon_modifiers.damage_mult = 1.0
    weapon_modifiers.fire_rate_mult = 1.0
    weapon_modifiers.reload_speed_mult = 0.9  # +10% скорости перезарядки

## === Переменные режима === ##
var team_scores = {"red": 0, "blue": 0}
var score_limit = 100
var spawn_points = {
    "red": [],
    "blue": []
}
var player_respawns = {}  # player_id: respawn_time

## === Основные методы === ##
func setup(api: GameModeAPI) -> void:
    # Загружаем точки спавна с текущей карты
    _load_spawn_points()
    
    # Настройка игроков при подключении
    api.player_joined.connect(_on_player_joined)
    api.player_left.connect(_on_player_left)
    api.score_updated.connect(_on_score_updated)
    
    print("TDM mode initialized!")

func start() -> void:
    # Разделяем игроков на команды
    _assign_teams()
    
    # Телепортируем всех на точки спавна
    for player_id in api.player_data:
        spawn_player(player_id)
    
    api.mode_state = api.ModeState.INGAME
    print("TDM started! First team to reach %d points wins!" % score_limit)

func end() -> void:
    # Определяем победителя
    var winner = "Draw"
    if team_scores["red"] > team_scores["blue"]:
        winner = "Red Team"
    elif team_scores["blue"] > team_scores["red"]:
        winner = "Blue Team"
    
    print("Game over! Winner: %s (Red: %d, Blue: %d)" % [
        winner, team_scores["red"], team_scores["blue"]
    ])
    
    api.mode_state = api.ModeState.POSTGAME
    get_tree().create_timer(10.0).timeout.connect(_restart_round)

## === Обработчики событий === ##
func _on_player_joined(player_id: String) -> void:
    _assign_team(player_id)
    if api.mode_state == api.ModeState.INGAME:
        spawn_player(player_id)

func _on_player_left(player_id: String) -> void:
    player_respawns.erase(player_id)

func on_player_death(player_id: String, killer_id: String) -> void:
    if killer_id in api.player_data:
        var killer_team = api.player_data[killer_id].team
        var victim_team = api.player_data[player_id].team
        
        if killer_team != victim_team:
            api.update_score(killer_id, 1)
            team_scores[killer_team] += 1
            print("%s (%s) killed %s (%s)! %s: %d" % [
                killer_id, killer_team,
                player_id, victim_team,
                killer_team, team_scores[killer_team]
            )
    
    player_respawns[player_id] = Time.get_ticks_msec() + 5000

func on_player_spawn(player_id: String) -> void:
    api._setup_player_weapons(player_id)
    var team = api.player_data[player_id].team
    var spawn = _get_random_spawn(team)
    api.teleport_to(player_id, spawn)

func _on_score_updated(player_id: String, delta: int) -> void:
    for team in team_scores:
        if team_scores[team] >= score_limit:
            end()
            break

## === Вспомогательные методы === ##
func _load_spawn_points() -> void:
    spawn_points["red"] = [Vector3(10, 0, 5), Vector3(12, 0, 3)]
    spawn_points["blue"] = [Vector3(-10, 0, 5), Vector3(-12, 0, 3)]

func _assign_teams() -> void:
    var players = api.player_data.keys()
    for i in range(players.size()):
        _assign_team(players[i])

func _assign_team(player_id: String) -> void:
    var red_count = 0
    var blue_count = 0
    
    for pid in api.player_data:
        if api.player_data[pid].team == "red":
            red_count += 1
        elif api.player_data[pid].team == "blue":
            blue_count += 1
    
    var team = "red" if red_count <= blue_count else "blue"
    api.set_player_team(player_id, team)
    print("%s assigned to %s team" % [player_id, team])

func _get_random_spawn(team: String) -> Vector3:
    if spawn_points[team].size() == 0:
        return Vector3.ZERO
    return spawn_points[team][randi() % spawn_points[team].size()]

func _restart_round() -> void:
    team_scores = {"red": 0, "blue": 0}
    api.mode_state = api.ModeState.LOBBY
    start()
