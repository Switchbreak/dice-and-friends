extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected

@onready var chat := $PanelContainer/Chat
@onready var chat_message := $ChatMessage
@onready var send_chat_button := $SendChatMessage
@onready var signal_server := $SignalServer

const DEFAULT_STUN_SERVER: String = "stun:stun.l.google.com:19302"

var matchmaking_socket := WebSocketPeer.new()
var prev_state: WebSocketPeer.State

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_ok)
    multiplayer.connection_failed.connect(_on_connected_fail)
    multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(_delta: float) -> void:
    _poll_matchmaking_server()


func _init_lobby() -> void:
    TableValues.chat_log.clear()
    chat.clear()
    send_chat_button.disabled = false
    chat_message.grab_focus()


#region Matchmaking server communication

func _matchmaking_server_start(port: int) -> Error:
    var error: Error = signal_server.listen(port)
    if error:
        printerr("Failed to start to matchmaking server: " + error_string(error))
        return error

    return OK


func _matchmaking_server_connect(url: String) -> Error:
    var error := matchmaking_socket.connect_to_url(url)
    if error:
        printerr("Failed to connect to matchmaking server: " + error_string(error))
        return error

    prev_state = WebSocketPeer.STATE_CONNECTING
    return OK


func _matchmaking_server_disconnect() -> void:
    matchmaking_socket.close()
    print("Disconnecting from matchmaking server")


func _matchmaking_server_disconnected() -> void:
    var code := matchmaking_socket.get_close_code()
    var reason := matchmaking_socket.get_close_reason()
    printerr("Disconnected from matchmaking server: %d - %s" % [code, reason])


func _matchmaking_server_send(type: int, data: String, index: int = -1) -> void:
    matchmaking_socket.send_text(JSON.stringify({
        "type": type,
        "data": data,
        "peer_index": index,
    }))


func _poll_matchmaking_server() -> void:
    matchmaking_socket.poll()

    var state := matchmaking_socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        _receive_matchmaking_messages()
        if state != prev_state:
            # When connection first opens, send notification to matchmaking server
            _matchmaking_server_send(signal_server.Message.PEER_CONNECT, TableValues.player_info.name)

    elif state == WebSocketPeer.STATE_CLOSED and state != prev_state:
        _matchmaking_server_disconnected()

    prev_state = state


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
    print(TableValues.player_info.name + ": Received packet from matchmaking server: " + packet)

    var message: Dictionary = JSON.parse_string(packet)
    var peer_index := int(message.peer_index)

    match int(message.type):
        signal_server.Message.SET_ID:
            init_rtc(peer_index)
        signal_server.Message.PEER_CONNECT:
            _register_player({"name": message.data}, peer_index)
            _connect_peer(peer_index)
        signal_server.Message.PEER_DISCONNECT:
            _on_player_disconnected(peer_index)
        signal_server.Message.OFFER:
            var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
            print(TableValues.player_info.name + ": Offer received")
            if rtc_peer.has_peer(peer_index):
                rtc_peer.get_peer(peer_index).connection.set_remote_description("offer", message.data)
        signal_server.Message.ANSWER:
            var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
            print(TableValues.player_info.name + ": Answer received")
            if rtc_peer.has_peer(peer_index):
                rtc_peer.get_peer(peer_index).connection.set_remote_description("answer", message.data)
        signal_server.Message.CANDIDATE:
            var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
            print(TableValues.player_info.name + ": Candidate received")
            var candidate: PackedStringArray = message.data.split("\n", false)
            if rtc_peer.has_peer(peer_index):
                rtc_peer.get_peer(peer_index).connection.add_ice_candidate(candidate[0], candidate[1].to_int(), candidate[2])

    return OK

#endregion


func create_table() -> Error:
    var error := _matchmaking_server_start(TableValues.DEFAULT_PORT)
    if error:
        return error

    TableValues.player_info.is_host = true

    return join_table(TableValues.DEFAULT_SERVER_IP, TableValues.DEFAULT_PORT)

    #var peer = WebRTCMultiplayerPeer.new()
    #var error = peer.create_server()
    #if error:
        #return error
    #multiplayer.multiplayer_peer = peer
    #var player_id = peer.get_unique_id()
    #TableValues.player_info.is_host = true
    #TableValues.players[player_id] = TableValues.player_info
    #player_connected.emit(player_id)
#
    #var ips = IP.get_local_addresses()
    #$ServerIPLabel.visible = true
    #$ServerIP.text = ips[ips.size() - 1] + ":" + str(TableValues.DEFAULT_PORT)
    #$ServerIP.visible = true
#
    #_init_lobby()
    #show_chat_message("Table created by %s" % TableValues.player_info.name)



func join_table(address: String = "", port: int = TableValues.DEFAULT_PORT) -> Error:
    var error := _matchmaking_server_connect("ws://%s:%s" % [address, port])
    if error:
        return error

    return OK

    #if address.is_empty():
        #address = TableValues.DEFAULT_SERVER_IP
    #var peer = ENetMultiplayerPeer.new()
    #var error = peer.create_client(address, port)
    #if error:
        #return error
    #multiplayer.multiplayer_peer = peer
    #TableValues.player_info.is_host = false
    #$ServerIPLabel.visible = false
    #$ServerIP.visible = false
    #_init_lobby()


func init_rtc(index: int) -> Error:
    var peer := WebRTCMultiplayerPeer.new()
    var error := peer.create_mesh(index)
    if error:
        return error
    multiplayer.multiplayer_peer = peer

    TableValues.players[index] = TableValues.player_info
    player_connected.emit(index)

    return OK


func remove_multiplayer_peer():
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    TableValues.players.clear()
    show_chat_message("Disconnected from lobby")


func sanitize_message(message: String) -> String:
    return message.xml_escape().strip_escapes().strip_edges()


@rpc("any_peer", "reliable")
func receive_chat_message(sender_player_info, message: String) -> void:
    show_chat_message(sender_player_info.name + ": " + message)


func show_chat_message(message: String) -> void:
    chat.add_text(sanitize_message(message) + "\n")


func send_chat_message(message: String, sender_player_info = TableValues.player_info) -> void:
    receive_chat_message.rpc(sender_player_info, message)
    show_chat_message(sender_player_info.name + ": " + message)


@rpc("any_peer", "reliable")
func _register_player(new_player_info, index) -> void:
    #var new_player_id := multiplayer.get_remote_sender_id()
    new_player_info.is_self = false
    new_player_info.is_host = false
    TableValues.players[index] = new_player_info
    player_connected.emit(index)
    if multiplayer.is_server():
        send_chat_message("%s has entered the lobby" % new_player_info.name, { "name": "Server" })


func _connect_peer(index: int) -> Error:
    var peer := WebRTCPeerConnection.new()
    var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer

    peer.initialize({
        "iceServers": [ { "urls": [DEFAULT_STUN_SERVER] } ],
    })
    peer.session_description_created.connect(_offer_created.bind(index))
    peer.ice_candidate_created.connect(_candidate_created.bind(index))
    rtc_peer.add_peer(peer, index)
    if not TableValues.player_info.is_host:
        peer.create_offer()

    return OK


func _offer_created(type: String, data: String, index: int) -> void:
    print(TableValues.player_info.name + ": Offer created")
    var rtc_peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
    rtc_peer.get_peer(index).connection.set_local_description(type, data)
    if type == "offer":
        _matchmaking_server_send(signal_server.Message.OFFER, data, index)
    else:
        _matchmaking_server_send(signal_server.Message.ANSWER, data, index)


func _candidate_created(mid_name: String, index_name: int, sdp_name: String, index: int) -> void:
    print(TableValues.player_info.name + ": Candidate created")
    _matchmaking_server_send(signal_server.Message.CANDIDATE, "\n%s\n%d\n%s" % [mid_name, index_name, sdp_name], index)


func _on_player_connected(_id: int):
    #_register_player.rpc_id(id, TableValues.player_info)
    pass


func _on_player_disconnected(id: int):
    var peer: WebRTCMultiplayerPeer = multiplayer.multiplayer_peer
    if peer.has_peer(id):
        peer.remove_peer(id)
    if TableValues.players.has(id):
        show_chat_message("%s has left the lobby" % TableValues.players[id].name)
        TableValues.players.erase(id)
    player_disconnected.emit(id)


func _on_connected_ok():
    var peer_id = multiplayer.get_unique_id()
    TableValues.players[peer_id] = TableValues.player_info
    player_connected.emit(peer_id)
    show_chat_message("Successfully connected to lobby")


func _on_connected_fail():
    remove_multiplayer_peer()
    show_chat_message("Failed to connect to lobby")


func _on_server_disconnected():
    remove_multiplayer_peer()
    server_disconnected.emit()
    send_chat_button.disabled = true


func _on_send_chat_message() -> void:
    if !send_chat_button.disabled:
        send_chat_message(chat_message.text)
        chat_message.clear()
        chat_message.grab_focus.call_deferred()


func _on_exit_lobby() -> void:
    _matchmaking_server_disconnect()
    remove_multiplayer_peer()
    get_parent().remove_child(self)
    signal_server.stop()
