extends Node

class Peer extends RefCounted:
    var socket := WebSocketPeer.new()

    func _init(stream_peer: StreamPeerTCP) -> void:
        socket.accept_stream(stream_peer)

    func get_address() -> String:
        return "%s:%d" % [socket.get_connected_host(), socket.get_connected_port()]

var tcp_server := TCPServer.new()
var peers: Array[Peer] = []

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

    var disconnected: Array[Peer] = []
    for peer in peers:
        peer.socket.poll()
        var state := peer.socket.get_ready_state()
        if state == WebSocketPeer.STATE_OPEN:
            _receive_peer_messages(peer)
        elif state == WebSocketPeer.STATE_CLOSED:
            disconnected.append(peer)

    for peer in disconnected:
        _disconnect_peer(peer)

func _connect_peer() -> void:
    var peer := Peer.new(tcp_server.take_connection())
    peers.append(peer)
    print("Peer connected: " + peer.get_address())

func _disconnect_peer(peer: Peer) -> void:
    peers.erase(peer)
    print("Peer disconnected: " + peer.get_address())

func _receive_peer_messages(peer: Peer) -> Error:
    while peer.socket.get_available_packet_count():
        var packet := peer.socket.get_packet().get_string_from_utf8()
        var error := peer.socket.get_packet_error()
        if error:
            printerr("Error receiving packet from peer %s - %s" % [peer.get_address(), error_string(error)])
            return error

        error = _handle_peer_message(peer, packet)
        if error:
            return error

    return OK

func _handle_peer_message(peer: Peer, packet: String) -> Error:
    print("Received packet from peer %s - %s" % [peer.get_address(), packet])

    var response_timer := get_tree().create_timer(1)
    response_timer.timeout.connect(_send_peer_response.bind(peer))

    return OK

func _send_peer_response(peer: Peer) -> void:
    peer.socket.send_text("Hello from matchmaking server")
    #stop()
