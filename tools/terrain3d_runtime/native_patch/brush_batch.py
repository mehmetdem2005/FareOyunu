#!/usr/bin/env python3
"""Native batch sculpt: apply after the packed RF upload patch.
No change to rendering formats, LOD, collision or file storage.
"""
from pathlib import Path
import sys
root = Path(sys.argv[1])
def edit(path, a, b):
    p = root / path
    s = p.read_text()
    if s.count(a) != 1:
        raise RuntimeError(f"Unexpected anchor: {path}: {a!r}")
    p.write_text(s.replace(a,b))
edit("src/terrain_3d_data.h",
    "void set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel);",
    """// TerraForge: bounded main-thread brush transaction on the authoritative RF maps.
	double tf_sample(const Vector2i &p) const;
	Dictionary tf_plan_brush(const Vector2 &center, int tool, double radius, double power, double flatten) const;
	Dictionary tf_write_brush(const Dictionary &values);
	void set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel);""")
edit("src/terrain_3d_data.cpp",
    '#include "terrain_3d_data.h"',
    '#include "terrain_3d_data.h"\n#include <algorithm>\n#include <array>\n#include <cmath>\n#include <limits>\n#include <vector>')
edit("src/terrain_3d_data.cpp",
    "void Terrain3DData::set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel) {",
    r"""// All samples are on the integer global vertex grid; no world-float roundtrip.
double Terrain3DData::tf_sample(const Vector2i &p) const {
	const Vector2i loc = V2I_DIVIDE_FLOOR(p, _region_size);
	const Terrain3DRegion *reg = get_region_ptr(loc);
	if (!reg || reg->is_deleted()) return std::numeric_limits<double>::quiet_NaN();
	Image *h = reg->get_map_ptr(TYPE_HEIGHT);
	Image *c = reg->get_map_ptr(TYPE_CONTROL);
	if (!h || !c || h->get_format()!=Image::FORMAT_RF || c->get_format()!=Image::FORMAT_RF ||
			h->get_size()!=_region_sizev || c->get_size()!=_region_sizev) {
		return std::numeric_limits<double>::quiet_NaN();
	}
	const Vector2i pix = vgrid_to_pixelv(p);
	const float control = c->get_pixelv(pix).r;
	// Keep native control bit interpretation; reject non-finite invalid control.
	if (std::isnan(control) || is_hole(control)) return std::numeric_limits<double>::quiet_NaN();
	return double(h->get_pixelv(pix).r);
}

Dictionary Terrain3DData::tf_plan_brush(const Vector2 &center, int tool, double radius, double power, double flatten) const {
	Dictionary out;
	out["error"] = "Unsupported native brush.";
	if (!_terrain || _region_size<=0 || _vertex_spacing<=0 || tool<0 || tool>3 ||
			!std::isfinite(center.x) || !std::isfinite(center.y) ||
			std::abs(center.x)>10000000.0 || std::abs(center.y)>10000000.0 ||
			!std::isfinite(radius) || radius<=0 || radius>36.0 ||
			!std::isfinite(power) || power<=0 || power>12.0 ||
			(tool==3 && !std::isfinite(flatten))) return out;
	const double gx=center.x/_vertex_spacing, gy=center.y/_vertex_spacing, r=radius/_vertex_spacing;
	const int x0=int(std::floor(gx-r)), y0=int(std::floor(gy-r));
	const int x1=int(std::ceil(gx+r)), y1=int(std::ceil(gy+r));
	const int width=x1-x0+1, height=y1-y0+1;
	if (int64_t(width)*height>85000) {
		out["error"]="Brush footprint exceeds grid budget; reduce radius for this spacing.";
		return out;
	}
	// Radius-aware normalized box filter. Summed-area tables make each
	// neighborhood lookup constant time, even for a large physical radius.
	// Invalid/missing/hole samples contribute neither a value nor a count.
	const int k=tool==2 ? std::max(1,int(std::round(r*0.35))) : 0;
	const int sw=width+2*k, sh=height+2*k, stride=sw+1;
	const int n=(sw+1)*(sh+1);
	std::vector<double> source, sums;
	std::vector<int> counts;
	if (tool==2) {
		if (n>180000) { out["error"]="Brush footprint exceeds grid budget; reduce radius for this spacing."; return out; }
		source.resize(sw*sh);
		sums.assign(n,0.0);
		counts.assign(n,0);
		for (int y=0;y<sh;++y) {
			double row_sum=0.0;
			int row_count=0;
			for (int x=0;x<sw;++x) {
				const double z=tf_sample(Vector2i(x0-k+x,y0-k+y));
				source[y*sw+x]=z;
				if (std::isfinite(z)) { row_sum+=z; ++row_count; }
				const int i=(y+1)*stride+x+1;
				sums[i]=sums[i-stride]+row_sum;
				counts[i]=counts[i-stride]+row_count;
			}
		}
	}
	Dictionary changes, originals;
	for (int y=y0;y<=y1;++y) {
		for (int x=x0;x<=x1;++x) {
			const double dx=(x-gx)/r, dy=(y-gy)/r;
			const double dist_sq=dx*dx+dy*dy;
			if (dist_sq>=1.0) continue;
			const Vector2i p(x,y);
			const double old=tool==2 ? source[(y-y0+k)*sw+(x-x0+k)] : tf_sample(p);
			if (!std::isfinite(old)) continue;
			const double t=std::sqrt(dist_sq);
			const double weight=1.0-t*t*(3.0-2.0*t);
			double value=old;
			if (tool==0) value+=power*weight;
			else if (tool==1) value-=power*weight;
			else if (tool==3) value+=(flatten-old)*std::min(1.0,power/12.0*weight);
			else {
				const int ax=x-x0, ay=y-y0, bx=ax+2*k+1, by=ay+2*k+1;
				const int a=ay*stride+ax, b=ay*stride+bx, c=by*stride+ax, d=by*stride+bx;
				const int count=counts[d]-counts[b]-counts[c]+counts[a];
				if (count>0) {
					const double average=(sums[d]-sums[b]-sums[c]+sums[a])/count;
					value+=(average-old)*std::min(1.0,power/6.0*weight);
				}
			}
			if (!std::isfinite(value) || std::abs(value)>1000000.0) {
				out["error"]="Height out of bounds; dab rejected.";
				return out;
			}
			const float actual=float(value);
			if (actual!=float(old)) { changes[p]=actual; originals[p]=float(old); }
		}
	}
	out["error"]="";
	out["changes"]=changes;
	out["originals"]=originals;
	out["filter_half_width_m"]=k*_vertex_spacing;
	return out;
}

Dictionary Terrain3DData::tf_write_brush(const Dictionary &values) {
	Dictionary out;
	out["error"]="Native batch rejected; no changes made.";
	out["actual"]=Dictionary();
	if (!_terrain || _region_size<=0 || values.size()>131072) return out;
	struct Sample { Vector2i key; Image *image; Vector2i pixel; float old_height; float height; int region_index; };
	std::vector<Sample> writes;
	writes.reserve(values.size());
	std::array<Terrain3DRegion*,1024> touched{};
	std::array<Vector2,1024> bounds{};
	const Array keys=values.keys();
	// Validate everything before the first write, including holes and finite RF.
	for (int i=0;i<keys.size();++i) {
		if (keys[i].get_type()!=Variant::VECTOR2I) return out;
		const Vector2i p=keys[i];
		const Variant v=values[p];
		if (v.get_type()!=Variant::FLOAT && v.get_type()!=Variant::INT) return out;
		const double value=double(v);
		const double old=tf_sample(p);
		if (!std::isfinite(old) || !std::isfinite(value) || std::abs(value)>1000000.0) return out;
		const float actual=float(value);
		if (actual==float(old)) continue;
		const Vector2i loc=V2I_DIVIDE_FLOOR(p,_region_size);
		const int index=get_region_map_index(loc);
		Terrain3DRegion *reg=get_region_ptr(loc);
		if (index<0 || index>=1024 || !reg) return out;
		if (!touched[index]) {
			touched[index]=reg;
			bounds[index]=reg->get_height_range();
		}
		bounds[index].x=std::min(bounds[index].x,real_t(actual));
		bounds[index].y=std::max(bounds[index].y,real_t(actual));
		writes.push_back({p,reg->get_map_ptr(TYPE_HEIGHT),vgrid_to_pixelv(p),float(old),actual,index});
	}
	Dictionary actual;
	for (const Sample &v:writes) {
		v.image->set_pixelv(v.pixel,Color(v.height,0.f,0.f,1.f));
		const float read=v.image->get_pixelv(v.pixel).r;
		if (read!=v.height) {
			// RF write mismatch: roll back the whole staged batch before upload.
			for (const Sample &undo:writes) undo.image->set_pixelv(undo.pixel,Color(undo.old_height,0.f,0.f,1.f));
			out["error"]="Native batch readback mismatch; rolled back.";
			return out;
		}
		actual[v.key]=read;
	}
	int dirty=0;
	for (int i=0;i<1024;++i) if (touched[i]) {
		touched[i]->set_height_range(bounds[i]);
		touched[i]->set_modified(true);
		touched[i]->set_edited(true);
		++dirty;
	}
	if (dirty>0) {
		calc_height_range(false);
		update_maps(TYPE_HEIGHT,false,false);
		for (Terrain3DRegion *reg:touched) if (reg) reg->set_edited(false);
		_terrain->snap();
	}
	out["error"]="";
	out["actual"]=actual;
	out["dirty_regions"]=dirty;
	return out;
}

void Terrain3DData::set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel) {""")
edit("src/terrain_3d_data.cpp",
    'ClassDB::bind_method(D_METHOD("get_region_count"), &Terrain3DData::get_region_count);',
    '''ClassDB::bind_method(D_METHOD("get_region_count"), &Terrain3DData::get_region_count);
	ClassDB::bind_method(D_METHOD("tf_plan_brush","center","tool","radius","power","flatten"), &Terrain3DData::tf_plan_brush);
	ClassDB::bind_method(D_METHOD("tf_write_brush","values"), &Terrain3DData::tf_write_brush);''')
print("TF_NATIVE_BRUSH_BATCH_PATCH_APPLIED")
