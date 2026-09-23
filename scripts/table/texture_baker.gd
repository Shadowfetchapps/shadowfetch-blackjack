class_name TextureBaker
extends RefCounted
## Renders a Node2D painter once in an offscreen SubViewport and returns a static,
## mipmapped ImageTexture (viewport textures have no mipmaps and shimmer at an angle).


static func bake(host: Node, size: Vector2i, painter: Node2D, mipmaps: bool = true) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		painter.free()
		return null
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	vp.add_child(painter)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	if mipmaps:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
