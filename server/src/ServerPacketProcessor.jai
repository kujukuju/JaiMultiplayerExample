
process_packets :: (time: float64, packets: [] Packet) {
    for packet: packets {
        connection_id := cast(u64) packet.connection;

        packet_view: [] u8;
        packet_view.data = packet.bytes.data;
        packet_view.count = packet.bytes.count;

        while packet_view.count > 0 {
            packet_type: ClientPacketType = (cast(*ClientPacketType) packet_view.data).*;

            starting_data: *u8 = packet_view.data;
            starting_count: int = packet_view.count;
            
            packet_size: int;
            #insert #run () -> string {
                client_packets_info := type_info(ClientPacketType);

                builder: String_Builder;

                append(*builder, "if #complete packet_type == {\n");
                for name: client_packets_info.names {
                    append(*builder, "case .");
                    append(*builder, name);
                    append(*builder, ";\n");
                    append(*builder, "packet_size = size_of(Client");
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

            process_packet(time, connection_id, packet_type, packet_view);
        }
    }
}

process_packet :: (time: float64, connection_id: u64, packet_type: ClientPacketType, packet_view: [] u8) {
    if #complete packet_type == {
        case .RequestJoint;
            packet := cast(*ClientRequestJointPacket) packet_view.data;

            packet_server_add_packet(context.packet_server, connection_id, ServerSetClientIDPacket.{
                id = connection_id,
            });

            add_player(context.player_manager, connection_id);

        case .Position;
            packet := cast(*ClientPositionPacket) packet_view.data;

            player := get_player(context.player_manager, connection_id);
            if !player {
                return;
            }

            player.position = packet.position;
    }
}
