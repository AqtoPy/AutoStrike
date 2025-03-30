var udp = PacketPeerUDP.new()
const BROADCAST_PORT = 9051  # Порт для рассылки

func start_server_broadcast():
    udp.close()
    if udp.listen(BROADCAST_PORT, "*") != OK:
        print("Failed to start broadcast")
        return
    
    # Рассылаем информацию о сервере каждые 2 секунды
    var timer = Timer.new()
    timer.wait_time = 2.0
    timer.timeout.connect(_broadcast_server_info)
    add_child(timer)
    timer.start()

func _broadcast_server_info():
    var server_info = {
        "name": current_server_info["name"],
        "ip": IP.get_local_addresses()[0],  # Локальный IP хоста
        "port": SERVER_PORT,
        "map": current_server_info["map"]
    }
    udp.set_dest_address("255.255.255.255", BROADCAST_PORT)  # Broadcast
    udp.put_packet(JSON.stringify(server_info).to_utf8_buffer())

func discover_local_servers():
    var udp = PacketPeerUDP.new()
    if udp.listen(BROADCAST_PORT, "*") != OK:
        return []
    
    var servers = []
    if udp.get_available_packet_count() > 0:
        var packet = udp.get_packet()
        var server_info = JSON.parse_string(packet.get_string_from_utf8())
        servers.append(server_info)
    
    udp.close()
    return servers

