extends Control

#var lobby_scene := preload("res://lobby_scene.tscn").instantiate()
var lobby_scene := preload("res://table_scene.tscn").instantiate()

@onready var player_name := $SelectName/Name
@onready var join_panel := $JoinPanel
@onready var table_id_input := $JoinPanel/TableID
@onready var join_button := $JoinPanel/Join

func _show_lobby() -> void:
    add_child(lobby_scene)
    lobby_scene.tree_exited.connect(_on_lobby_exit)
    visible = false

func _on_host_game_pressed() -> void:
    _show_lobby()
    lobby_scene.create_table(player_name.text)

func _on_join_game_pressed() -> void:
    join_panel.visible = !join_panel.visible

func _on_table_id_text_changed(new_text: String) -> void:
    join_button.disabled = new_text.is_empty()

func _on_join_pressed() -> void:
    var ip: String = SignalServer.DEFAULT_SERVER_IP
    var port: int = SignalServer.DEFAULT_PORT
    var player: String = player_name.text
    var table_id: String = table_id_input.text

    _show_lobby()
    lobby_scene.join_table(ip, port, player, table_id)

func _on_lobby_exit() -> void:
    visible = true
