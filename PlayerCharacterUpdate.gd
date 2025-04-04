extends CharacterBody3D

# ... [предыдущие настройки] ...

# Новые переменные для отображения урона
var damage_text_scene = preload("res://ui/damage_text.tscn")
var current_character: String = "soldier"
var current_weapon_skin: String = "default"

func _ready():
    # ... [предыдущий код] ...
    _load_character_model()
    _load_weapon_skin()

func _load_character_model():
    var model_path = "res://characters/%s.tscn" % current_character
    if ResourceLoader.exists(model_path):
        var model = load(model_path).instantiate()
        $Model.add_child(model)

func _load_weapon_skin():
    # Здесь загружаем скин для текущего оружия
    pass

func take_damage(amount: int, attacker: Node):
    # ... [предыдущий код обработки урона] ...
    _show_damage_text(amount)

func _show_damage_text(amount: int):
    var damage_text = damage_text_scene.instantiate()
    damage_text.text = str(amount)
    damage_text.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)
    get_viewport().add_child(damage_text)
    
    # Анимация появления и исчезания текста урона
    var tween = create_tween()
    tween.tween_property(damage_text, "position:y", damage_text.position.y - 50, 0.5)
    tween.parallel().tween_property(damage_text, "modulate:a", 0.0, 0.5)
    tween.tween_callback(damage_text.queue_free)

func add_xp(amount: int):
    player_xp += amount
    while player_xp >= _get_xp_for_level(player_level + 1):
        player_xp -= _get_xp_for_level(player_level + 1)
        player_level += 1
        _on_level_up()
    
    _update_level_ui()

func _on_level_up():
    show_status("Новый уровень! %d" % player_level, Color.GOLD)
    # Можно добавить награды за уровень
