extends Label

func _ready():
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
    tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
