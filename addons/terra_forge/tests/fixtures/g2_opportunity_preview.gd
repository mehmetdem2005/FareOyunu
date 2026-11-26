extends "res://addons/terra_forge/terrain/paged_terrain_preview.gd"
const OBS_W=preload("res://addons/terra_forge/core/geometry_worker.gd")
var observed: Dictionary={"published":0,"new_tile":0,"lod_change":0,"same_signature":0,"effective_seam_change":0,"signature_only":0,"height_edge_change":0,"collision_changed":0,"unknown":0}
func _publish_geometry(key: Vector2i,lod: int,generated: Dictionary,started: int) -> Error:
    var kind: String="unknown"
    var height_edge: bool=false
    var collision_changed: bool=false
    if not _tiles.has(key):
        kind="new_tile"
    else:
        var tile: Dictionary=_tiles[key]
        if tile.get("lod",-1)!=lod:
            kind="lod_change"
        else:
            var prev: Array=tile.get("levels",[])
            var sig: Dictionary=OBS_W.signature(key,lod,_desired_tiles,_reader.cells)
            if prev.size()==4 and sig.get("error",FAILED)==OK:
                var next: Array=sig["levels"]
                if prev==next:
                    kind="same_signature"
                else:
                    kind="signature_only"
                    for i in range(4):
                        if maxi(lod,int(prev[i]))!=maxi(lod,int(next[i])):
                            height_edge=true
                        if maxi(lod,int(prev[i]))!=maxi(lod,int(next[i])) or (prev[i]==lod)!=(next[i]==lod):
                            kind="effective_seam_change"
                    if lod==0 and kind=="effective_seam_change":
                        var shape: HeightMapShape3D=tile["collision"].shape as HeightMapShape3D
                        if shape!=null:
                            collision_changed=shape.map_data!=generated["collision_heights"]
    var result: Error=super._publish_geometry(key,lod,generated,started)
    if result==OK:
        observed["published"]+=1
        observed[kind]+=1
        observed["height_edge_change"]+=int(height_edge)
        observed["collision_changed"]+=int(collision_changed)
    return result
