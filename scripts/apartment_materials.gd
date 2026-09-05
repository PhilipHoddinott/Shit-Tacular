extends RefCounted
## Small, deterministic, seamless textures; no external assets or downloads.

static func surface(kind: String, tint: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var value := 1.0
			if kind == "wood":
				var row := y / 32
				var offset := (row % 3) * 79
				var seam := (x + offset) % 256 < 2 or y % 32 < 2
				var grain := sin(float(x) * 0.17 + sin(float(y) * 0.8) * 2.0)
				value = 0.88 + 0.06 * grain + 0.035 * sin(float(row) * 4.7)
				if seam:
					value = 0.54
			elif kind == "tile":
				var seam := x % 64 < 2 or y % 64 < 2
				value = 0.93 + 0.025 * sin(float(x / 64 + y / 64) * 2.4)
				if seam:
					value = 0.62
			else:
				value = 0.93 + 0.035 * sin(float(x) * PI * 0.5) * sin(float(y) * PI * 0.5)
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.albedo_color = tint
	material.roughness = roughness
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * (0.416667 if kind != "fabric" else 3.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material
