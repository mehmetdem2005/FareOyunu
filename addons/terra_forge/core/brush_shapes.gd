@tool
extends RefCounted
## Pure, deterministic normalized profiles used by TerraForge sculpt tools.
## All profiles return zero at/beyond the radius, preventing square stamp seams.
const TOOL_RAISE: int = 0
const TOOL_LOWER: int = 1
const TOOL_SMOOTH: int = 2
const TOOL_FLATTEN: int = 3
const TOOL_RIDGE: int = 4
const TOOL_VALLEY: int = 5
const TOOL_RAMP: int = 6
const TOOL_STAMP: int = 7
const TOOL_WEATHER: int = 8

const STAMP_HILL: int = 0
const STAMP_CRATER: int = 1
const STAMP_MESA: int = 2

static func ridge(u: float) -> float:
    if u >= 1.0:
        return 0.0
    return pow(1.0 - maxf(0.0, u), 4.0)

static func valley(u: float) -> float:
    if u >= 1.0:
        return 0.0
    return pow(1.0 - maxf(0.0, u), 2.5)

static func blend(u: float) -> float:
    if u >= 1.0:
        return 0.0
    var t: float = clampf(1.0 - u, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

static func stamp(preset: int, u: float) -> float:
    if u >= 1.0:
        return 0.0
    var r: float = maxf(0.0, u)
    match preset:
        STAMP_CRATER:
            # Depressed center with a raised lip around 75% of the radius.
            var bowl: float = -pow(1.0 - r * r, 2.0)
            var lip: float = exp(-pow((r - 0.75) / 0.14, 2.0))
            var edge: float = clampf((1.0 - r) / 0.15, 0.0, 1.0)
            return bowl + lip * edge
        STAMP_MESA:
            # Flat center; 38-100% forms a smooth shoulder.
            if r <= 0.38:
                return 1.0
            var x: float = clampf((r - 0.38) / 0.62, 0.0, 1.0)
            return 1.0 - x * x * (3.0 - 2.0 * x)
        _:
            # Rounded hill with a smoothly vanishing boundary.
            return pow(1.0 - r * r, 3.0)

## One coherent world-space warp gives each stamp a less mechanical outline.
## The unwarped radial envelope reaches exactly zero at the brush radius,
## preventing seams at adjacent stamps and protecting the Undo boundary.
static func organic_stamp(
        preset: int,
        world: Vector2,
        center: Vector2,
        radius: float,
        noise: FastNoiseLite
    ) -> float:
    var safe_radius: float = maxf(0.001, radius)
    var delta: Vector2 = world - center
    var base_r: float = delta.length() / safe_radius
    if base_r >= 1.0:
        return 0.0
    # One low-frequency sample per texel, not an expensive per-pixel
    # fractal simulation. Noise is anchored in world coordinates.
    var irregularity: float = noise.get_noise_2d(world.x, world.y) * 0.105
    var rotated: Vector2 = delta.rotated(0.51)
    var ellipse_r: float = Vector2(rotated.x * 0.92, rotated.y * 1.08).length() / safe_radius
    var warped_r: float = clampf(lerpf(base_r, ellipse_r, 0.6) + irregularity * base_r, 0.0, 1.0)
    # The final 18% of the radius tapers to zero even if the noise
    # pulls the underlying procedural form slightly beyond its edge.
    var edge: float = clampf((1.0 - base_r) / 0.18, 0.0, 1.0)
    edge = edge * edge * (3.0 - 2.0 * edge)
    return stamp(preset, warped_r) * edge
