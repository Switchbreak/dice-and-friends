extends Control

var lobby_scene := preload("res://lobby_scene.tscn").instantiate()
@onready var player_name := $SelectName/Name


func init_lobby_scene() -> void:
    lobby_scene.player_info.name = player_name.text
    add_child(lobby_scene)


func _on_host_game_pressed() -> void:
    init_lobby_scene()
    lobby_scene.create_game()


func _on_join_game_pressed() -> void:
    init_lobby_scene()
    lobby_scene.join_game()
