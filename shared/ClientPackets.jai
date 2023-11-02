
// more information is generated relying on the naming convention of Client{Name}Packet
ClientPacketType :: enum s16 {
    RequestJoint;
    Position;
}

ClientRequestJointPacket :: struct {
    type := ClientPacketType.RequestJoint;
}

ClientPositionPacket :: struct {
    type := ClientPacketType.Position;
    position: Vector2;
}