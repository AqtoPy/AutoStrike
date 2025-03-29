extends GameModeAPI.GameMode
class_name TeamDeathmatchMode

func _init():
    name = "Team Deathmatch"
    description = "Red vs Blue: Уничтожьте противников"
    max_players = 16
    team_based = true
    required_weapons = ["pistol", "rifle"]

var team_scores = {"red": 0, "blue": 0}
var spawn_points = {}

func setup(api: GameModeAPI):
    .setup(api)
    _load_test_spawns()
    print("TDM: Setup complete")

func start():
    _assign_teams()
    for player in api.player_data:
        spawn_player(player)
    api.mode_state = api.ModeState.INGAME
    print("TDM: Started! Teams assigned")

func _load_test_spawns():
    spawn_points = {
        "red": [Vector3(5, 0, 0), Vector3(10, 0, 0)],
        "blue": [Vector3(-5, 0, 0), Vector3(-10, 0, 0)]
    }

func _assign_teams():
    var team_index = 0
    for player in api.player_data:
        var team = "red" if team_index % 2 == 0 else "blue"
        api.set_player_team(player, team)
        team_index += 1

func on_player_spawn(player_id):
    var team = api.player_data[player_id].team
    if spawn_points.has(team) and spawn_points[team].size() > 0:
        var spawn = spawn_points[team][0]
        api.teleport_to(player_id, spawn)
        print(player_id, " spawned at ", spawn)

func on_player_death(player_id, killer_id):
    if api.player_data[killer_id].team != api.player_data[player_id].team:
        api.update_score(killer_id, 1)
        team_scores[api.player_data[killer_id].team] += 1
    get_tree().create_timer(3.0).timeout.connect(
        func(): spawn_player(player_id)
    )
