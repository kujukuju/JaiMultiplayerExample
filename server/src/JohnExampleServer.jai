
MAX_PLAYERS :: 32;
ROOM_TICKRATE :: 60;
TICK_DURATION :: 1000 / ROOM_TICKRATE;

#add_context packet_server: *PacketServer;
#add_context player_manager: *PlayerManager;

main :: () {
    init_time();

    context.packet_server = packet_server_create(4080);

    player_manager: PlayerManager;
    context.player_manager = *player_manager;

    while true {
        start := get_time() * 1000;

        server_loop(start);

        end := get_time() * 1000;

        duration := end - start;
        remainder := max(TICK_DURATION - duration, 0);
        while remainder > 0 {
            // poll while paused instead of wasting the cpu
            packet_server_poll(context.packet_server);

            duration = get_time() * 1000 - start;
            remainder = max(TICK_DURATION - duration, 0);
        }

        reset_temporary_storage();
    }
}

server_loop :: (time: float64) {
    packets := packet_server_get_packets(context.packet_server);
    process_packets(time, packets);

    connections := packet_server_get_connections(context.packet_server);
    maintain_players(context.player_manager, connections);

    update_packets(context.player_manager);

    packet_server_send_packets(context.packet_server);
    packet_server_poll(context.packet_server);
}

#import "websocketpp-jai";
#import "JaiSerializer";

#import "Basic";
#import "Thread";
#import "Hash_Table";
#import "Math";
