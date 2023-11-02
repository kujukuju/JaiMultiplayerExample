
cat_sprite: Sprite;

packet_client: *PacketClient;

TICKRATE :: 60;
TICK_DURATION :: 1000 / TICKRATE;

main :: () {
    init_time();
    koda_init();

    create_window("Multiplayer Example", 1600, 900);
    set_vsync(true);
    
    cat_sprite = create_sprite(load_texture("into_the_spiritwell_cat.png"));
    cat_sprite.anchor = .{0.5, 0.5};
    set_scale(*cat_sprite, .{0.5, 0.5});

    packet_client = packet_client_create("ws://127.0.0.1:4080");
    packet_client_add_packet(packet_client, ClientRequestJointPacket.{});

    time := get_time() * 1000;
    last_update_time := time - TICK_DURATION;
    while !should_exit() {
        time = get_time() * 1000;

        if time - last_update_time >= TICK_DURATION {
            update_inputs();
            
            last_update_time += TICK_DURATION;
            update(last_update_time, TICK_DURATION);
        }

        render(time - TICK_DURATION);

        reset_temporary_storage();
    }
}

update :: (time: float64, dt: float) {
    packet_client_poll(packet_client);
    packets := packet_client_get_packets(packet_client);
    process_packets(time, packets);

    update_client_player(time, dt);

    packet_client_send_packets(packet_client);
    packet_client_poll(packet_client);
}

update_client_player :: (time: float64, dt: float) {
    client_player := get_player(client_id);
    if !client_player {
        return;
    }

    accel: Vector2;
    if input.keys[Key.A] {
        accel.x -= 0.2;
    }
    if input.keys[Key.D] {
        accel.x += 0.2;
    }
    if input.keys[Key.W] {
        accel.y -= 0.2;
    }
    if input.keys[Key.S] {
        accel.y += 0.2;
    }

    client_player.position += accel * dt;

    packet_client_add_packet(packet_client, ClientPositionPacket.{
        position = client_player.position,
    });
}

render :: (time: float64) {
    clear(.{0, 0, 0, 1});

    render_players(time);

    draw_fps(10, 10);
}

#import "KodaJai";
#import "websocketpp-jai";
#import "JaiSerializer";

#import "Basic";
#import "Math";
