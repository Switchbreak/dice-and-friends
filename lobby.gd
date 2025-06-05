extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)
signal server_disconnected

@onready var chat := $PanelContainer/Chat
@onready var chat_message := $ChatMessage

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_ok)
    multiplayer.connection_failed.connect(_on_connected_fail)
    multiplayer.server_disconnected.connect(_on_server_disconnected)


func create_table():
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_server(TableValues.DEFAULT_PORT)
    if error:
        return error
    multiplayer.multiplayer_peer = peer
    var player_id = peer.get_unique_id()
    TableValues.player_info.is_host = true
    TableValues.players[player_id] = TableValues.player_info
    player_connected.emit(player_id)
    show_chat_message("Table created by %s" % TableValues.player_info.name)


func join_table(address: String = ""):
    if address.is_empty():
        address = TableValues.DEFAULT_SERVER_IP
    var peer = ENetMultiplayerPeer.new()
    var error = peer.create_client(address, TableValues.DEFAULT_PORT)
    if error:
        return error
    multiplayer.multiplayer_peer = peer
    TableValues.player_info.is_host = false


func remove_multiplayer_peer():
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
func _register_player(new_player_info):
    var new_player_id := multiplayer.get_remote_sender_id()
    new_player_info.is_self = false
    TableValues.players[new_player_id] = new_player_info
    player_connected.emit(new_player_id)
    if multiplayer.is_server():
        send_chat_message("%s has entered the lobby" % new_player_info.name, { "name": "Server" })


func _on_player_connected(id: int):
    _register_player.rpc_id(id, TableValues.player_info)


func _on_player_disconnected(id: int):
    if TableValues.players[id]:
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


func _on_server_disconnected():
    remove_multiplayer_peer()
    server_disconnected.emit()


func _on_send_chat_message() -> void:
    send_chat_message(chat_message.text)
    chat_message.clear()
    chat_message.grab_focus()
