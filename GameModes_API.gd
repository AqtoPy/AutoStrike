class_name GameModeAPI
extends Node

## === Сигналы === ##
signal mode_loaded(mode_name)
signal mode_unloaded(mode_name)
signal player_joined(player_id, team)
signal player_left(player_id)
signal team_updated(team_name, property, value)

## === Классы данных === ##
class TeamData:
    var name: String
    var color: Color
    var score: int = 0
    var players: Array = []
    
    func _init(_name: String, _color: Color):
        name = _name
        color = _color

class PlayerModeData:
    var team: String = ""
    var stats: Dictionary = {}
    var is_vip: bool = false
    
    func update_stat(stat_name: String, value):
        stats[stat_name] = value

## === Основные переменные === ##
var current_mode: GameMode = null
var available_modes: Dictionary = {}
var teams: Dictionary = {}       # team_name: TeamData
var player_data: Dictionary = {} # player_id: PlayerModeData
var mode_state: int = 0 # 0-lobby, 1-pregame, 2-ingame, 3-postgame

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
    
    func setup(api: GameModeAPI) -> void:
        # Инициализация команд
        if team_based:
            for team in default_teams:
                api.create_team(team.name, team.color)
    
    func get_team_color(team_name: String) -> Color:
        return Color.WHITE
    
    func get_scoreboard_data(player_stats: Dictionary) -> Dictionary:
        var data = {}
        for player_id in player_stats:
            data[player_id] = {
                "name": player_stats[player_id].get("name", "Player"),
                "team": player_stats[player_id].get("team", ""),
                "is_vip": player_stats[player_id].get("is_vip", false)
            }
            for stat in scoreboard_stats:
                if player_stats[player_id].has(stat):
                    data[player_id][stat] = player_stats[player_id][stat]
        return data

## === Основной API === ##
func _ready():
    _load_builtin_modes()
    _scan_custom_modes()

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

func remove_team(team_name: String) -> void:
    if teams.has(team_name):
        for player_id in teams[team_name].players:
            set_player_team(player_id, "")
        teams.erase(team_name)
        team_updated.emit(team_name, "removed", null)

func set_player_team(player_id: String, team_name: String) -> void:
    if not player_data.has(player_id):
        return
    
    # Удаляем из старой команды
    var old_team = player_data[player_id].team
    if teams.has(old_team):
        teams[old_team].players.erase(player_id)
    
    # Добавляем в новую команду
    if teams.has(team_name):
        player_data[player_id].team = team_name
        teams[team_name].players.append(player_id)
        player_joined.emit(player_id, team_name)
    else:
        player_data[player_id].team = ""

func update_player_stat(player_id: String, stat_name: String, value) -> void:
    if player_data.has(player_id):
        player_data[player_id].update_stat(stat_name, value)
        
        # Обновляем статистику команды если нужно
        if stat_name == "score" and player_data[player_id].team:
            var team = player_data[player_id].team
            if teams.has(team):
                teams[team].score = _calculate_team_score(team)

func get_scoreboard_data() -> Dictionary:
    if current_mode:
        var stats = {}
        for player_id in player_data:
            stats[player_id] = {
                "name": player_data[player_id].get("name", "Player"),
                "team": player_data[player_id].team,
                "is_vip": player_data[player_id].is_vip
            }
            for stat in current_mode.scoreboard_stats:
                if player_data[player_id].stats.has(stat):
                    stats[player_id][stat] = player_data[player_id].stats[stat]
        
        return current_mode.get_scoreboard_data(stats)
    return {}

func get_team_color(team_name: String) -> Color:
    if teams.has(team_name):
        return teams[team_name].color
    return current_mode.get_team_color(team_name) if current_mode else Color.WHITE

## === Внутренние методы === ##
func _calculate_team_score(team_name: String) -> int:
    var total = 0
    for player_id in teams[team_name].players:
        if player_data[player_id].stats.has("score"):
            total += player_data[player_id].stats["score"]
    return total

func _load_builtin_modes():
    var builtin_modes = [
        load("res://game_modes/DeathmatchMode.gd"),
        load("res://game_modes/TeamDeathmatchMode.gd")
    ]
    for mode_script in builtin_modes:
        if mode_script:
            register_mode(mode_script)

func _scan_custom_modes():
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
