## Camera ray math done by hand, from the camera's physics-tick transform.
## Why not Camera3D.project_ray_*? With physics interpolation on, those can use the
## interpolated (render) transform, which depends on frame timing. Doing it ourselves keeps
## touch → world mapping identical for identical input (determinism rule).
##
## Pinhole camera, Godot's default KEEP_HEIGHT aspect: `fov` is the vertical field of view.
## A screen point p maps to normalised device coords ndc ∈ [-1,1]² (y up), and the ray
## direction in camera space is (ndc.x·tan(fov/2)·aspect, ndc.y·tan(fov/2), -1).
class_name ScreenMath
extends RefCounted


## Returns [origin: Vector3, direction: Vector3 (normalised)] for a screen point.
static func ray(cam: Camera3D, screen_size: Vector2, p: Vector2) -> Array:
	var xf := cam.global_transform
	var t := tan(deg_to_rad(cam.fov) * 0.5)
	var aspect := screen_size.x / screen_size.y
	var ndc := Vector2(2.0 * p.x / screen_size.x - 1.0, 1.0 - 2.0 * p.y / screen_size.y)
	var dir_cam := Vector3(ndc.x * t * aspect, ndc.y * t, -1.0)
	return [xf.origin, (xf.basis * dir_cam).normalized()]


## World point → screen point (inverse of `ray`). Returns null if behind the camera.
static func project(cam: Camera3D, screen_size: Vector2, world: Vector3) -> Variant:
	var pc := cam.global_transform.affine_inverse() * world
	if pc.z > -0.0001:
		return null
	var t := tan(deg_to_rad(cam.fov) * 0.5)
	var aspect := screen_size.x / screen_size.y
	var ndc := Vector2(pc.x / (-pc.z * t * aspect), pc.y / (-pc.z * t))
	return Vector2((ndc.x + 1.0) * 0.5 * screen_size.x, (1.0 - ndc.y) * 0.5 * screen_size.y)


## Ray/plane intersection. Plane = all x with (x - point)·normal = 0.
## Solve (o + d·s - point)·n = 0  →  s = (point - o)·n / (d·n). Null if parallel or behind.
static func ray_plane(r: Array, point: Vector3, normal: Vector3) -> Variant:
	var denom: float = r[1].dot(normal)
	if absf(denom) < 1e-6:
		return null
	var s: float = (point - r[0]).dot(normal) / denom
	if s < 0.0:
		return null
	return r[0] + r[1] * s
