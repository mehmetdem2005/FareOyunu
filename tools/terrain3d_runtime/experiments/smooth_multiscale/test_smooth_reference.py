import math
import unittest
from smooth_reference import smooth

class SmoothTests(unittest.TestCase):
    def test_scales(self):
        n=273; s=0.25; c=(n-1)*s/2; mid=(n//2)*n+n//2
        hill=[13.25*math.exp(-((x*s-c)**2+(y*s-c)**2)/(2*8**2)) for y in range(n) for x in range(n)]
        micro=[v+0.20*math.cos(2*math.pi*(i%n-n//2)/8)*math.cos(2*math.pi*(i//n-n//2)/8) for i,v in enumerate(hill)]
        def run(src,mode):
            return smooth(src,n,n,s,c,c,24,6,mode)
        old=run(hill,"legacy"); old_micro=run(micro,"legacy")
        new=run(hill,"macro"); new_micro=run(micro,"macro")
        fine=run(hill,"fine"); fine_micro=run(micro,"fine")
        old_ret=abs(old_micro[mid]-old[mid])/0.2
        new_ret=abs(new_micro[mid]-new[mid])/0.2
        fine_ret=abs(fine_micro[mid]-fine[mid])/0.2
        self.assertGreater(hill[mid]-new[mid],1.0)
        self.assertGreater(new_ret,0.8)
        self.assertLess(old_ret,0.15)
        self.assertLess(fine_ret,0.15)
        self.assertLess(abs(fine[mid]-hill[mid]),0.25)
        self.assertEqual(new[0],hill[0])
        self.assertAlmostEqual(new[mid+12],new[mid+12*n],places=8)
        print("TF_SMOOTH_SCALES_OK peak_before=%.6f legacy_peak=%.6f macro_peak=%.6f fine_peak=%.6f legacy_detail=%.6f macro_detail=%.6f fine_detail=%.6f"%(hill[mid],old[mid],new[mid],fine[mid],old_ret,new_ret,fine_ret))

    def test_holes_constant_and_edges(self):
        n=49;s=0.25;c=6.0
        a=[4.0]*(n*n)
        for y in range(15,34):
            a[y*n+24]=math.nan
        for mode in ("legacy","macro","fine"):
            b=smooth(a,n,n,s,c,c,5,6,mode)
            for x,y in zip(a,b):
                if math.isnan(x):
                    self.assertTrue(math.isnan(y))
                else:
                    self.assertAlmostEqual(x,y,places=10)
        print("TF_SMOOTH_MASK_OK constant=true holes=true")

    def test_invalid(self):
        for kwargs in ({"radius":37},{"power":math.nan},{"retention":1.1},{"mode":"bad"}):
            p=dict(spacing=.25,cx=.5,cy=.5,radius=1,power=3)
            p.update(kwargs)
            with self.assertRaises(ValueError):
                smooth([0.0]*25,5,5,**p)

if __name__=="__main__":
    unittest.main()
