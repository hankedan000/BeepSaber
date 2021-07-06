extends Node

const SERVER_PORT = 6868
const FILE_TRANSFER_PORT = 7272
const MAX_PLAYERS = 1

var peer := NetworkedMultiplayerENet.new()
var hostname = "10.0.0.235"

# TODO get this from handshake
var my_pc_ip = "10.0.0.10"

var beep_saber = null

onready var file_tranfer := $UDP_FileTransfer

func _ready():
	peer.connect("connection_succeeded",self,"_on_connection_succeeded")
	peer.connect("connection_failed",self,"_on_connection_failed")
	
	if vr.inVR:
		peer.create_server(SERVER_PORT, MAX_PLAYERS)
		vr.log_info("created server @ port %d" % SERVER_PORT)
	else:
		vr.log_info("creating client to host %s:%d" % [hostname,SERVER_PORT])
		peer.create_client(hostname,SERVER_PORT)
		file_tranfer.listen(FILE_TRANSFER_PORT)
	get_tree().network_peer = peer
	
remote func update_player_info(player_info):
#	vr.log_info("got new player info. %s" % player_info)
	vr.rightController.global_transform = player_info['r_ctrl']
	vr.leftController.global_transform = player_info['l_ctrl']
	
remote func send_map_info(info, map_data):
	if beep_saber != null:
		beep_saber.start_map(info,map_data)
		
func send_song_file(song_file: File):
	file_tranfer.send_file(song_file,my_pc_ip,FILE_TRANSFER_PORT)
	
func _on_connection_succeeded():
	vr.log_info("connected!")

func _on_connection_failed():
	vr.log_info("connection failed!")

func _on_UDP_FileTransfer_received_file_data(file_data: PoolByteArray):
	vr.log_info("Tranfer complete! %dbytes" % file_data.size())
	if beep_saber != null:
		var stream = AudioStreamOGGVorbis.new()
		stream.data = file_data
		beep_saber.song_player.stream = stream
		beep_saber.song_player.play(0)
		vr.log_info("Playing!")
