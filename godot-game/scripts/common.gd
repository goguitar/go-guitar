extends Node
## Common.gd - Shared constants and utility functions for Go-Guitar

const FRET_COUNT : int = 24
const STRING_COUNT : int = 6
const SCALE_LENGTH : float = 300.0
const FRET_WORLD_WIDTH : float = 25.0
const STRING_SLOT_HEIGHT : float = 1.2
const STRING_HEIGHT_SCALE : float = 1.0

const STRING_COLORS: Array[Color] = [
	Color(0.98, 0.26, 0.22, 1.0),
	Color(0.98, 0.78, 0.16, 1.0),
	Color(0.20, 0.80, 0.95, 1.0),
	Color(1.00, 0.55, 0.10, 1.0),
	Color(0.20, 0.88, 0.30, 1.0),
	Color(0.72, 0.38, 0.98, 1.0),
]

static func chart_fret_pos(fret_num: float) -> float:
	return SCALE_LENGTH - (SCALE_LENGTH / pow(2.0, fret_num / 12.0))

static func fret_separator_world_x(fret_num: int) -> float:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return 0.0
	return chart_fret_pos(float(fret_num)) / max_pos * FRET_WORLD_WIDTH

static func fret_mid_world_x(fret_num: int) -> float:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return 0.0
	var curr := chart_fret_pos(float(fret_num))
	var nxt := chart_fret_pos(float(fret_num) + 1.0)
	return (curr + nxt) * 0.5 / max_pos * FRET_WORLD_WIDTH

static func string_world_y(str_idx: int) -> float:
	return (3.0 + float(5 - str_idx) * 4.0) * STRING_HEIGHT_SCALE

static func note_indicator_size(fret_num: int) -> Vector2:
	var max_pos: float = chart_fret_pos(float(FRET_COUNT))
	if max_pos <= 0.001:
		return Vector2(1.0, 0.8)
	var curr := chart_fret_pos(float(fret_num))
	var nxt := chart_fret_pos(float(fret_num) + 1.0)
	var w := (nxt - curr) / max_pos * FRET_WORLD_WIDTH
	var h := STRING_SLOT_HEIGHT * 0.8
	return Vector2(maxf(w, 0.3), maxf(h, 0.6))
