
// more information is generated relying on the naming convention of Server{Name}Packet
ServerPacketType :: enum s16 {
    SetClientID;
    Position;
}

ServerSetClientIDPacket :: struct {
    type := ServerPacketType.SetClientID;
    id: u64;
}

ServerPositionPacket :: struct {
    type := ServerPacketType.Position;
    id: u64;
    position: Vector2;
}
