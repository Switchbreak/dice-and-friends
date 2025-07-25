extends ItemList

const HIGHLIGHT_COLOR: Color = Color("ffffff")
const HOST_APPEND: String = " (host)"

@onready var client := $"/root/HomeScreen/Lobby/MultiplayerClient"

func refresh_list() -> void:
    clear()
    for id: int in client.players:
        var player = client.players[id]
        var player_name = player.name
        if player.is_host:
            player_name += HOST_APPEND
        var index = add_item(player_name)
        if player.is_self:
            set_item_custom_fg_color(index, HIGHLIGHT_COLOR)
