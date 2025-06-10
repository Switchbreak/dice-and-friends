extends Control

var lobby_scene := preload("res://lobby_scene.tscn").instantiate()

@onready var player_name := $SelectName/Name
@onready var join_panel := $JoinPanel
@onready var join_ip := $JoinPanel/JoinIP
@onready var join_port := $JoinPanel/JoinPort
@onready var join_button := $JoinPanel/Join

func _ready() -> void:
    join_ip.text = SignalServer.DEFAULT_SERVER_IP
    join_port.text = str(SignalServer.DEFAULT_PORT)
    _on_join_ip_text_changed()

func _on_host_game_pressed() -> void:
    add_child(lobby_scene)
    lobby_scene.create_table(player_name.text)

func _on_join_game_pressed() -> void:
    join_panel.visible = !join_panel.visible

func string_to_int(string: String) -> int:
    if string.is_valid_int():
        return string.to_int()
    else:
        return -1

func is_valid_port(port: int) -> bool:
    return port > 0 && port <= 65535

func _on_join_pressed() -> void:
    var ip: String = join_ip.text
    var port: int = string_to_int(join_port.text)
    var player: String = player_name.text

    if ip.is_valid_ip_address() and is_valid_port(port):
        add_child(lobby_scene)
        lobby_scene.join_table(ip, port, player)

func _on_join_ip_text_changed() -> void:
    var ip: String = join_ip.text
    var port: int = string_to_int(join_port.text)

    join_button.disabled = !(ip.is_valid_ip_address() && is_valid_port(port))
