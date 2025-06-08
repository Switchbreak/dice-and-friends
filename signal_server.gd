extends Node

enum Message {
    SET_ID,
    PEER_CONNECT,
    PEER_DISCONNECT,
    OFFER,
    ANSWER,
    CANDIDATE,
}

class Peer extends RefCounted:
    var socket := WebSocketPeer.new()
    var name := "Player"
    var id_set := false
    var is_host := false

    func _init(stream_peer: StreamPeerTCP) -> void:
        socket.accept_stream(stream_peer)

    func get_address() -> String:
        return "%s:%d" % [socket.get_connected_host(), socket.get_connected_port()]

var tcp_server := TCPServer.new()
var peers: Dictionary[int, Peer] = {}

func _process(_delta: float) -> void:
    poll()

func stop() -> void:
    if tcp_server.is_listening():
        print("Matchmaking server stopped")
        tcp_server.stop()

func listen(port: int) -> Error:
    stop()
    print("Matchmaking server started")
    return tcp_server.listen(port)

func poll() -> void:
    if not tcp_server.is_listening():
        return

    if tcp_server.is_connection_available():
        _connect_peer()

    var disconnected: Array[int] = []
    for index in peers:
        peers[index].socket.poll()
        var state := peers[index].socket.get_ready_state()
        if state == WebSocketPeer.STATE_OPEN:
            if not peers[index].id_set:
                peers[index].socket.send_text(JSON.stringify({ "type": Message.SET_ID, "peer_index": index }))
                peers[index].id_set = true
            _receive_peer_messages(index)
        elif state == WebSocketPeer.STATE_CLOSED:
            disconnected.append(index)

    for peer in disconnected:
        _disconnect_peer(peer)

func _connect_peer() -> void:
    var peer := Peer.new(tcp_server.take_connection())
    var index := randi() % (1 << 31)
    if peers.is_empty():
        peer.is_host = true
    peers[index] = peer
    print("Peer connected: " + peer.get_address())

func _disconnect_peer(index: int) -> void:
    peers.erase(index)
    print("Peer disconnected: %d" % index)

    for remaining_peer in peers:
        # Send existing peers notification of disconnection
        peers[remaining_peer].socket.send_text(JSON.stringify({ "type": Message.PEER_DISCONNECT, "peer_index": index, "data": "" }))


func _receive_peer_messages(index: int) -> Error:
    while peers[index].socket.get_available_packet_count():
        var packet := peers[index].socket.get_packet().get_string_from_utf8()
        var error := peers[index].socket.get_packet_error()
        if error:
            printerr("Error receiving packet from peer %s - %s" % [peers[index].get_address(), error_string(error)])
            return error

        error = _handle_peer_message(index, packet)
        if error:
            return error

    return OK

func _handle_peer_message(from_index: int, packet: String) -> Error:
    var message: Dictionary = JSON.parse_string(packet)

    if message.type == Message.PEER_CONNECT:
        peers[from_index].name = message.data.name
        for index in peers:
            if index != from_index:
                # Send existing peers the index of the new peer
                peers[index].socket.send_text(JSON.stringify({ "type": Message.PEER_CONNECT, "peer_index": from_index, "data": message.data }))
                # Send the new peer a message for each existing peer
                peers[from_index].socket.send_text(JSON.stringify({
                    "type": Message.PEER_CONNECT,
                    "peer_index": index,
                    "data": {
                        "name": peers[index].name,
                        "is_host": peers[index].is_host,
                        "preexisting": true,
                    },
                }))
    else:
        var destination := peers[int(message.peer_index)]
        destination.socket.send_text(JSON.stringify({ "type": message.type, "peer_index": from_index, "data": message.data }))

    return OK
