extends Node

class_name SignalServer

enum Message {
    SET_ID,
    PEER_CONNECT,
    PEER_DISCONNECT,
    OFFER,
    ANSWER,
    CANDIDATE,
}

# Matchmaking server defaults
const DEFAULT_SERVER_IP = "match.coriolis.space" # IPv4 localhost
const DEFAULT_PORT = 443

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
var peers: Dictionary[String, Peer] = {}

func _process(_delta: float) -> void:
    poll()

func stop() -> void:
    if tcp_server.is_listening():
        tcp_server.stop()
        print("Matchmaking server stopped")

func listen(port: int) -> Error:
    stop()
    var error := tcp_server.listen(port)
    print("Matchmaking server started")

    if error:
        printerr("Failed to start to matchmaking server: " + error_string(error))

    return error

func poll() -> void:
    if not tcp_server.is_listening():
        return

    if tcp_server.is_connection_available():
        _connect_peer()

    var disconnected: Array[String] = []
    for index in peers:
        peers[index].socket.poll()
        var state := peers[index].socket.get_ready_state()
        if state == WebSocketPeer.STATE_OPEN:
            if not peers[index].id_set:
                _set_peer_id(peers[index], index)
            _receive_peer_messages(index)
        elif state == WebSocketPeer.STATE_CLOSED:
            disconnected.append(index)

    for peer in disconnected:
        _disconnect_peer(peer)

func _receive_peer_messages(index: String) -> Error:
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

func _handle_peer_message(from_index: String, packet: String) -> Error:
    var message: Dictionary = JSON.parse_string(packet)

    # Forward PEER_CONNECT messages to entire peer list, all other types to
    # just the destination peer
    var error: Error
    if message.type == Message.PEER_CONNECT:
        error = _handle_peer_connection(from_index, message)
    else:
        error = _send_peer_message(peers[message.peer_index], message.type, from_index, message.data)

    return error

func _handle_peer_connection(from_index: String, message: Dictionary) -> Error:
    peers[from_index].name = message.data.name

    var errors: Array[Error]
    for index in peers:
        if index != from_index:
            # Send existing peers the index of the new peer
            var error := _send_peer_message(peers[index], Message.PEER_CONNECT, from_index, message.data)
            if error:
                errors.append(error)

            # Send the new peer a message for each existing peer
            error = _send_peer_message(
                peers[from_index],
                Message.PEER_CONNECT,
                index,
                {
                    "name": peers[index].name,
                    "is_host": peers[index].is_host,
                    "preexisting": true,
                })
            if error:
                errors.append(error)

    if errors.is_empty():
        return OK
    else:
        return errors[0]

func _connect_peer() -> void:
    var peer := Peer.new(tcp_server.take_connection())
    var index := str(randi() % (1 << 31))
    if peers.is_empty():
        peer.is_host = true
    peers[index] = peer
    print("Peer connected: " + peer.get_address())

func _set_peer_id(peer: Peer, index: String) -> Error:
    peer.id_set = true
    return _send_peer_message(peer, Message.SET_ID, index)

func _disconnect_peer(index: String) -> Error:
    peers.erase(index)
    print("Peer disconnected: %s" % index)

    # Send existing peers notification of disconnection
    var errors: Array[Error]
    for remaining_peer in peers:
        var error := _send_peer_message(peers[remaining_peer], Message.PEER_DISCONNECT, index)
        if error:
            errors.append(error)

    if errors.is_empty():
        return OK
    else:
        return errors[0]

func _send_peer_message(peer: Peer, type: Message, index: String, data: Variant = {}) -> Error:
    var packet := JSON.stringify({ "type": type, "peer_index": index, "data": data })
    var error := peer.socket.send_text(packet)
    if error:
        printerr("Failed to send packet %s to peer %s" % [packet, peer.name])

    return error
