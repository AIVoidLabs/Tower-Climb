extends SceneTree
## Oyun simgesini gerçek kartal modelinden üretir: arduvaz kart + turkuaz hâle + yakın plan kartal.
## Çıktılar: res://assets/icon.png (512 px; proje/pencere simgesi) ve res://assets/icon.ico
## (256…16 px; exe ve görev çubuğu simgesi).
## Çalıştır (pencereli; headless'ta render yok):  godot --path . -s res://tools/icon/make_icon.gd

const SIZE: int = 1024
const PNG_SIZE: int = 512
const ICO_SIZES: Array[int] = [256, 128, 64, 48, 32, 24, 16]
const PNG_PATH: String = "res://assets/icon.png"
const ICO_PATH: String = "res://assets/icon.ico"
const MODEL_SCRIPT: String = "res://scripts/player/character_model.gd"

## Yakın plan: modelin simgedeki boyu ve ayak çizgisi (çerçevenin altında → baş ve omuzlar görünür).
const MODEL_PX: float = 1250.0
const FEET_Y: float = 1330.0
const YAW: float = -PI * 0.5 + 0.38
const MARGIN: float = 24.0
const CORNER: int = 210
const BORDER: int = 14
## Model dosyasıyla aynı oranlar (Tuning.MODEL_HEIGHT, MODEL_FRAME_RATIO); betik class_name kullanmaz.
const MODEL_HEIGHT: float = 88.0
const FRAME_RATIO: float = 1.6
const RENDER_FRAMES: int = 45

const CARD := Color(0.17, 0.21, 0.28)
const CARD_DARK := Color(0.08, 0.10, 0.15)
const BORDER_COLOR := Color(0.30, 0.55, 0.57)
const ACCENT := Color(0.42, 0.74, 0.76)

var _viewport: SubViewport
var _model: Node2D
var _frames: int = 0


func _initialize() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(SIZE, SIZE)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var card: Panel = _make_card()
	_viewport.add_child(card)
	card.add_child(_make_shade(card.size))
	card.add_child(_make_glow())
	var holder := Node2D.new()
	holder.position = Vector2(SIZE * 0.5, FEET_Y) - Vector2.ONE * MARGIN
	holder.scale = Vector2.ONE * (MODEL_PX / MODEL_HEIGHT)
	card.add_child(holder)
	_model = load(MODEL_SCRIPT).new()
	holder.add_child(_model)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_setup_model()
	if _frames < RENDER_FRAMES:
		return false
	_save(_viewport.get_texture().get_image())
	return true


## Model ilk karede kurulur; sonra açısı verilir ve kendi render'ı simge çözünürlüğüne büyütülür.
func _setup_model() -> void:
	_model.call(&"set_preview_yaw", YAW, true)
	var frame_units: float = MODEL_HEIGHT * FRAME_RATIO
	var px: int = roundi(frame_units * MODEL_PX / MODEL_HEIGHT)
	(_model.get_node("ModelViewport") as SubViewport).size = Vector2i(px, px)
	(_model.get_node("ModelSprite") as Sprite2D).scale = Vector2.ONE * (frame_units / px)


func _make_card() -> Panel:
	var card := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = CARD
	box.border_color = BORDER_COLOR
	box.set_corner_radius_all(CORNER)
	box.set_border_width_all(BORDER)
	box.anti_aliasing = true
	card.add_theme_stylebox_override(&"panel", box)
	card.position = Vector2.ONE * MARGIN
	card.size = Vector2.ONE * (SIZE - MARGIN * 2.0)
	card.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	return card


## Alta doğru koyulaşan gölge.
func _make_shade(size: Vector2) -> TextureRect:
	var texture := GradientTexture2D.new()
	texture.gradient = _gradient(Color(CARD_DARK, 0.0), Color(CARD_DARK, 0.9))
	texture.fill_from = Vector2(0.5, 0.35)
	texture.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = size
	return rect


## Başın arkasında yumuşak turkuaz hâle.
func _make_glow() -> TextureRect:
	var texture := GradientTexture2D.new()
	texture.gradient = _gradient(Color(ACCENT, 0.6), Color(ACCENT, 0.0))
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 512
	texture.height = 512
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = Vector2(860.0, 860.0)
	rect.position = Vector2(SIZE * 0.5, FEET_Y - MODEL_PX * 0.55) - rect.size * 0.5 - Vector2.ONE * MARGIN
	return rect


func _gradient(from: Color, to: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, from)
	gradient.set_color(1, to)
	return gradient


func _save(image: Image) -> void:
	image.convert(Image.FORMAT_RGBA8)
	var png := image.duplicate() as Image
	png.resize(PNG_SIZE, PNG_SIZE, Image.INTERPOLATE_LANCZOS)
	png.save_png(ProjectSettings.globalize_path(PNG_PATH))
	_save_ico(image, ProjectSettings.globalize_path(ICO_PATH))
	print("Simge yazıldı: ", PNG_PATH, ", ", ICO_PATH)


## ICO: başlık + dizin + PNG gömülü girdiler (Windows Vista ve sonrası destekler).
func _save_ico(source: Image, path: String) -> void:
	var blobs: Array[PackedByteArray] = []
	for size: int in ICO_SIZES:
		var image := source.duplicate() as Image
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		blobs.append(image.save_png_to_buffer())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_16(0)
	file.store_16(1)
	file.store_16(ICO_SIZES.size())
	var offset: int = 6 + 16 * ICO_SIZES.size()
	for i: int in ICO_SIZES.size():
		var size: int = ICO_SIZES[i]
		file.store_8(0 if size >= 256 else size)
		file.store_8(0 if size >= 256 else size)
		file.store_8(0)
		file.store_8(0)
		file.store_16(1)
		file.store_16(32)
		file.store_32(blobs[i].size())
		file.store_32(offset)
		offset += blobs[i].size()
	for blob: PackedByteArray in blobs:
		file.store_buffer(blob)
	file.close()
