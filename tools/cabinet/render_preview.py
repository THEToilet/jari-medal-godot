"""確認用の簡易ソフトウェアレンダラ（numpy）。glbと同じシーングラフを描く。"""
import math, sys
import numpy as np
from PIL import Image
import build_cabinet as B

W, H = int(sys.argv[2]) if len(sys.argv) > 2 else 900, int(sys.argv[3]) if len(sys.argv) > 3 else 1200
yaw = float(sys.argv[4]) if len(sys.argv) > 4 else 28
out = sys.argv[1] if len(sys.argv) > 1 else "preview.png"

def rx(deg):
    t = math.radians(deg); c, s = math.cos(t), math.sin(t)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])

items = []
def walk(n, R, T):
    R2 = R @ rx(n.rot_x); T2 = T + R @ np.array(n.t, float)
    if n.mesh is not None:
        items.append((n.mesh.v @ R2.T + T2, n.mesh.n @ R2.T, n.mesh.i.reshape(-1, 3), n.mesh.uv, B.MATS[n.material], n.name))
    for c in n.children: walk(c, R2, T2)
walk(B.root, np.eye(3), np.zeros(3))

# カメラ
target = np.array([0, 0.80, 0]); dist = 2.9; pitch = 8
ty, tp = math.radians(yaw), math.radians(pitch)
eye = target + dist * np.array([math.sin(ty) * math.cos(tp), math.sin(tp), math.cos(ty) * math.cos(tp)])
f = target - eye; f /= np.linalg.norm(f); r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r); u = np.cross(r, f)
fov = math.radians(38); fy = (H / 2) / math.tan(fov / 2)
light = np.array([0.5, 0.8, 0.6]); light /= np.linalg.norm(light)
fill = np.array([-0.7, 0.2, 0.3]); fill /= np.linalg.norm(fill)

img = np.zeros((H, W, 3));
yy = np.linspace(0, 1, H)[:, None]
img[:] = (np.array([0.93, 0.95, 0.98]) * (1 - yy) + np.array([0.78, 0.82, 0.9]) * yy)[:, None, :][:, 0, :][:, None, :]
zb = np.full((H, W), np.inf)

def screen_tex(uv, name):
    U, V = uv[..., 0], uv[..., 1]
    if name == "Screen":
        c = np.stack([0.2 + 0.5 * U, 0.6 - 0.3 * V, 0.95 - 0.2 * U], -1)
        bld = ((U * 10).astype(int) % 3 == 0) & (V > 0.45 + 0.25 * np.abs(np.sin(U * 13)))
        c[bld] = [0.15, 0.15, 0.3]; return c
    if name == "TopperLogo":   # 仮：ロゴ画像が入る場所
        c = np.ones(U.shape + (3,)); c[..., :] = [0.55, 0.57, 0.62]; return c
    if name == "FrontDecal":   # 仮：前面の絵が入る場所
        c = np.ones(U.shape + (3,)); c[..., :] = [0.93, 0.93, 0.93]; return c
    return None

for V3, N3, T, UV, M, name in items:
    rel = V3 - eye
    cx, cy, cz = rel @ r, rel @ u, rel @ f
    px = W / 2 + fy * cx / cz; py = H / 2 - fy * cy / cz
    base = np.array(M["color"]); em = np.array(M["emissive"] or [0, 0, 0])
    nn = N3 / np.linalg.norm(N3, axis=1, keepdims=True)
    for tri in T:
        a, b, c = tri
        x0, y0, x1, y1, x2, y2 = px[a], py[a], px[b], py[b], px[c], py[c]
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-9: continue
        minx, maxx = int(max(0, math.floor(min(x0, x1, x2)))), int(min(W - 1, math.ceil(max(x0, x1, x2))))
        miny, maxy = int(max(0, math.floor(min(y0, y1, y2)))), int(min(H - 1, math.ceil(max(y0, y1, y2))))
        if minx > maxx or miny > maxy: continue
        gx, gy = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
        w0 = ((x1 - gx) * (y2 - gy) - (x2 - gx) * (y1 - gy)) / area
        w1 = ((x2 - gx) * (y0 - gy) - (x0 - gx) * (y2 - gy)) / area
        w2 = 1 - w0 - w1
        ins = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not ins.any(): continue
        z = 1.0 / (w0 / cz[a] + w1 / cz[b] + w2 / cz[c])
        sub = zb[miny:maxy + 1, minx:maxx + 1]
        m = ins & (z < sub)
        if not m.any(): continue
        n = (w0[..., None] * nn[a] + w1[..., None] * nn[b] + w2[..., None] * nn[c])
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        col = base
        if UV is not None:
            uvp = w0[..., None] * UV[a] + w1[..., None] * UV[b] + w2[..., None] * UV[c]
            t = screen_tex(uvp, name)
            if t is not None: col = t
        dif = np.clip(n @ light, 0, 1)[..., None]; dif2 = np.clip(n @ fill, 0, 1)[..., None]
        view = -(eye - (w0[..., None] * V3[a] + w1[..., None] * V3[b] + w2[..., None] * V3[c]))
        view /= np.linalg.norm(view, axis=-1, keepdims=True)
        h = light - view; h /= np.linalg.norm(h, axis=-1, keepdims=True)
        spec = np.clip((n * h).sum(-1), 0, 1)[..., None] ** (8 + 120 * (1 - M["rough"])) * (0.25 + 0.9 * M["metallic"])
        if M["metallic"] > 0.5:
            env = 0.55 + 0.45 * n[..., 1:2]
            shade = col * (0.25 + 0.5 * dif + 0.4 * env) + spec
        else:
            shade = col * (0.32 + 0.62 * dif + 0.18 * dif2) + spec * 0.6
        if M["emissive"]:
            shade = shade + (col if UV is not None else em) * (0.9 if UV is not None else 0.8)
        sub[m] = z[m]
        img[miny:maxy + 1, minx:maxx + 1][m] = np.clip(shade, 0, 1)[m]

# 床の影っぽい楕円
Image.fromarray((img * 255).astype(np.uint8)).save(out)
print("saved", out)
