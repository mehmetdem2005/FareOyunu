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
	Vector3 tf_pick_brush(const Vector3 &origin, const Vector3 &direction) const;
	Dictionary tf_plan_brush(const Vector2 &center, int tool, double radius, double power, double flatten, int smooth_mode = 0) const;
	Dictionary tf_capture_smooth(const Vector2 &center, double radius, double power, int smooth_mode, bool bulk = true) const;
	void tf_read_rf_rect(const Vector2i &origin, int width, int height, float *dst, bool bulk) const;
	static Dictionary tf_plan_smooth_snapshot(const Dictionary &snapshot);
	bool tf_verify_smooth_snapshot(const Dictionary &snapshot, bool bulk = true) const;
	Dictionary tf_write_brush(const Dictionary &values, bool cached = true, bool keep_mesh_target = true);
	void set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel);""")
edit("src/terrain_3d_data.cpp",
    '#include "terrain_3d_data.h"',
    '#include "terrain_3d_data.h"\n#include <algorithm>\n#include <array>\n#include <cmath>\n#include <chrono>\n#include <cstring>\n#include <limits>\n#include <vector>\n#include <godot_cpp/variant/packed_float32_array.hpp>')
edit("src/terrain_3d_data.cpp",
    "void Terrain3DData::set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel) {",
    r"""// All samples are on the integer global vertex grid; no world-float roundtrip.
// Conservative horizontal broad phase; preserve original step positions.
Vector3 Terrain3DData::tf_pick_brush(const Vector3 &origin,const Vector3 &ray) const {
	if (!_terrain || ray.is_zero_approx() || !ray.is_finite() || !origin.is_finite()) return V3_NAN;
	const Vector3 direction=ray.normalized();
	if (direction.y<-.99999f) {
		const real_t h=get_surface_height(origin);
		if (std::isfinite(h)) return Vector3(origin.x,h,origin.z);
	}
	const real_t initial=get_surface_height(origin);
	if (initial>origin.y) return V3_MAX;
	double min_x=std::numeric_limits<double>::infinity(), min_z=min_x;
	double max_x=-min_x, max_z=-min_x;
	bool bounded=std::isfinite(_vertex_spacing) && _vertex_spacing>=0.25 && _vertex_spacing<=100.0 && _region_size>0;
	bool any=false;
	// Iterate live region dictionary, not a potentially stale active map.
	if (bounded) for (const Vector2i &loc : _regions.keys()) {
		const Terrain3DRegion *reg=get_region_ptr(loc);
		if (!reg || reg->is_deleted()) continue;
		any=true;
		const double extent=double(_region_size)*_vertex_spacing;
		const double x=double(loc.x)*extent, z=double(loc.y)*extent;
		// Conservative float precision bound; unusual coordinates fall back.
		if (std::abs(x)>100000.0 || std::abs(z)>100000.0 || extent>100000.0) { bounded=false; break; }
		const double pad=2.0*_vertex_spacing+0.02;
		min_x=std::min(min_x,x-pad); min_z=std::min(min_z,z-pad);
		max_x=std::max(max_x,x+extent+pad); max_z=std::max(max_z,z+extent+pad);
	}
	if (bounded && !any) return V3_MAX;
	Vector3 point=origin;
	for (int i=0;i<4000;++i) {
		if (bounded) {
			const bool left=point.x<min_x, right=point.x>max_x;
			const bool near=point.z<min_z, far=point.z>max_z;
			if ((left && direction.x<=0) || (right && direction.x>=0) ||
				(near && direction.z<=0) || (far && direction.z>=0)) return V3_MAX;
			if (left || right || near || far) { point+=direction; continue; }
		}
		const real_t h=get_surface_height(point);
		if (point.y-h<=0.f) return point;
		point+=direction;
	}
	return V3_MAX;
}

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

Dictionary Terrain3DData::tf_plan_brush(const Vector2 &center, int tool, double radius, double power, double flatten, int smooth_mode) const {
	Dictionary out;
	out["error"] = "Unsupported native brush.";
	if (!_terrain || _region_size<=0 || _vertex_spacing<=0 || tool<0 || tool>3 || smooth_mode<0 || smooth_mode>2 ||
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
	// mode 0 legacy, 1 macro with retained residual, 2 fine.
	const int broad_k=tool==2 ? std::max(1,int(std::round(r*0.35))) : 0;
	const int fine_k=tool==2 ? std::max(1,int(std::round(std::min(1.0,radius)/_vertex_spacing))) : 0;
	const int pass_k=tool==2 ? std::max(1,int(std::round(broad_k/std::sqrt(2.0)))) : 0;
	const int k=tool!=2 ? 0 : smooth_mode==0 ? broad_k : smooth_mode==1 ? fine_k+2*pass_k : fine_k;
	const int sw=width+2*k, sh=height+2*k, stride=sw+1;
	const int64_t n=int64_t(sw+1)*(sh+1);
	std::vector<double> source, fine, target, sums;
	std::vector<int> counts;
	if (tool==2) {
		if (n>(smooth_mode==0 ? 180000 : 300000)) { out["error"]="Brush footprint exceeds grid budget; reduce radius for this spacing."; return out; }
		source.resize(sw*sh);
		for (int y=0;y<sh;++y) for (int x=0;x<sw;++x)
			source[y*sw+x]=tf_sample(Vector2i(x0-k+x,y0-k+y));
		// Same masked, normalized box passes as the Q4 numerical reference.
		// All buffers are local to this transaction; no live RF access during filtering.
		auto box = [&](const std::vector<double> &input, int half, std::vector<double> &output) {
			sums.assign(n,0.0);
			counts.assign(n,0);
			for (int y=0;y<sh;++y) {
				double row_sum=0.0;
				int row_count=0;
				for (int x=0;x<sw;++x) {
					const double z=input[y*sw+x];
					if (std::isfinite(z)) { row_sum+=z; ++row_count; }
					const int i=(y+1)*stride+x+1;
					sums[i]=sums[i-stride]+row_sum;
					counts[i]=counts[i-stride]+row_count;
				}
			}
			output.assign(sw*sh,std::numeric_limits<double>::quiet_NaN());
			for (int y=0;y<sh;++y) for (int x=0;x<sw;++x) {
				const int i=y*sw+x;
				if (!std::isfinite(input[i])) continue;
				const int ax=std::max(0,x-half), ay=std::max(0,y-half);
				const int bx=std::min(sw,x+half+1), by=std::min(sh,y+half+1);
				const int a=ay*stride+ax,b=ay*stride+bx,c=by*stride+ax,d=by*stride+bx;
				const int count=counts[d]-counts[b]-counts[c]+counts[a];
				if (count>0) output[i]=(sums[d]-sums[b]-sums[c]+sums[a])/count;
			}
		};
		if (smooth_mode==0) {
			// Preserve legacy SAT-only path (no full target grid allocation).
			sums.assign(n,0.0); counts.assign(n,0);
			for (int y=0;y<sh;++y) {
				double row_sum=0.0; int row_count=0;
				for (int x=0;x<sw;++x) {
					const double z=source[y*sw+x];
					if (std::isfinite(z)) { row_sum+=z; ++row_count; }
					const int i=(y+1)*stride+x+1;
					sums[i]=sums[i-stride]+row_sum; counts[i]=counts[i-stride]+row_count;
				}
			}
		} else {
			box(source,fine_k,fine);
			if (smooth_mode==1) {
				std::vector<double> intermediate;
				box(fine,pass_k,intermediate);
				box(intermediate,pass_k,target);
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
			else if (smooth_mode!=0) {
				const int i=(y-y0+k)*sw+(x-x0+k);
				const double desired=smooth_mode==1 ? target[i]+0.9*(old-fine[i]) : fine[i];
				if (std::isfinite(desired))
					value+=(desired-old)*std::min(1.0,power/6.0*weight);
			}
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
	out["smooth_mode"]=smooth_mode;
	out["filter_grid_cells"]=n;
	return out;
}

// Q6c1: value-only snapshot. Capture/verify on main thread; static planner
// may execute off-thread. No live object or rendering resource in snapshot.
namespace {
struct TFSmoothGrid {
	int x0,y0,w,h,k,sw,sh;
};
bool tf_smooth_grid(const Vector2 &center,double radius,double power,int mode,double spacing,TFSmoothGrid &g) {
	if (!std::isfinite(spacing) || spacing<0.25 || spacing>100.0 ||
		!std::isfinite(center.x) || !std::isfinite(center.y) ||
		std::abs(center.x)>10000000.0 || std::abs(center.y)>10000000.0 ||
		!std::isfinite(radius) || radius<=0 || radius>36 ||
		!std::isfinite(power) || power<=0 || power>12 || mode<0 || mode>2) return false;
	const double gx=center.x/spacing, gy=center.y/spacing, r=radius/spacing;
	g.x0=int(std::floor(gx-r)); g.y0=int(std::floor(gy-r));
	g.w=int(std::ceil(gx+r))-g.x0+1; g.h=int(std::ceil(gy+r))-g.y0+1;
	const int broad=std::max(1,int(std::round(r*0.35)));
	const int fine=std::max(1,int(std::round(std::min(1.0,radius)/spacing)));
	const int pass=std::max(1,int(std::round(broad/std::sqrt(2.0))));
	g.k=mode==0 ? broad : mode==1 ? fine+2*pass : fine;
	g.sw=g.w+2*g.k; g.sh=g.h+2*g.k;
	return int64_t(g.w)*g.h<=85000 && int64_t(g.sw+1)*(g.sh+1)<=(mode==0?180000:300000);
}
}

// Resolve each overlapping region once; copy raw RF bytes only for that
// region, with no pointer lifetime crossing the function or thread boundary.
// Keep scalar path as reference and fallback for unexpected image layout.
void Terrain3DData::tf_read_rf_rect(const Vector2i &origin,int width,int height,float *dst,bool bulk) const {
	const float invalid=std::numeric_limits<float>::quiet_NaN();
	if (!bulk) {
		for (int y=0;y<height;++y) for (int x=0;x<width;++x)
			dst[y*width+x]=float(tf_sample(origin+Vector2i(x,y)));
		return;
	}
	std::fill(dst,dst+int64_t(width)*height,invalid);
	const Vector2i end=origin+Vector2i(width-1,height-1);
	const Vector2i lo=V2I_DIVIDE_FLOOR(origin,_region_size);
	const Vector2i hi=V2I_DIVIDE_FLOOR(end,_region_size);
	for (int ry=lo.y;ry<=hi.y;++ry) for (int rx=lo.x;rx<=hi.x;++rx) {
		const Vector2i loc(rx,ry);
		const Terrain3DRegion *reg=get_region_ptr(loc);
		if (!reg || reg->is_deleted()) continue;
		Image *h=reg->get_map_ptr(TYPE_HEIGHT);
		Image *c=reg->get_map_ptr(TYPE_CONTROL);
		if (!h || !c || h->get_format()!=Image::FORMAT_RF || c->get_format()!=Image::FORMAT_RF ||
				h->get_size()!=_region_sizev || c->get_size()!=_region_sizev) continue;
		const Vector2i base=loc*_region_size;
		const int x0=std::max(origin.x,base.x), x1=std::min(end.x,base.x+_region_size-1);
		const int y0=std::max(origin.y,base.y), y1=std::min(end.y,base.y+_region_size-1);
		const int64_t bytes=int64_t(_region_size)*_region_size*4;
		const PackedByteArray hb=h->get_data(), cb=c->get_data();
		if (sizeof(float)!=4 || hb.size()!=bytes || cb.size()!=bytes || h->has_mipmaps() || c->has_mipmaps()) {
			for (int y=y0;y<=y1;++y) for (int x=x0;x<=x1;++x)
				dst[(y-origin.y)*width+x-origin.x]=float(tf_sample(Vector2i(x,y)));
			continue;
		}
		const uint8_t *hp=hb.ptr(), *cp=cb.ptr();
		for (int y=y0;y<=y1;++y) {
			int64_t offset=(int64_t(y-base.y)*_region_size+x0-base.x)*4;
			float *row=dst+(y-origin.y)*width+x0-origin.x;
			// memcpy avoids alignment/aliasing UB. Preserve existing control
			// NaN and hole semantics; RF bytes are native float storage.
			for (int x=x0;x<=x1;++x,offset+=4,++row) {
				float control;
				std::memcpy(&control,cp+offset,4);
				if (!std::isnan(control) && !is_hole(control))
					std::memcpy(row,hp+offset,4);
			}
		}
	}
}

Dictionary Terrain3DData::tf_capture_smooth(const Vector2 &center,double radius,double power,int smooth_mode,bool bulk) const {
	Dictionary out;
	out["error"]="Invalid or oversized Smooth snapshot.";
	TFSmoothGrid g{};
	if (!_terrain || _region_size<=0 || !tf_smooth_grid(center,radius,power,smooth_mode,_vertex_spacing,g)) return out;
	PackedFloat32Array samples;
	samples.resize(g.sw*g.sh);
	tf_read_rf_rect(Vector2i(g.x0-g.k,g.y0-g.k),g.sw,g.sh,samples.ptrw(),bulk);
	out["center"]=center;
	out["radius"]=radius;
	out["power"]=power;
	out["mode"]=smooth_mode;
	out["spacing"]=double(_vertex_spacing);
	out["region_size"]=_region_size;
	out["data_id"]=int64_t(get_instance_id());
	out["samples"]=samples;
	out["error"]="";
	return out;
}

bool Terrain3DData::tf_verify_smooth_snapshot(const Dictionary &snapshot,bool bulk) const {
	if (!_terrain || !snapshot.has("samples") || !snapshot.has("center") || !snapshot.has("radius") || !snapshot.has("power") || !snapshot.has("mode") || !snapshot.has("spacing") || !snapshot.has("region_size") || !snapshot.has("data_id")) return false;
	if (int64_t(snapshot["data_id"])!=int64_t(get_instance_id()) || int(snapshot["region_size"])!=_region_size || double(snapshot["spacing"])!=double(_vertex_spacing)) return false;
	const Vector2 center=snapshot["center"];
	TFSmoothGrid g{};
	if (!tf_smooth_grid(center,double(snapshot["radius"]),double(snapshot["power"]),int(snapshot["mode"]),_vertex_spacing,g)) return false;
	const PackedFloat32Array samples=snapshot["samples"];
	if (samples.size()!=g.sw*g.sh) return false;
	const float *src=samples.ptr();
	std::vector<float> live(g.sw*g.sh);
	tf_read_rf_rect(Vector2i(g.x0-g.k,g.y0-g.k),g.sw,g.sh,live.data(),bulk);
	for (int i=0;i<g.sw*g.sh;++i) {
		const float a=src[i], b=live[i];
		if (std::isfinite(a)!=std::isfinite(b) || (std::isfinite(a) && a!=b)) return false;
	}
	return true;
}

Dictionary Terrain3DData::tf_plan_smooth_snapshot(const Dictionary &snapshot) {
	Dictionary out;
	out["error"]="Invalid Smooth snapshot.";
	if (!snapshot.has("samples") || !snapshot.has("center") || !snapshot.has("radius") || !snapshot.has("power") || !snapshot.has("mode") || !snapshot.has("spacing")) return out;
	const Vector2 center=snapshot["center"];
	const double radius=snapshot["radius"],power=snapshot["power"],spacing=snapshot["spacing"];
	const int smooth_mode=snapshot["mode"];
	const PackedFloat32Array samples=snapshot["samples"];
	TFSmoothGrid g{};
	if (!tf_smooth_grid(center,radius,power,smooth_mode,spacing,g)) return out;
	const double gx=center.x/spacing, gy=center.y/spacing, r=radius/spacing;
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
	// mode 0 legacy, 1 macro with retained residual, 2 fine.
	const int broad_k=std::max(1,int(std::round(r*0.35)));
	const int fine_k=std::max(1,int(std::round(std::min(1.0,radius)/spacing)));
	const int pass_k=std::max(1,int(std::round(broad_k/std::sqrt(2.0))));
	const int k=smooth_mode==0 ? broad_k : smooth_mode==1 ? fine_k+2*pass_k : fine_k;
	const int sw=width+2*k, sh=height+2*k, stride=sw+1;
	const int64_t n=int64_t(sw+1)*(sh+1);
	std::vector<double> source, fine, target, sums;
	std::vector<int> counts;
	{
		if (n>(smooth_mode==0 ? 180000 : 300000)) { out["error"]="Brush footprint exceeds grid budget; reduce radius for this spacing."; return out; }
		if (samples.size()!=sw*sh) return out;
		source.resize(sw*sh);
		for (int i=0;i<sw*sh;++i) source[i]=samples[i];
		// Same masked, normalized box passes as the Q4 numerical reference.
		// All buffers are local to this transaction; no live RF access during filtering.
		auto box = [&](const std::vector<double> &input, int half, std::vector<double> &output) {
			sums.assign(n,0.0);
			counts.assign(n,0);
			for (int y=0;y<sh;++y) {
				double row_sum=0.0;
				int row_count=0;
				for (int x=0;x<sw;++x) {
					const double z=input[y*sw+x];
					if (std::isfinite(z)) { row_sum+=z; ++row_count; }
					const int i=(y+1)*stride+x+1;
					sums[i]=sums[i-stride]+row_sum;
					counts[i]=counts[i-stride]+row_count;
				}
			}
			output.assign(sw*sh,std::numeric_limits<double>::quiet_NaN());
			for (int y=0;y<sh;++y) for (int x=0;x<sw;++x) {
				const int i=y*sw+x;
				if (!std::isfinite(input[i])) continue;
				const int ax=std::max(0,x-half), ay=std::max(0,y-half);
				const int bx=std::min(sw,x+half+1), by=std::min(sh,y+half+1);
				const int a=ay*stride+ax,b=ay*stride+bx,c=by*stride+ax,d=by*stride+bx;
				const int count=counts[d]-counts[b]-counts[c]+counts[a];
				if (count>0) output[i]=(sums[d]-sums[b]-sums[c]+sums[a])/count;
			}
		};
		if (smooth_mode==0) {
			// Preserve legacy SAT-only path (no full target grid allocation).
			sums.assign(n,0.0); counts.assign(n,0);
			for (int y=0;y<sh;++y) {
				double row_sum=0.0; int row_count=0;
				for (int x=0;x<sw;++x) {
					const double z=source[y*sw+x];
					if (std::isfinite(z)) { row_sum+=z; ++row_count; }
					const int i=(y+1)*stride+x+1;
					sums[i]=sums[i-stride]+row_sum; counts[i]=counts[i-stride]+row_count;
				}
			}
		} else {
			box(source,fine_k,fine);
			if (smooth_mode==1) {
				std::vector<double> intermediate;
				box(fine,pass_k,intermediate);
				box(intermediate,pass_k,target);
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
			const double old=source[(y-y0+k)*sw+(x-x0+k)];
			if (!std::isfinite(old)) continue;
			const double t=std::sqrt(dist_sq);
			const double weight=1.0-t*t*(3.0-2.0*t);
			double value=old;
			if (smooth_mode!=0) {
				const int i=(y-y0+k)*sw+(x-x0+k);
				const double desired=smooth_mode==1 ? target[i]+0.9*(old-fine[i]) : fine[i];
				if (std::isfinite(desired))
					value+=(desired-old)*std::min(1.0,power/6.0*weight);
			}
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
	out["filter_half_width_m"]=k*spacing;
	out["smooth_mode"]=smooth_mode;
	out["filter_grid_cells"]=n;
	return out;
}

Dictionary Terrain3DData::tf_write_brush(const Dictionary &values, bool cached, bool keep_mesh_target) {
	using TFClock = std::chrono::steady_clock;
	const auto started = TFClock::now();
	auto elapsed_us = [](TFClock::time_point a, TFClock::time_point b) -> int64_t {
		return std::chrono::duration_cast<std::chrono::microseconds>(b-a).count();
	};
	Dictionary out;
	out["error"]="Native batch rejected; no changes made.";
	out["actual"]=Dictionary();
	if (!_terrain || _region_size<=0 || values.size()>131072) return out;
	struct Sample { Vector2i key; Image *image; Vector2i pixel; float old_height; float height; int region_index; };
	std::vector<Sample> writes;
	writes.reserve(values.size());
	std::array<Terrain3DRegion*,1024> touched{};
	std::array<Vector2,1024> bounds{};
	// Transaction-local non-owning pointers: no mutation or thread transfer
	// during validation. Same RF pixel read/write and exact rollback as before.
	struct RegionRead { Terrain3DRegion *reg=nullptr; Image *height=nullptr; Image *control=nullptr; };
	std::array<RegionRead,1024> read_cache{};
	int resolved_regions=0;
	const Array keys=values.keys();
	// Validate everything before the first write, including holes and finite RF.
	for (int i=0;i<keys.size();++i) {
		if (keys[i].get_type()!=Variant::VECTOR2I) return out;
		const Vector2i p=keys[i];
		const Variant v=values[p];
		if (v.get_type()!=Variant::FLOAT && v.get_type()!=Variant::INT) return out;
		const double value=double(v);
		if (!std::isfinite(value) || std::abs(value)>1000000.0) return out;
		const Vector2i loc=V2I_DIVIDE_FLOOR(p,_region_size);
		const int index=get_region_map_index(loc);
		Terrain3DRegion *reg=nullptr;
		Image *height_map=nullptr;
		Vector2i pixel;
		double old;
		if (cached) {
			if (index<0 || index>=1024) return out;
			RegionRead &entry=read_cache[index];
			if (!entry.reg) {
				entry.reg=get_region_ptr(loc);
				if (!entry.reg || entry.reg->is_deleted()) return out;
				entry.height=entry.reg->get_map_ptr(TYPE_HEIGHT);
				entry.control=entry.reg->get_map_ptr(TYPE_CONTROL);
				if (!entry.height || !entry.control || entry.height->get_format()!=Image::FORMAT_RF ||
					entry.control->get_format()!=Image::FORMAT_RF || entry.height->get_size()!=_region_sizev ||
					entry.control->get_size()!=_region_sizev) return out;
				++resolved_regions;
			}
			reg=entry.reg;
			height_map=entry.height;
			pixel=p-loc*_region_size;
			const float control=entry.control->get_pixelv(pixel).r;
			if (std::isnan(control) || is_hole(control)) return out;
			old=double(height_map->get_pixelv(pixel).r);
		} else {
			old=tf_sample(p);
		}
		if (!std::isfinite(old)) return out;
		const float actual=float(value);
		if (actual==float(old)) continue;
		if (!cached) {
			reg=get_region_ptr(loc);
			if (index<0 || index>=1024 || !reg) return out;
			height_map=reg->get_map_ptr(TYPE_HEIGHT);
			pixel=vgrid_to_pixelv(p);
		}
		if (!touched[index]) {
			touched[index]=reg;
			bounds[index]=reg->get_height_range();
		}
		bounds[index].x=std::min(bounds[index].x,real_t(actual));
		bounds[index].y=std::max(bounds[index].y,real_t(actual));
		writes.push_back({p,height_map,pixel,float(old),actual,index});
	}
	const auto validated = TFClock::now();
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
	const auto written = TFClock::now();
	int dirty=0;
	for (int i=0;i<1024;++i) if (touched[i]) {
		touched[i]->set_height_range(bounds[i]);
		touched[i]->set_modified(true);
		touched[i]->set_edited(true);
		++dirty;
	}
	const auto marked = TFClock::now();
	auto ranged = marked;
	auto uploaded = marked;
	auto snapped = marked;
	int64_t layer_bytes_est = 0;
	int64_t edited_regions_est = 0;
	bool incremental_expected = false;
	bool mesh_target_preserved=false;
	if (dirty>0) {
		// These counters describe expected CPU-side full-layer payload, not
		// GPU completion. Dirty arrays may rebuild more than the edited layers.
		incremental_expected = !_region_map_dirty && !_generated_height_maps.is_dirty() &&
			!_generated_control_maps.is_dirty() && !_generated_color_maps.is_dirty();
		for (const Vector2i &loc : _region_locations) {
			const Terrain3DRegion *reg = get_region_ptr(loc);
			if (reg && reg->is_edited()) ++edited_regions_est;
		}
		if (incremental_expected)
			layer_bytes_est = edited_regions_est * int64_t(_region_size) * _region_size * 4;
		calc_height_range(false);
		ranged = TFClock::now();
		update_maps(TYPE_HEIGHT,false,false);
		uploaded = TFClock::now();
		for (Terrain3DRegion *reg:touched) if (reg) reg->set_edited(false);
		if (keep_mesh_target && incremental_expected)
			mesh_target_preserved=_terrain->tf_snap_height_edit();
		else
			_terrain->snap();
		snapped = TFClock::now();
	}
	out["profile"] = Dictionary();
	Dictionary profile;
	profile["validate_us"] = elapsed_us(started,validated);
	profile["pixel_write_us"] = elapsed_us(validated,written);
	profile["mark_us"] = elapsed_us(written,marked);
	profile["range_us"] = elapsed_us(marked,ranged);
	profile["publish_cpu_us"] = elapsed_us(ranged,uploaded);
	profile["snap_us"] = elapsed_us(uploaded,snapped);
	profile["changed_samples"] = int64_t(writes.size());
	profile["cached_validation"] = cached;
	profile["resolved_regions"] = resolved_regions;
	profile["dirty_regions"] = dirty;
	profile["edited_regions_est"] = edited_regions_est;
	profile["incremental_expected"] = incremental_expected;
	profile["layer_bytes_est"] = layer_bytes_est;
	profile["mesh_target_preserved"] = mesh_target_preserved;
	out["profile"] = profile;
	out["error"]="";
	out["actual"]=actual;
	out["dirty_regions"]=dirty;
	return out;
}

void Terrain3DData::set_pixel(const MapType p_map_type, const Vector3 &p_global_position, const Color &p_pixel) {""")
edit("src/terrain_3d_data.cpp",
    'ClassDB::bind_method(D_METHOD("get_region_count"), &Terrain3DData::get_region_count);',
    '''ClassDB::bind_method(D_METHOD("get_region_count"), &Terrain3DData::get_region_count);
	ClassDB::bind_method(D_METHOD("tf_pick_brush","origin","direction"), &Terrain3DData::tf_pick_brush);
	ClassDB::bind_method(D_METHOD("tf_plan_brush","center","tool","radius","power","flatten","smooth_mode"), &Terrain3DData::tf_plan_brush, DEFVAL(0));
	ClassDB::bind_method(D_METHOD("tf_write_brush","values","cached","keep_mesh_target"), &Terrain3DData::tf_write_brush, DEFVAL(true), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("tf_capture_smooth","center","radius","power","smooth_mode","bulk"), &Terrain3DData::tf_capture_smooth, DEFVAL(true));
	ClassDB::bind_static_method("Terrain3DData",D_METHOD("tf_plan_smooth_snapshot","snapshot"), &Terrain3DData::tf_plan_smooth_snapshot);
	ClassDB::bind_method(D_METHOD("tf_verify_smooth_snapshot","snapshot","bulk"), &Terrain3DData::tf_verify_smooth_snapshot, DEFVAL(true));''')
# R3a: keep editor clipmap transforms when only RF heights change.
# Collision invalidation remains identical; tessellation and rebuilds use snap.
edit("src/terrain_3d.h", "void snap();",
    """void snap();
	bool tf_snap_height_edit();
	int64_t tf_mesh_recenter_count(bool probe = false);""")
edit("src/terrain_3d_mesher.h", "Vector2 _last_target_position = V2_MAX;",
    "Vector2 _last_target_position = V2_MAX;\n\tint64_t _tf_recenter_count = 0;")
edit("src/terrain_3d_mesher.h", "void reset_target_position() { _last_target_position = V2_MAX; }",
    """void reset_target_position() { _last_target_position = V2_MAX; }
	int64_t tf_recenter_count() const { return _tf_recenter_count; }""")
edit("src/terrain_3d_mesher.cpp", "// Recenter terrain on the target",
    "++_tf_recenter_count;\n\t// Recenter terrain on the target")
edit("src/terrain_3d.cpp", "void Terrain3D::snap() {", r"""// Height texture and AABB notifications already happened in update_maps.
// Non-tessellated clipmap transforms depend on camera XZ, not sample heights.
// Keep collision invalidation exactly as in snap(); all other modes fall back.
bool Terrain3D::tf_snap_height_edit() {
	if (!IS_EDITOR || !_initialized || !_terrain_mesher || _tessellation_level>0) {
		snap();
		return false;
	}
	if (_collision) _collision->reset_target_position();
	// Ocean is deliberately unchanged by a terrain height-only edit.
	return true;
}

int64_t Terrain3D::tf_mesh_recenter_count(bool probe) {
	if (!_terrain_mesher) return -1;
	if (probe) _terrain_mesher->snap();
	return _terrain_mesher->tf_recenter_count();
}

void Terrain3D::snap() {""")
edit("src/terrain_3d.cpp", 'ClassDB::bind_method(D_METHOD("snap"), &Terrain3D::snap);',
    '''ClassDB::bind_method(D_METHOD("snap"), &Terrain3D::snap);
	ClassDB::bind_method(D_METHOD("tf_mesh_recenter_count","probe"), &Terrain3D::tf_mesh_recenter_count, DEFVAL(false));''')
print("TF_NATIVE_BRUSH_BATCH_PATCH_APPLIED")
