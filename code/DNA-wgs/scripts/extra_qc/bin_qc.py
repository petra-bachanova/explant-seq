#!/usr/bin/env python3
"""Usage: bin_qc.py regions.bed.gz SAMPLE OUTPREFIX"""
import sys
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

regions, sample, prefix = sys.argv[1:4]
AUTO = [str(i) for i in range(1, 23)]

df = pd.read_csv(regions, sep="\t", header=None,
                 names=["chrom", "start", "end", "depth"], dtype={"chrom": str})
df = df[df.chrom.isin(AUTO + ["X", "Y"])].copy()
med = df[df.chrom.isin(AUTO)].depth.median()
df["ratio"] = df.depth / med

# Autosomal bins, dropping gaps (near-zero) and extreme outliers
a = df[df.chrom.isin(AUTO) & (df.ratio > 0.1) & (df.ratio < 3)]
cv = a.ratio.std() / a.ratio.mean()
l2 = np.log2(a.ratio.values)
same = a.chrom.values[1:] == a.chrom.values[:-1]
mapd = np.median(np.abs(np.diff(l2)[same]))        # noise between neighbouring bins
w = int((df.end - df.start).mode()[0])
floor = 1 / np.sqrt(med * w / 151)                  # unavoidable counting noise

pd.DataFrame([dict(sample=sample, bin_kb=w // 1000, median_depth=round(med, 2),
                   cv=round(cv, 4), mapd=round(mapd, 4), poisson_cv_floor=round(floor, 4),
                   x_ratio=round(df[df.chrom == "X"].ratio.mean(), 3),
                   y_ratio=round(df[df.chrom == "Y"].ratio.mean(), 3))]
             ).to_csv(prefix + ".bin_qc.tsv", sep="\t", index=False)

fig, ax = plt.subplots(figsize=(16, 3.5))
off = 0
for i, c in enumerate(AUTO + ["X", "Y"]):
    s = df[df.chrom == c]
    ax.scatter(off + s.start, s.ratio, s=1, color="C0" if i % 2 == 0 else "C1")
    off += s.end.max()
ax.axhline(1, color="k", lw=0.5)
ax.set_ylim(0, 2.5)
ax.set_xlabel("genome position (chr1 to Y)")
ax.set_ylabel("depth / autosomal median")
ax.set_title(f"{sample}, {w // 1000} kb bins: CV {cv:.3f}, MAPD {mapd:.3f}")
fig.tight_layout()
fig.savefig(prefix + ".png", dpi=130)
