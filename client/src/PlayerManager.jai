
Player :: struct {
    id: u64;
    position: Vector2;
}

client_id: u64;
players: [..] Player;

get_player :: (id: u64) -> *Player {
    for *player: players {
        if player.id == id {
            return player;
        }
    }

    return null;
}

get_or_add_player :: (id: u64) -> *Player {
    player := get_player(id);
    if !player {
        player = add_player(id);
    }

    return player;
}

add_player :: (id: u64) -> *Player {
    player := array_add(*players);
    player.id = id;

    return player;
}

render_players :: (time: float64) {
    for player: players {
        draw(cat_sprite, player.position);
    }
}
