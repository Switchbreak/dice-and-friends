extends Node

signal player_connected(peer_id: String)
signal player_disconnected(peer_id: String)
signal joined_table(lobby_id: String)
signal left_table()

const DEFAULT_STUN_SERVER: String = "stun:stun.l.google.com:19302"

var players: Dictionary[String, Dictionary] = {}
var chat_log: Array[String]
var player_info: Dictionary = {
    "name": "Name",
    "is_host": false,
    "is_self": true,
    "preexisting": false,
    "peer_id": 0,
    "lobby_id": "",
}

var server_ip := SignalServer.DEFAULT_SERVER_IP
var server_port := SignalServer.DEFAULT_PORT
var matchmaking_socket := WebSocketPeer.new()
var prev_state: WebSocketPeer.State

#region Matchmaking server communication

func matchmaking_server_connect(address: String, port: int, lobby_id: String) -> Error:
    prev_state = WebSocketPeer.STATE_CONNECTING
    var error := matchmaking_socket.connect_to_url("ws://%s:%s/%s" % [address, port, lobby_id])
    if error:
        printerr("Failed to connect to matchmaking server: " + error_string(error))

    return error

func _matchmaking_server_disconnect() -> void:
    matchmaking_socket.close()
    print("Disconnecting from matchmaking server")

func _matchmaking_server_disconnected() -> void:
    var code := matchmaking_socket.get_close_code()
    var reason := matchmaking_socket.get_close_reason()
    printerr("Disconnected from matchmaking server: %d - %s" % [code, reason])

func _matchmaking_server_send(type: int, data: Variant, index: String = "") -> Error:
    var packet := JSON.stringify({
        "type": type,
        "data": data,
        "peer_index": index,
    })
    var error := matchmaking_socket.send_text(packet)

    if error:
        printerr("Failed to send message to matchmaking server: " + packet)
    return error

func poll_matchmaking_server() -> Error:
    matchmaking_socket.poll()
    var state := matchmaking_socket.get_ready_state()

    if state == WebSocketPeer.STATE_OPEN:
        var error := _receive_matchmaking_messages()
        if error:
            return error

        if state != prev_state:
            # When connection first opens, send notification to matchmaking server
            error = _matchmaking_server_send(SignalServer.Message.PEER_CONNECT, player_info)
            if error:
                return error
    elif state == WebSocketPeer.STATE_CLOSED and state != prev_state:
        _matchmaking_server_disconnected()

    prev_state = state
    return OK

func _receive_matchmaking_messages() -> Error:
    while matchmaking_socket.get_available_packet_count():
        var packet := matchmaking_socket.get_packet().get_string_from_utf8()
        var error := matchmaking_socket.get_packet_error()
        if error:
            printerr("Error receiving packet from matchmaking server: " + error_string(error))
            return error

        error = _handle_matchmaking_message(packet)
        if error:
            return error

    return OK

func _handle_matchmaking_message(packet: String) -> Error:
    print(player_info.name + ": Received packet from matchmaking server: " + packet)

    var message: Dictionary = JSON.parse_string(packet)
    var peer_index: String = message.peer_index

    match int(message.type):
        SignalServer.Message.SET_ID:
            init_rtc(peer_index)
            player_info.lobby_id = message.data.lobby_id
            joined_table.emit(player_info.lobby_id)
        SignalServer.Message.PEER_CONNECT:
            _register_player(message.data, peer_index)
            _connect_peer(peer_index, message.data.preexisting)
        SignalServer.Message.PEER_DISCONNECT:
            _disconnect_peer(peer_index)
        SignalServer.Message.OFFER:
            var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
            var peer_id: int = players[peer_index].peer_id
            print(player_info.name + ": Offer received")
            if rtc_peer.has_peer(peer_id):
                rtc_peer.get_peer(peer_id).connection.set_remote_description("offer", message.data)
        SignalServer.Message.ANSWER:
            var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
            var peer_id: int = players[peer_index].peer_id
            print(player_info.name + ": Answer received")
            if rtc_peer.has_peer(peer_id):
                rtc_peer.get_peer(peer_id).connection.set_remote_description("answer", message.data)
        SignalServer.Message.CANDIDATE:
            var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
            var peer_id: int = players[peer_index].peer_id
            print(player_info.name + ": Candidate received")
            var candidate: PackedStringArray = message.data.split("\n", false)
            if rtc_peer.has_peer(peer_id):
                rtc_peer.get_peer(peer_id).connection.add_ice_candidate(candidate[0], candidate[1].to_int(), candidate[2])

    return OK

#endregion

func init_rtc(index: String) -> Error:
    var peer := WebRTCMultiplayerPeer.new()
    var peer_id := peer.generate_unique_id()
    var error := peer.create_mesh(peer_id)
    if error:
        return error
    multiplayer.multiplayer_peer = peer

    player_info.peer_id = peer_id
    players[index] = player_info
    joined_table.emit(player_info.lobby_id)

    return OK

func client_disconnect():
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    _matchmaking_server_disconnect()

    players.clear()
    chat_log.clear()
    left_table.emit()

func _register_player(new_player_info: Dictionary, index: String) -> void:
    new_player_info.is_self = false
    players[index] = new_player_info
    player_connected.emit(index)

func _connect_peer(index: String, preexisting: bool) -> Error:
    var peer := WebRTCPeerConnection.new()
    var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer

    var peer_id := rtc_peer.generate_unique_id()
    players[index].peer_id = peer_id

    peer.initialize({
        "iceServers": [ { "urls": [DEFAULT_STUN_SERVER] } ],
    })
    peer.session_description_created.connect(_offer_created.bind(index))
    peer.ice_candidate_created.connect(_candidate_created.bind(index))
    var error := rtc_peer.add_peer(peer, peer_id)
    if error:
        printerr("Failed to add WebRTC peer: " + error_string(error))
        return error

    # Existing peers will create offer when a new peer connects, the new peer
    # should not create an offer for existing peers
    if not preexisting:
        error = peer.create_offer()
        if error:
            printerr("Failed to create offer for new WebRTC peer: " + error_string(error))
            return error

    return OK

func _offer_created(type: String, data: String, index: String) -> void:
    print(player_info.name + ": Offer created")
    var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
    rtc_peer.get_peer(players[index].peer_id).connection.set_local_description(type, data)
    if type == "offer":
        _matchmaking_server_send(SignalServer.Message.OFFER, data, index)
    else:
        _matchmaking_server_send(SignalServer.Message.ANSWER, data, index)

func _candidate_created(mid_name: String, index_name: int, sdp_name: String, index: String) -> void:
    print(player_info.name + ": Candidate created")
    _matchmaking_server_send(SignalServer.Message.CANDIDATE, "\n%s\n%d\n%s" % [mid_name, index_name, sdp_name], index)

func _disconnect_peer(index: String):
    var peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
    if players.has(index):
        var player: Dictionary = players[index]

        if peer.has_peer(player.peer_id):
            peer.remove_peer(player.peer_id)
        players.erase(index)

        player_disconnected.emit(player)
