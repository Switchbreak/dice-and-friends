extends Node

const DEFAULT_SERVER_IP = "127.0.0.1" # IPv4 localhost
const DEFAULT_PORT = 7000

var players := {}
var chat_log: Array[String]
var player_info = {
    "name": "Name",
    "is_host": false,
    "is_self": true
}

var server_ip := DEFAULT_SERVER_IP
var server_port := DEFAULT_PORT
