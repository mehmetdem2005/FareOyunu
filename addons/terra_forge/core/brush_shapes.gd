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
