extends Node

const SERVER_PORT = 6868
const MAX_PLAYERS = 1

var peer := NetworkedMultiplayerENet.new()
var hostname = "10.0.0.235"

func _ready():
	peer.connect("connection_succeeded",self,"_on_connection_succeeded")
	peer.connect("connection_failed",self,"_on_connection_failed")
	
	if vr.inVR:
		peer.create_server(SERVER_PORT, MAX_PLAYERS)
		vr.log_info("created server @ port %d" % SERVER_PORT)
	else:
		vr.log_info("creating client to host %s:%d" % [hostname,SERVER_PORT])
		peer.create_client(hostname,SERVER_PORT)
	get_tree().network_peer = peer
	
remote func update_player_info(player_info):
#	vr.log_info("got new player info. %s" % player_info)
	vr.rightController.global_transform = player_info['r_ctrl']
	vr.leftController.global_transform = player_info['l_ctrl']
	
func _on_connection_succeeded():
	vr.log_info("connected!")

func _on_connection_failed():
	vr.log_info("connection failed!")
