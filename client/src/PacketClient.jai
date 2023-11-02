
PacketClient :: struct {
    client: *wspp_client;
    client_context: Context;
    received_packets: [..] Packet;
    back_received_packets: [..] Packet;
    queued_packets: [..] u8;
}

Packet :: struct {
    bytes: [..] u8;
}

packet_client_create :: (address: string) -> *PacketClient {
    packet_client := New(PacketClient);
    packet_client.client_context = context;

    packet_client.client = wspp_client_create();
    packet_client.client.data = packet_client;

    wspp_client_set_open_handler(packet_client.client, (client: *wspp_client, connection: wspp_connection) -> void #c_call {
        packet_client := cast(*PacketClient) client.data;
        client_context := packet_client.client_context;

        push_context client_context {
            print("Opened connection.\n");
        }
    });

    wspp_client_set_close_handler(packet_client.client, (client: *wspp_client, connection: wspp_connection) -> void #c_call {
        packet_client := cast(*PacketClient) client.data;
        client_context := packet_client.client_context;

        push_context client_context {
            print("Closed connection.\n");
        }
    });

    wspp_client_set_message_handler(packet_client.client, (client: *wspp_client, data: *u8, length: s64) -> void #c_call {
        packet_client := cast(*PacketClient) client.data;
        client_context := packet_client.client_context;

        push_context client_context {
            packet: *Packet;
            if packet_client.received_packets.count < packet_client.received_packets.allocated {
                packet_client.received_packets.count += 1;
                packet = *packet_client.received_packets[packet_client.received_packets.count - 1];
                packet.* = Packet.{};
            } else {
                packet = array_add(*packet_client.received_packets);
            }
            
            if packet.bytes.allocated < length {
                next_size := next_power_of_two(length);
                array_reserve(*packet.bytes, next_size);
            }

            packet.bytes.count = length;
            memcpy(packet.bytes.data, data, length);
        }
    });

    wspp_client_connect(packet_client.client, address.data, address.count);
    while !packet_client.client.connection {
        wspp_client_poll(packet_client.client);
    }

    return packet_client;
}

packet_client_free :: (packet_client: *PacketClient) {
    wspp_client_free(packet_client.client);
    for i: 0..packet_client.received_packets.allocated - 1 {
        packet := packet_client.received_packets.data + i;
        array_free(packet.bytes);
    }
    array_free(packet_client.received_packets);
    for i: 0..packet_client.back_received_packets.allocated - 1 {
        packet := packet_client.back_received_packets.data + i;
        array_free(packet.bytes);
    }
    array_free(packet_client.back_received_packets);
    free(cast(*void) packet_client);
}

packet_client_poll :: (packet_client: *PacketClient) {
    wspp_client_poll(packet_client.client);
}

packet_client_get_packets :: (packet_client: *PacketClient) -> [] Packet {
    packet_client.received_packets, packet_client.back_received_packets = swap(packet_client.received_packets, packet_client.back_received_packets);
    packet_client.received_packets.count = 0;

    return packet_client.back_received_packets;
}

packet_client_add_packet :: (packet_client: *PacketClient, packet: $T) {
    #run assert(is_pod(T));
    PACKET_SIZE :: #run size_of(T);

    required_space := packet_client.queued_packets.count + PACKET_SIZE;

    if packet_client.queued_packets.allocated < required_space {
        array_reserve(*packet_client.queued_packets, next_power_of_two(required_space));
    }

    memcpy(packet_client.queued_packets.data + packet_client.queued_packets.count, *packet, PACKET_SIZE);
    packet_client.queued_packets.count = required_space;
}

packet_client_send_packets :: (packet_client: *PacketClient) {
    sent := wspp_client_send(packet_client.client, packet_client.queued_packets.data, packet_client.queued_packets.count, .binary);
    packet_client.queued_packets.count = 0;
}

#scope_file

next_power_of_two :: (i: int) -> int {
    val := 1;
    while val < i {
        val += val;
    }
    return val;
}
