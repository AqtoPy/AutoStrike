# В разделе с другими функциями создания объектов
func create_nav_point() -> NavigationPoint:
    var point = NavigationPoint.new()
    point.position = cursor.global_position
    point.radius = brush_size.x / 2
    add_child(point)
    
    # Автоматическое соединение с ближайшей точкой
    if nav_points.size() > 0:
        var closest_point = find_closest_nav_point(point.position)
        if closest_point:
            point.add_connection(closest_point)
    
    nav_points.append(point)
    return point

func create_nav_point_from_data(data: Dictionary) -> NavigationPoint:
    var point = NavigationPoint.new()
    point.position = data["position"]
    point.radius = data.get("radius", 1.0)
    point.is_important = data.get("is_important", false)
    add_child(point)
    return point

func find_closest_nav_point(position: Vector3) -> NavigationPoint:
    if nav_points.is_empty():
        return null
    
    var closest = nav_points[0]
    var min_dist = position.distance_to(closest.position)
    
    for point in nav_points:
        var dist = position.distance_to(point.position)
        if dist < min_dist:
            min_dist = dist
            closest = point
    
    return closest if min_dist < (brush_size.x * 2) else null
