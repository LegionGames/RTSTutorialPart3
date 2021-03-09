extends AudioStreamPlayer

export var bpm := 100
export var offset := 0.0

var song_position = 0.0
var song_position_in_beats = 0
var sec_per_beat = 60.0 / bpm
var last_reported_beat = 0

var closest = 0
var time_off_beat = 0.0

signal beat(position)


func _ready():
	sec_per_beat = 60.0 / bpm


func _physics_process(_delta):
	song_position = offset + get_playback_position() + AudioServer.get_time_since_last_mix()
	song_position -= AudioServer.get_output_latency()
	song_position_in_beats = int(floor(song_position / sec_per_beat))
	if last_reported_beat < song_position_in_beats:
		emit_signal("beat", song_position_in_beats)
		last_reported_beat = song_position_in_beats


func closest_beat(nth):
	closest = int(round((song_position / sec_per_beat) / nth) * nth) 
	time_off_beat = abs(closest * sec_per_beat - song_position)
	return Vector2(closest, time_off_beat)

func go_to_beat(beat):
	seek(beat * sec_per_beat)
