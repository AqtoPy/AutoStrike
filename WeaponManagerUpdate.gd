extends Node3D

# ... [предыдущие сигналы и переменные] ...

@export var damage_text_color: Color = Color.RED
@export var critical_color: Color = Color.GOLD

func shoot():
    # ... [предыдущий код shoot] ...
    if hit_success:
        var is_critical = randf() < 0.1  # 10% шанс крита
        var damage_amount = current_weapon_slot.weapon.damage
        if is_critical:
            damage_amount *= 2
            _show_damage_text(damage_amount, true)
        else:
            _show_damage_text(damage_amount, false)

func _show_damage_text(amount: int, is_critical: bool):
    var damage_text = damage_text_scene.instantiate()
    damage_text.text = str(amount)
    damage_text.modulate = critical_color if is_critical else damage_text_color
    
    # Позиционируем по центру экрана
    var viewport_size = get_viewport().size
    damage_text.position = Vector2(viewport_size.x / 2 - damage_text.size.x / 2, 
                                  viewport_size.y / 2 - 50)
    
    get_viewport().add_child(damage_text)
    
    # Анимация
    var tween = create_tween()
    tween.tween_property(damage_text, "position:y", damage_text.position.y - 30, 0.5)
    tween.parallel().tween_property(damage_text, "modulate:a", 0.0, 0.5)
    tween.tween_callback(damage_text.queue_free)
