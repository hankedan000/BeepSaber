extends Node

# set to True to mute the saber cutting sound
var mute_cut_sound = false

# set to True to allow the cut cubes to collide. Note: having this enabled can
# lead to cut pieces hitting into each other and possibly ricocheting into the
# camera and blocking the players view
var enable_cut_collisions = false

# if set true, won't spawn cut cube chunks
var cube_instant_kill = false

# if set true, cubes will have collisions disabled
var cube_no_collisions = false

# how far ahead the game will spawn beats from the map. multiply this by
# BPS to get spawn ahead time in seconds.
var beats_ahead = 4.0;
