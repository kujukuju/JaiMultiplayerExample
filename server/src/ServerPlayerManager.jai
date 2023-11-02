
PlayerManager :: struct {
    players: [..] Player;
}

Player :: struct {
    id: u64;
    position: Vector2;
}

get_player :: (manager: *PlayerManager, id: u64) -> *Player {
    for *player: manager.players {
        if player.id == id {
            return player;
        }
    }

    return null;
}

add_player :: (manager: *PlayerManager, id: u64) {
    player := array_add(*manager.players);
    player.id = id;
}

update_packets :: (manager: *PlayerManager) {
    for player: manager.players {
        packet_server_add_packet(context.packet_server, ServerPositionPacket.{
            id = player.id,
            position = player.position,
        });
    }
}

maintain_players :: (manager: *PlayerManager, connections: [] u64) {
    i := 0;
    while i < manager.players.count {
        found := false;
        for connection_id: connections {
            if manager.players[i].id == connection_id {
                found = true;
                break;
            }
        }

        if found {
            i += 1;
        } else {
            array_ordered_remove_by_index(*manager.players, i);
        }
    }
}
