func serialize_nav_points() -> Array:
    var result = []
    for point in nav_points:
        var data = {
            "position": point.position,
            "radius": point.radius,
            "is_important": point.is_important,
            "connections": []
        }
        
        for connected in point.connections:
            if connected in nav_points:
                data["connections"].append(nav_points.find(connected))
        
        result.append(data)
    return result

func deserialize_nav_points(data: Array):
    nav_points.clear()
    
    # Сначала создаём все точки
    for point_data in data:
        var point = create_nav_point_from_data(point_data)
        nav_points.append(point)
    
    # Затем восстанавливаем соединения
    for i in range(data.size()):
        for conn_index in data[i]["connections"]:
            if conn_index < nav_points.size():
                nav_points[i].add_connection(nav_points[conn_index])
