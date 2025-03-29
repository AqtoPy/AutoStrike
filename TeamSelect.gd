extends PanelContainer

signal team_selected(team_name)

@onready var teams_container = $MarginContainer/TeamsContainer
var team_buttons = {}

func _ready():
    visible = false

func setup(available_teams: Dictionary, current_player_data: Dictionary):
    # Очищаем предыдущие кнопки
    for child in teams_container.get_children():
        child.queue_free()
    team_buttons.clear()
    
    # Создаем кнопки для каждой команды
    for team_name in available_teams:
        var team = available_teams[team_name]
        var button = Button.new()
        button.text = team_name.capitalize()
        button.custom_minimum_size = Vector2(150, 50)
        button.pressed.connect(_on_team_selected.bind(team_name))
        
        # Настраиваем цвет кнопки
        var style = StyleBoxFlat.new()
        style.bg_color = team["color"]
        style.bg_color.a = 0.7
        style.border_color = team["color"].lightened(0.3)
        style.border_width_all = 2
        style.corner_radius_top_left = 8
        style.corner_radius_top_right = 8
        
        button.add_theme_stylebox_override("normal", style)
        
        var hover_style = style.duplicate()
        hover_style.bg_color.a = 0.9
        button.add_theme_stylebox_override("hover", hover_style)
        
        var pressed_style = style.duplicate()
        pressed_style.bg_color = team["color"].darkened(0.2)
        button.add_theme_stylebox_override("pressed", pressed_style)
        
        # Информация о команде
        var label = Label.new()
        label.text = "Players: %d" % team["players"].size()
        label.align = Label.ALIGNMENT_CENTER
        
        var vbox = VBoxContainer.new()
        vbox.add_child(button)
        vbox.add_child(label)
        
        teams_container.add_child(vbox)
        team_buttons[team_name] = button
    
    # Кнопка "Spectator"
    var spectator_button = Button.new()
    spectator_button.text = "Spectator"
    spectator_button.custom_minimum_size = Vector2(150, 50)
    spectator_button.pressed.connect(_on_team_selected.bind("spectator"))
    
    var spec_style = StyleBoxFlat.new()
    spec_style.bg_color = Color(0.3, 0.3, 0.3, 0.7)
    spec_style.border_color = Color(0.5, 0.5, 0.5)
    spec_style.border_width_all = 2
    
    spectator_button.add_theme_stylebox_override("normal", spec_style)
    teams_container.add_child(spectator_button)
    
    # Показываем окно
    visible = true

func _on_team_selected(team_name: String):
    team_selected.emit(team_name)
    visible = false

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        visible = false
