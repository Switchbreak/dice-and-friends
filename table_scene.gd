extends Node3D

@onready var client := $MultiplayerClient

func _process(_delta: float) -> void:
    client.poll_matchmaking_server()

func create_table(player_name: String) -> Error:
    client.player_info.is_host = true

    return join_table(SignalServer.DEFAULT_SERVER_IP, SignalServer.DEFAULT_PORT, player_name)

func join_table(address: String, port: int, player_name: String) -> Error:
    client.player_info.name = player_name

    return client.matchmaking_server_connect(address, port)
