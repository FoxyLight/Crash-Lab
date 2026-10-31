extends RefCounted
## Original procedural mono PCM cues. Cached once; no external audio assets.
const RATE: int = 22050
const RECIPES = {
	&"wood_break": [240.0, -600.0, 0.25, 0.7],
	&"barrier_break": [90.0, -110.0, 0.4, 0.8],
	&"hazard_blast": [55.0, -40.0, 0.5, 0.85],
	&"crash_minor": [260.0, -700.0, 0.10, 0.65],
	&"crash_moderate": [140.0, -220.0, 0.22, 0.78],
	&"crash_major": [65.0, -55.0, 0.38, 0.85],
	&"repair": [650.0, 1800.0, 0.22, 0.0],
	&"heavy_shot": [160.0, -150.0, 0.25, 0.45],
	&"player_shot": [1100.0, -8500.0, 0.085, 0.12],
	&"enemy_shot": [330.0, -1300.0, 0.14, 0.15],
	&"impact": [180.0, -300.0, 0.07, 0.8],
	&"hit": [1600.0, 2000.0, 0.06, 0.05],
	&"damage": [100.0, -40.0, 0.15, 0.4],
	&"destroyed": [90.0, -60.0, 0.45, 0.75],
	&"respawn": [400.0, 900.0, 0.3, 0.02],
	&"victory": [440.0, 0.0, 0.65, 0.0],
	&"defeat": [330.0, 0.0, 0.65, 0.0],
	&"draw": [350.0, 0.0, 0.45, 0.0]
}
static var cache: Dictionary = {}

static func get_stream(cue: StringName) -> AudioStreamWAV:
	if cache.has(cue):
		return cache[cue]
	if not RECIPES.has(cue):
		return null
	var recipe: Array = RECIPES[cue]
	var duration: float = recipe[2]
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = hash(cue)
	var phase: float = 0.0
	for i in count:
		var t := float(i) / RATE
		var frequency: float = maxf(25.0, recipe[0] + recipe[1] * t)
		var envelope := minf(t / 0.004, 1.0) * pow(1.0 - t / duration, 2.0)
		if cue in [&"victory", &"defeat", &"draw"]:
			var note := mini(2, int(t / duration * 3.0))
			var ratios: Array = [1.0, 1.25, 1.5] if cue == &"victory" else ([1.0, 0.8, 0.6] if cue == &"defeat" else [1.0, 1.0, 1.0])
			frequency = recipe[0] * ratios[note]
			var segment := fmod(t, duration / 3.0) / (duration / 3.0)
			envelope = pow(sin(PI * segment), 2.0) * 0.8
		phase += TAU * frequency / RATE
		var sample: float = lerpf(sin(phase), random.randf_range(-1.0, 1.0), recipe[3]) * envelope * 0.6
		data.encode_s16(i * 2, int(clampf(sample, -0.6, 0.6) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	cache[cue] = stream
	return stream
