
process_packets :: (time: float64, packets: [] Packet) {
    for packet: packets {
        packet_view: [] u8;
        packet_view.data = packet.bytes.data;
        packet_view.count = packet.bytes.count;

        while packet_view.count > 0 {
            packet_type: ServerPacketType = (cast(*ServerPacketType) packet_view.data).*;

            starting_data: *u8 = packet_view.data;
            starting_count: int = packet_view.count;
            
            packet_size: int;
            #insert #run () -> string {
                server_packets_info := type_info(ServerPacketType);

                builder: String_Builder;

                append(*builder, "if #complete packet_type == {\n");
                for name: server_packets_info.names {
                    append(*builder, "case .");
                    append(*builder, name);
                    append(*builder, ";\n");
                    append(*builder, "packet_size = size_of(Server");
                    append(*builder, name);
                    append(*builder, "Packet);\n");
                }
                append(*builder, "}\n");

                return builder_to_string(*builder);
            }();

            if packet_view.count < packet_size {
                assert(false, "Invalid remaining packet byte size.");
                continue packet;
            }

            defer packet_view.data += packet_size;
            defer packet_view.count -= packet_size;

            process_packet(time, packet_type, packet_view);
        }
    }
}

process_packet :: (time: float64, packet_type: ServerPacketType, packet_view: [] u8) {
    if #complete packet_type == {
        case .SetClientID;
            packet := cast(*ServerSetClientIDPacket) packet_view.data;

            client_id = packet.id;

        case .Position;
            packet := cast(*ServerPositionPacket) packet_view.data;

            player := get_or_add_player(packet.id);
            if !player || player.id == client_id {
                return;
            }

            player.position = packet.position;
    }
}
