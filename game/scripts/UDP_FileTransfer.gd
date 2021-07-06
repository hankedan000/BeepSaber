extends Node

signal transfer_initiated()
signal received_file_data(file_data)

const CHUNK_SIZE = 60000
var packet_peer := PacketPeerUDP.new()

var _transfer_in_progress = false
var _data := PoolByteArray()

func listen(listen_port):
	var err = packet_peer.listen(listen_port)
	if err != OK:
		vr.log_error("Failed to init UDP_FileTranfer. %d" % [listen_port])
		
func send_file(file: File, dest_ip, dest_port):
	packet_peer.listen(dest_port)
	packet_peer.set_dest_address(dest_ip,dest_port)
	var file_size = file.get_len()
	var full_buffer = file.get_buffer(file_size)
	
	var num_chunks = ceil(float(file_size) / CHUNK_SIZE)
	var bytes_left = file_size
	var offset = 0
	var curr_chunk = 0
	while bytes_left > 0:
		var chunk_size = min(CHUNK_SIZE,file_size - offset)
		var chunk = {
			"curr_chunk" : curr_chunk,
			"num_chunks" : int(num_chunks),
			"data" : full_buffer.subarray(offset,offset + chunk_size - 1)
		}
		packet_peer.put_var(chunk,true)
		
		packet_peer.wait()
		var resp = packet_peer.get_var()
		
		offset += chunk_size
		bytes_left -= chunk_size
		curr_chunk += 1
		
	file.seek(0)
	
func _process(_delta):
	if packet_peer.is_listening():
		while packet_peer.get_available_packet_count() > 0:
			_transfer_in_progress = true
			var chunk = packet_peer.get_var(true)
			if chunk['curr_chunk'] == 0:
				_data = PoolByteArray()
				emit_signal("transfer_initiated")
			_data.append_array(chunk['data'])
			vr.log_info("received %d/%d chunks" % [chunk['curr_chunk'],chunk['num_chunks']])
			packet_peer.set_dest_address(packet_peer.get_packet_ip(),packet_peer.get_packet_port())
			packet_peer.put_var(true)
			if chunk['curr_chunk'] + 1 == chunk['num_chunks']:
				_transfer_in_progress = false
				emit_signal("received_file_data",_data)
			
