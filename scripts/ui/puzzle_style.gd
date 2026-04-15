class_name PuzzleStyle
extends RefCounted

# Shared visual language for puzzle UI. Keep palette + factory methods
# centralised so nonogram and sudoku stay coherent but distinct.

# --- Nonogram aesthetic: organic, image-reveal, warm mosaic ---
const NONO_BG := Color(0.11, 0.1, 0.13)
const NONO_PANEL := Color(0.16, 0.14, 0.18)

# Per-floor accent shift: warm on floor 1, cool on floor 2, ominous on floor 3+
const FLOOR_ACCENTS: Array[Color] = [
	Color(0.95, 0.72, 0.35),  # floor 1 — amber
	Color(0.45, 0.72, 0.95),  # floor 2 — steel blue
	Color(0.85, 0.3, 0.45),   # floor 3 — blood crimson
]
const NONO_CELL_EMPTY := Color(0.19, 0.18, 0.22)
const NONO_CELL_FILLED := Color(0.94, 0.92, 0.88)
const NONO_CELL_MARKED := Color(0.42, 0.23, 0.26)
const NONO_CELL_BORDER := Color(1, 1, 1, 0.05)
const NONO_ACCENT := Color(0.95, 0.72, 0.35)
const NONO_CLUE_FG := Color(0.88, 0.84, 0.78)
const NONO_CLUE_DONE := Color(0.88, 0.84, 0.78, 0.35)
const NONO_CELL_WRONG_OUTLINE := Color(0.95, 0.35, 0.35)

# --- Sudoku aesthetic: cool, ledger / ledger-book feel ---
const SUDO_BG := Color(0.08, 0.1, 0.13)
const SUDO_PANEL := Color(0.12, 0.14, 0.18)
const SUDO_CELL_BLANK := Color(0.17, 0.19, 0.24)
const SUDO_CELL_GIVEN := Color(0.1, 0.12, 0.15)
const SUDO_CELL_SELECTED := Color(0.33, 0.48, 0.72)
const SUDO_CELL_RELATED := Color(0.22, 0.28, 0.38)      # same row/col/box
const SUDO_CELL_MATCH := Color(0.25, 0.35, 0.5)          # same number as selected
const SUDO_CELL_CONFLICT_TINT := Color(0.55, 0.2, 0.25)  # cell that violates
const SUDO_TEXT_GIVEN := Color(0.96, 0.95, 0.92)
const SUDO_TEXT_ENTERED := Color(0.55, 0.85, 1.0)
const SUDO_TEXT_CONFLICT := Color(1, 0.55, 0.55)
const SUDO_GRID_MAJOR := Color(0.55, 0.6, 0.7)
const SUDO_ACCENT := Color(0.45, 0.75, 0.95)

# --- Typography scale ---
const FONT_CLUE := 15
const FONT_BUTTON := 14
const FONT_DIGIT := 28
const FONT_DISPLAY := 36  # boss name / headline

# --- Factories -----------------------------------------------------------

static func cell_style(bg: Color, corner: int = 4, border_w: int = 1,
		border_color: Color = Color(1, 1, 1, 0.04)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.border_color = border_color
	return sb

static func outlined_cell_style(bg: Color, outline: Color, outline_w: int = 3,
		corner: int = 4) -> StyleBoxFlat:
	var sb: StyleBoxFlat = cell_style(bg, corner, outline_w, outline)
	return sb

static func panel_style(bg: Color, accent: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_color = accent.lerp(bg, 0.65)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

static func button_style(bg: Color, hover_tint: float = 0.12,
		accent: Color = Color(1, 1, 1, 0.18)) -> Dictionary:
	var normal: StyleBoxFlat = cell_style(bg, 6, 1, accent)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover: StyleBoxFlat = cell_style(bg.lightened(hover_tint), 6, 1, accent)
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	var pressed: StyleBoxFlat = cell_style(bg.darkened(0.1), 6, 1, accent)
	pressed.content_margin_left = 12
	pressed.content_margin_right = 12
	pressed.content_margin_top = 6
	pressed.content_margin_bottom = 6
	return {"normal": normal, "hover": hover, "pressed": pressed}

static func apply_button_style(btn: Button, styles: Dictionary) -> void:
	btn.add_theme_stylebox_override("normal", styles.normal)
	btn.add_theme_stylebox_override("hover", styles.hover)
	btn.add_theme_stylebox_override("pressed", styles.pressed)
	btn.add_theme_font_size_override("font_size", FONT_BUTTON)

static func contrast_text(c: Color) -> Color:
	var lum: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Color.BLACK if lum > 0.55 else Color.WHITE

static func accent_for_floor(floor_num: int) -> Color:
	var idx: int = clamp(floor_num - 1, 0, FLOOR_ACCENTS.size() - 1)
	return FLOOR_ACCENTS[idx]

# Cheap deterministic per-tile variation: filled nonogram cells apply a
# small brightness jitter by position so the picture reads as textured
# instead of flat blocks of colour. No assets, no StyleBoxTexture needed.
static func variegate(base: Color, x: int, y: int, amount: float = 0.06) -> Color:
	var h: int = (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	var noise: float = ((h & 0xff) / 255.0 - 0.5) * 2.0 * amount
	var gradient: float = (float(x + y) * 0.015) - 0.02
	var delta: float = noise + gradient
	return Color(
		clamp(base.r + delta, 0, 1),
		clamp(base.g + delta, 0, 1),
		clamp(base.b + delta, 0, 1),
		base.a)
