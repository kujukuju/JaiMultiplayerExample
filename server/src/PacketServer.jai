
PacketServer :: struct {
    server: *wspp_server;
    server_context: Context;
    received_packets: [..] Packet;
    back_received_packets: [..] Packet;
    all_queued_packets: [..] u8;
    queued_packets: Table(u64, [..] u8);
    connections: [..] wspp_connection;
    mutex: Mutex;
}

// TODO instead of allocating memory for each one of these, all my packets are fixed size, it could just have the maximum packet size of bytes
Packet :: struct {
    connection: wspp_connection;
    bytes: [..] u8;
    time: float64;
}

packet_server_create :: (port: int) -> *PacketServer {
    packet_server := New(PacketServer);
    packet_server.server_context = context;

    packet_server.server = wspp_server_create();
    packet_server.server.data = packet_server;
    init(*packet_server.mutex);

    wspp_server_set_open_handler(packet_server.server, (server: *wspp_server, connection: wspp_connection) -> void #c_call {
        packet_server := cast(*PacketServer) server.data;
        server_context := packet_server.server_context;

        push_context server_context {
            lock(*packet_server.mutex);
            defer unlock(*packet_server.mutex);

            print("Opened connection.\n");

            array_add(*packet_server.connections, connection);

            connection_id := cast(u64) connection;
            bytes: [..] u8;
            table_add(*packet_server.queued_packets, connection_id, bytes);
        }
    });

    wspp_server_set_close_handler(packet_server.server, (server: *wspp_server, connection: wspp_connection) -> void #c_call {
        packet_server := cast(*PacketServer) server.data;
        server_context := packet_server.server_context;

        push_context server_context {
            lock(*packet_server.mutex);
            defer unlock(*packet_server.mutex);

            print("Closed connection.\n");
            
            connection_id := cast(u64) connection;
            
            array_ordered_remove_by_value(*packet_server.connections, connection);

            potential_client_bytes := table_find_pointer(*packet_server.queued_packets, connection_id);
            if potential_client_bytes {
                array_free(potential_client_bytes.*);
            }
            table_remove(*packet_server.queued_packets, connection_id);
        }
    });

    wspp_server_set_message_handler(packet_server.server, (server: *wspp_server, connection: wspp_connection, data: *u8, length: s64) -> void #c_call {
        packet_server := cast(*PacketServer) server.data;
        server_context := packet_server.server_context;

        push_context server_context {
            time := get_time() * 1000.0;

            lock(*packet_server.mutex);
            defer unlock(*packet_server.mutex);
            
            packet: *Packet;
            if packet_server.received_packets.count < packet_server.received_packets.allocated {
                packet_server.received_packets.count += 1;
                packet = *packet_server.received_packets[packet_server.received_packets.count - 1];
                packet.* = Packet.{};
            } else {
                packet = array_add(*packet_server.received_packets);
            }
            
            packet.connection = connection;
            if packet.bytes.allocated < length {
                next_size := next_power_of_two(length);
                array_reserve(*packet.bytes, next_size);
            }

            packet.bytes.count = length;
            packet.time = time;
            memcpy(packet.bytes.data, data, length);
        }
    });

    wspp_server_listen(packet_server.server, port);

    return packet_server;
}

packet_server_free :: (packet_server: *PacketServer) {
    // TODO fix memory, although the server will never be freed
    wspp_server_free(packet_server.server);
    for i: 0..packet_server.received_packets.allocated - 1 {
        packet := packet_server.received_packets.data + i;
        array_free(packet.bytes);
    }
    array_free(packet_server.received_packets);
    for i: 0..packet_server.back_received_packets.allocated - 1 {
        packet := packet_server.back_received_packets.data + i;
        array_free(packet.bytes);
    }
    array_free(packet_server.back_received_packets);
    array_free(packet_server.connections);
    destroy(*packet_server.mutex);
    free(cast(*void) packet_server);
}

packet_server_poll :: (packet_server: *PacketServer) {
    wspp_server_poll(packet_server.server);
}

packet_server_get_packets :: (packet_server: *PacketServer) -> [] Packet {
    lock(*packet_server.mutex);
    defer unlock(*packet_server.mutex);

    packet_server.received_packets, packet_server.back_received_packets = swap(packet_server.received_packets, packet_server.back_received_packets);
    packet_server.received_packets.count = 0;

    return packet_server.back_received_packets;
}

packet_server_get_connections :: (packet_server: *PacketServer) -> [] wspp_connection {
    lock(*packet_server.mutex);
    defer unlock(*packet_server.mutex);

    connections: [..] wspp_connection;
    connections.allocator = temp;
    array_copy(*connections, packet_server.connections);

    return connections;
}

packet_server_add_packet :: (packet_server: *PacketServer, packet: $T) {
    #run assert(is_pod(T));
    PACKET_SIZE :: #run size_of(T);
    
    lock(*packet_server.mutex);
    defer unlock(*packet_server.mutex);

    required_space := packet_server.all_queued_packets.count + PACKET_SIZE;

    if packet_server.all_queued_packets.allocated < required_space {
        array_reserve(*packet_server.all_queued_packets, next_power_of_two(required_space));
    }

    memcpy(packet_server.all_queued_packets.data + packet_server.all_queued_packets.count, *packet, PACKET_SIZE);
    packet_server.all_queued_packets.count = required_space;
}

packet_server_add_packet :: (packet_server: *PacketServer, id: u64, packet: $T) {
    #run assert(is_pod(T));
    PACKET_SIZE :: #run size_of(T);

    // TODO not 100% sure I need to lock a mutex for these methods, and also not 100% sure I should be find_or_adding
    lock(*packet_server.mutex);
    defer unlock(*packet_server.mutex);

    packets := find_or_add(*packet_server.queued_packets, id);
    required_space := packets.count + PACKET_SIZE;

    if packets.allocated < required_space {
        array_reserve(packets, next_power_of_two(required_space));
    }

    memcpy(packets.data + packets.count, *packet, PACKET_SIZE);
    packets.count = required_space;
}

packet_server_send_packets :: (packet_server: *PacketServer) {
    lock(*packet_server.mutex);
    defer unlock(*packet_server.mutex);
    
    for connection: packet_server.connections {
        connection_id := cast(u64) connection;

        packets := find_or_add(*packet_server.queued_packets, connection_id);
        required_space := packets.count + packet_server.all_queued_packets.count;

        if packets.allocated < required_space {
            array_reserve(packets, next_power_of_two(required_space));
        }

        memcpy(packets.data + packets.count, packet_server.all_queued_packets.data, packet_server.all_queued_packets.count);
        packets.count += packet_server.all_queued_packets.count;

        wspp_server_send(connection, packets.data, packets.count, .binary);
        packets.count = 0;
    }

    packet_server.all_queued_packets.count = 0;
}

#scope_file

next_power_of_two :: (i: int) -> int {
    val := 1;
    while val < i {
        val += val;
    }
    return val;
}
