@tool
extends RefCounted
## Conservative local-XZ swept AABB, NOT a continuous collision sweep.
## Reject before enumeration if footprint exceeds fixed work bound.
const MAX_TILES: int=16
static func plan(start: Vector2,finish: Vector2,radius: float,extent: Vector2,tile_size: float) -> Dictionary:
    if not start.is_finite() or not finish.is_finite() or not extent.is_finite() or not is_finite(radius) or not is_finite(tile_size) or radius<=0.0 or tile_size<=0.0 or extent.x<=0.0 or extent.y<=0.0:
        return {"ready":false,"reason":"invalid_input"}
    var lo: Vector2=start.min(finish)-Vector2.ONE*radius
    var hi: Vector2=start.max(finish)+Vector2.ONE*radius
    if lo.x<=0.0 or lo.y<=0.0 or hi.x>=extent.x or hi.y>=extent.y:
        return {"ready":false,"reason":"outside_world"}
    # Include the tile on either side of an exactly touched lower edge.
    var first=Vector2i(ceili(lo.x/tile_size)-1,ceili(lo.y/tile_size)-1)
    var last=Vector2i(floori(hi.x/tile_size),floori(hi.y/tile_size))
    var span: Vector2i=last-first+Vector2i.ONE
    if span.x>MAX_TILES or span.y>MAX_TILES or span.x*span.y>MAX_TILES:
        return {"ready":false,"reason":"footprint_cap"}
    var keys: Array[Vector2i]=[]
    for z in range(first.y,last.y+1):
        for x in range(first.x,last.x+1):
            keys.append(Vector2i(x,z))
    return {"ready":true,"reason":"planned","tiles":keys}
