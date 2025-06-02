extends ItemList

const HIGHLIGHT_COLOR: Color = Color("ffffff")

var players = {}


func _on_lobby_player_connected(peer_id: int, player_info: Variant, is_self: bool) -> void:
    var player_name = player_info.name
    if player_info.host:
        player_name += " (host)"
    var index = add_item(player_name)
    players[peer_id] = { "index": index, "player_info": player_info }

    if is_self:
        set_item_custom_fg_color(index, HIGHLIGHT_COLOR)


func _on_lobby_player_disconnected(peer_id: int) -> void:
    var player = players[peer_id]
    self.remove_item(player.index)
    players.erase(peer_id)
