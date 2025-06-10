extends Node

@onready var chat := $PanelContainer/Chat
@onready var chat_message := $ChatMessage
@onready var send_chat_button := $SendChatMessage
@onready var client := $MultiplayerClient

func _process(_delta: float) -> void:
    client.poll_matchmaking_server()

func _init_lobby() -> void:
    chat.clear()
    send_chat_button.disabled = false
    chat_message.grab_focus()

func create_table(player_name: String) -> Error:
    client.player_info.is_host = true

    return join_table(SignalServer.DEFAULT_SERVER_IP, SignalServer.DEFAULT_PORT, player_name)

func join_table(address: String, port: int, player_name: String) -> Error:
    client.player_info.name = player_name

    return client.matchmaking_server_connect(address, port)

func send_chat_message(message: String, sender_player_info = client.player_info) -> void:
    receive_chat_message.rpc(sender_player_info, message)
    show_chat_message(sender_player_info.name + ": " + message)

@rpc("any_peer", "reliable")
func receive_chat_message(sender_player_info, message: String) -> void:
    show_chat_message(sender_player_info.name + ": " + message)

func sanitize_message(message: String) -> String:
    return message.xml_escape().strip_escapes().strip_edges()

func show_chat_message(message: String) -> void:
    chat.add_text(sanitize_message(message) + "\n")

func _on_send_chat_message() -> void:
    if !send_chat_button.disabled:
        send_chat_message(chat_message.text)
        chat_message.clear()
        chat_message.grab_focus.call_deferred()

func _on_exit_lobby() -> void:
    client.client_disconnect()
    get_parent().remove_child(self)

func _on_multiplayer_client_left_table() -> void:
    show_chat_message("Disconnected from lobby")

func _on_multiplayer_client_player_connected(peer_id: Variant) -> void:
    var new_player_info: Dictionary = client.players[peer_id]
    if not new_player_info.preexisting:
        show_chat_message("%s has entered the lobby" % new_player_info.name)
    elif new_player_info.is_host:
        show_chat_message("Connected to lobby")

func _on_multiplayer_client_player_disconnected(player_info) -> void:
    show_chat_message("%s has left the lobby" % player_info.name)
