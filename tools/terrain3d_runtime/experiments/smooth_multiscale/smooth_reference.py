"""Numerical reference candidate for Q4. No live Terrain3D integration.
Masked, separable-scale box convolutions via summed-area tables.
Invalid cells stay invalid; finite neighbors contribute normalized weights.
"""
import math


def mean_box(src, w, h, k):
    if len(src) != w*h or w < 1 or h < 1 or k < 1:
        raise ValueError("invalid grid/kernel")
    stride = w+1
    sums = [0.0]*((w+1)*(h+1))
    counts = [0]*len(sums)
    for y in range(h):
        total = 0.0
        count = 0
        for x in range(w):
            v = src[y*w+x]
            if math.isfinite(v):
                total += v
                count += 1
            p = (y+1)*stride+x+1
            sums[p] = sums[p-stride]+total
            counts[p] = counts[p-stride]+count
    out = [math.nan]*(w*h)
    for y in range(h):
        lo_y, hi_y = max(0,y-k), min(h,y+k+1)
        for x in range(w):
            i=y*w+x
            if not math.isfinite(src[i]):
                continue
            lo_x, hi_x = max(0,x-k), min(w,x+k+1)
            a,b,c,d = lo_y*stride+lo_x,lo_y*stride+hi_x,hi_y*stride+lo_x,hi_y*stride+hi_x
            n=counts[d]-counts[b]-counts[c]+counts[a]
            if n:
                out[i]=(sums[d]-sums[b]-sums[c]+sums[a])/n
    return out


def smooth(src,w,h,spacing,cx,cy,radius,power,mode="macro",detail_m=1.0,retention=0.9):
    """World coordinates and meters, with unchanged samples outside footprint.
    macro: smooth the coarse surface while preserving a fraction of fine residual.
    fine: remove small-scale roughness without flattening the entire hill.
    legacy: radius-scaled single box filter (Q1 numerical reference).
    The caller must capture enough halo beyond the brush footprint.
    """
    if w*h>300000 or len(src)!=w*h or min(w,h)<1:
        raise ValueError("grid budget")
    if not all(map(math.isfinite,(spacing,cx,cy,radius,power,detail_m,retention))) or not (0.25<=spacing<=36 and 0<radius<=36 and 0<power<=12 and 0<detail_m<=radius and 0<=retention<=1):
        raise ValueError("parameters")
    if mode not in ("macro","fine","legacy"):
        raise ValueError("mode")
    broad_k=max(1,math.floor(radius*0.35/spacing+0.5))
    fine_k=max(1,math.floor(detail_m/spacing+0.5))
    if mode=="legacy":
        target=mean_box(src,w,h,broad_k)
        fine=None
    else:
        fine=mean_box(src,w,h,fine_k)
        # Match approximate broad filter variance across two passes.
        k=max(1,math.floor(broad_k/math.sqrt(2)+0.5))
        target=mean_box(mean_box(fine,w,h,k),w,h,k) if mode=="macro" else fine
    out=list(src)
    for y in range(h):
        for x in range(w):
            i=y*w+x
            old=src[i]
            if not math.isfinite(old):
                continue
            r=math.hypot(x*spacing-cx,y*spacing-cy)/radius
            if r>=1:
                continue
            weight=1-r*r*(3-2*r)
            desired=target[i]
            if mode=="macro":
                desired+=retention*(old-fine[i])
            out[i]=old+(desired-old)*min(1,power/6*weight)
    return out
