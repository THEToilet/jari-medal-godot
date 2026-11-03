"""じゃりメダル筐体 v0.4（ローポリ・一体型）を .glb で生成する。依存: numpy のみ。
Godot座標系 (Y上, 正面=+Z, 単位m)。丸みは最小限の頂点＋スムーズ法線で表現する。
"""
import json, struct, math
import numpy as np

# ---------------------------------------------------------------- materials
MATS = {}
def mat(name, color, metallic=0.0, rough=0.5, emissive=None):
    MATS[name] = dict(name=name, color=color, metallic=metallic, rough=rough, emissive=emissive)
    return name
def hexc(h):
    h = h.lstrip('#'); return [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]

M_FRONT  = mat("FrontOrange", hexc("FF6B2C"), rough=0.3)
M_BODY   = mat("BodyWhite", hexc("F4F2EE"), rough=0.3)
M_DECK   = mat("DeckCharcoal", hexc("2A2B31"), rough=0.4)
M_FACE   = mat("FaceCharcoal", hexc("2A2B31"), rough=0.35)
M_BEZEL  = mat("BezelBlack", hexc("0C0C10"), rough=0.3)
M_STEEL  = mat("PocketSteel", hexc("5E636C"), metallic=0.3, rough=0.4)
M_CHROME = mat("Chrome", hexc("D8DCE2"), metallic=0.5, rough=0.25)
M_DARK   = mat("SlotDark", hexc("050505"), rough=0.9)
M_RED    = mat("ButtonRed", hexc("E8322B"), rough=0.25)
M_SCREEN = mat("ScreenMat", [0.05, 0.05, 0.08], rough=0.1, emissive=[0.25, 0.35, 0.6])
M_LOGO   = mat("TopperLogoMat", [1, 1, 1], rough=0.5, emissive=[0.15, 0.15, 0.15])
M_DECAL  = mat("FrontDecalMat", [1, 1, 1], rough=0.5)
M_LED    = mat("LEDMat", [1, 1, 1], rough=0.3, emissive=[1.0, 0.35, 0.75])

# ---------------------------------------------------------------- mesh
class Mesh:
    def __init__(s, v, n, i, uv=None):
        s.v = np.asarray(v, np.float32).reshape(-1, 3); s.n = np.asarray(n, np.float32).reshape(-1, 3)
        s.i = np.asarray(i, np.uint32).reshape(-1); s.uv = None if uv is None else np.asarray(uv, np.float32)
    def moved(s, d):
        return Mesh(s.v + np.asarray(d, np.float32), s.n, s.i, s.uv)

def merge(ms):
    v, n, i, off = [], [], [], 0
    for m in ms:
        v.append(m.v); n.append(m.n); i.append(m.i + off); off += len(m.v)
    return Mesh(np.concatenate(v), np.concatenate(n), np.concatenate(i))

def fix_winding(m):
    t = m.i.reshape(-1, 3).copy()
    a, b, c = m.v[t[:, 0]], m.v[t[:, 1]], m.v[t[:, 2]]
    fn = np.cross(b - a, c - a); vn = m.n[t[:, 0]] + m.n[t[:, 1]] + m.n[t[:, 2]]
    bad = (fn * vn).sum(1) < 0; t[bad] = t[bad][:, [0, 2, 1]]
    m.i = t.reshape(-1).astype(np.uint32); return m

def quad(w, h, center=(0, 0, 0)):
    cx, cy, cz = center
    v = [[cx - w/2, cy - h/2, cz], [cx + w/2, cy - h/2, cz], [cx + w/2, cy + h/2, cz], [cx - w/2, cy + h/2, cz]]
    return Mesh(v, [[0, 0, 1]] * 4, [0, 1, 2, 0, 2, 3], [[0, 1], [1, 1], [1, 0], [0, 0]])

def rrect_loop(hx, hy, r, seg=3):
    """角丸長方形のループ (点, 外向き法線)。CCW"""
    P, N = [], []
    for cx, cy, a0 in ((hx - r, hy - r, 0), (-(hx - r), hy - r, 90), (-(hx - r), -(hy - r), 180), (hx - r, -(hy - r), 270)):
        for k in range(seg + 1):
            t = math.radians(a0 + 90 * k / seg); n = (math.cos(t), math.sin(t))
            P.append((cx + r * n[0], cy + r * n[1])); N.append(n)
    return np.array(P), np.array(N)

def rounded_plate(w, h, d, r, seg=2):
    """前面(+Z)に向いた角丸の板。前面の縁だけ丸める軽量版"""
    P, N = rrect_loop(w / 2, h / 2, r, seg)
    P0, _ = rrect_loop(w / 2 - r * 0.45, h / 2 - r * 0.45, r * 0.55, seg)
    n = len(P); V, NN, I = [], [], []
    for p, q in zip(P, N): V.append([p[0], p[1], 0]); NN.append([q[0], q[1], 0])          # 側面下
    for p, q in zip(P, N): V.append([p[0], p[1], d - r * 0.45]); NN.append([q[0], q[1], 0])  # 側面上
    for p, q in zip(P0, N): V.append([p[0], p[1], d]); NN.append([q[0] * 0.5, q[1] * 0.5, 0.85])  # 丸め
    c = len(V); V.append([0, 0, d]); NN.append([0, 0, 1])
    for k in range(n):
        j = (k + 1) % n
        for ring in (0, 1):
            a, b = ring * n + k, ring * n + j
            I += [a, b, b + n, a, b + n, a + n]
        I += [2 * n + k, 2 * n + j, c]
    return fix_winding(Mesh(V, NN, I))

def cylinder(r, h, seg=16, center=(0, 0, 0), caps=(True, True)):
    V, N, I = [], [], []
    for k in range(seg):
        t = 2 * math.pi * k / seg; c, s = math.cos(t), math.sin(t)
        V += [[r * c, -h/2, r * s], [r * c, h/2, r * s]]; N += [[c, 0, s], [c, 0, s]]
    for k in range(seg):
        a, b = 2 * k, 2 * ((k + 1) % seg); I += [a, a + 1, b + 1, a, b + 1, b]
    for y, ny, on in ((-h/2, -1, caps[0]), (h/2, 1, caps[1])):
        if not on: continue
        c0 = len(V); V.append([0, y, 0]); N.append([0, ny, 0])
        for k in range(seg):
            t = 2 * math.pi * k / seg; V.append([r * math.cos(t), y, r * math.sin(t)]); N.append([0, ny, 0])
        for k in range(seg): I += [c0, c0 + 1 + k, c0 + 1 + (k + 1) % seg]
    return fix_winding(Mesh(np.array(V) + center, N, I))

def dome(r, seg=16, rings=3, center=(0, 0, 0), sy=1.0):
    V, N, I = [], [], []
    for j in range(rings + 1):
        ph = (math.pi / 2) * j / rings
        cnt = seg if j < rings else 1
        for k in range(cnt):
            t = 2 * math.pi * k / seg
            n = [math.cos(ph) * math.cos(t), math.sin(ph), math.cos(ph) * math.sin(t)]
            V.append([r * n[0], r * n[1] * sy, r * n[2]]); N.append(n)
    for j in range(rings - 1):
        for k in range(seg):
            a, b = j * seg + k, j * seg + (k + 1) % seg
            I += [a, a + seg, b + seg, a, b + seg, b]
    top = len(V) - 1; base = (rings - 1) * seg
    for k in range(seg): I += [base + k, top, base + (k + 1) % seg]
    return fix_winding(Mesh(np.array(V) + center, N, I))

def hline(m):
    """Y軸向きのメッシュをX軸向きにする"""
    return fix_winding(Mesh(m.v[:, [1, 0, 2]], m.n[:, [1, 0, 2]], m.i))

def hazard_stripes(x0, x1, y0, y1, w=0.035, gap=0.075, slant=0.04, z=0.0):
    """平らな黒い平行四辺形（板ポリ）。1本2三角形"""
    V, N, I = [], [], []; x = x0
    while x + w + slant <= x1 + 1e-6:
        b = len(V)
        V += [[x, y0, z], [x + w, y0, z], [x + w + slant, y1, z], [x + slant, y1, z]]; N += [[0, 0, 1]] * 4
        I += [b, b + 1, b + 2, b, b + 2, b + 3]; x += gap
    return Mesh(V, N, I)

def rot_y(m, deg):
    t = math.radians(deg); c, s = math.cos(t), math.sin(t); R = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return fix_winding(Mesh(m.v @ R.T, m.n @ R.T, m.i, m.uv))

# ---------------------------------------------------------------- scene graph
class Node:
    def __init__(s, name, mesh=None, material=None, t=(0, 0, 0), rot_x=0.0, children=None):
        s.name, s.mesh, s.material, s.t, s.rot_x = name, mesh, material, tuple(float(x) for x in t), rot_x
        s.children = children or []

# ---------------------------------------------------------------- 一体型シェル（ローポリ）
def fillet_outline(pts, radii, arc_seg=4):
    """(z,y)のCCW多角形の角を丸める。[(点, 外向き法線)] と、各角の最初の点のindexを返す"""
    P = [np.array(p, float) for p in pts]; n = len(P); out = []; starts = []
    for k in range(n):
        Q, C, R = P[k - 1], P[k], P[(k + 1) % n]; r = radii[k]
        d1 = (Q - C) / np.linalg.norm(Q - C); d2 = (R - C) / np.linalg.norm(R - C)
        a = math.acos(np.clip(d1 @ d2, -1, 1)) / 2
        T1 = C + d1 * (r / math.tan(a)); T2 = C + d2 * (r / math.tan(a))
        cen = C + (d1 + d2) / np.linalg.norm(d1 + d2) * (r / math.sin(a))
        ein, eout = C - Q, R - C
        convex = (ein[0] * eout[1] - ein[1] * eout[0]) > 0
        a1 = math.atan2(*(T1 - cen)[::-1]); a2 = math.atan2(*(T2 - cen)[::-1])
        da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        starts.append(len(out))
        for j in range(arc_seg + 1):
            th = a1 + da * j / arc_seg
            p = cen + r * np.array([math.cos(th), math.sin(th)]); nn = (p - cen) / r
            out.append((p, nn if convex else -nn))
    return out, starts

def ear_clip(poly):
    idx = []
    for k in range(len(poly)):
        if not idx or np.hypot(poly[k][0] - poly[idx[-1]][0], poly[k][1] - poly[idx[-1]][1]) > 1e-7: idx.append(k)
    def cross(o, a, b): return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    def inside(p, a, b, c, e=1e-12): return cross(a, b, p) > e and cross(b, c, p) > e and cross(c, a, p) > e
    tris = []; guard = 0
    while len(idx) > 3 and guard < 100000:
        guard += 1; m = len(idx); found = False
        for k in range(m):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % m]
            a, b, c = poly[i0], poly[i1], poly[i2]
            if cross(a, b, c) <= 1e-12: continue
            if any(inside(poly[j], a, b, c) for j in idx if j not in (i0, i1, i2)): continue
            tris.append((i0, i1, i2)); idx.pop(k); found = True; break
        if not found: idx.pop(0)
    if len(idx) == 3: tris.append(tuple(idx))
    return tris

def swept_shell(outline, width, r, seg=3, skip=(), group=lambda i: "Body"):
    """側面輪郭を幅方向に押し出し、左右の縁を半径rで丸める。skip: 中央の平面を作らない区間(index)"""
    V, N = [], []; G = {}
    cols = [(-1, math.pi / 2 * k / seg) for k in range(seg, -1, -1)] + [(1, math.pi / 2 * k / seg) for k in range(seg + 1)]
    nc = len(cols); m = len(outline)
    for p, nn in outline:
        for s, ph in cols:
            cz, cy = p - nn * r
            V.append([s * (width / 2 - r) + s * r * math.sin(ph), cy + nn[1] * r * math.cos(ph), cz + nn[0] * r * math.cos(ph)])
            N.append([s * math.sin(ph), nn[1] * math.cos(ph), nn[0] * math.cos(ph)])
    for i in range(m):
        j = (i + 1) % m
        for c in range(nc - 1):
            if c == seg and i in skip: continue
            a, b = i * nc + c, i * nc + c + 1; d, e = j * nc + c, j * nc + c + 1
            G.setdefault(group(i), []).extend([a, b, e, a, e, d])
    I = G.setdefault("Body", [])
    inset = [tuple(p - nn * r) for p, nn in outline]
    tris = ear_clip(inset)
    for s in (-1, 1):
        base = len(V)
        for z, y in inset: V.append([s * width / 2, y, z]); N.append([s, 0, 0])
        for t in tris: I += [base + t[0], base + t[1], base + t[2]]
    V = np.array(V); N = np.array(N); out = {}
    for g, idx in G.items():
        idx = np.array(idx); used = np.unique(idx); remap = -np.ones(len(V), int); remap[used] = np.arange(len(used))
        out[g] = fix_winding(Mesh(V[used], N[used], remap[idx]))
    return out

class Face:
    """平らな前面区間の座標系。u=横(X), v=面に沿って上, w=外向き"""
    def __init__(s, p0, p1, half_w):
        p0, p1 = np.array(p0), np.array(p1)
        s.L = float(np.linalg.norm(p1 - p0)); t = (p1 - p0) / s.L
        s.O = np.array([0, p0[1], p0[0]]); s.T = np.array([0, t[1], t[0]]); s.Nw = np.array([0, -t[0], t[1]])
        s.hw = half_w
        s.tilt = math.degrees(math.atan2(t[0], t[1]))   # +Zを面の法線に合わせる rot_x
    def P(s, u, v, w=0.0): return s.O + np.array([u, 0, 0]) + s.T * v + s.Nw * w
    def D(s, du, dv, dw): return np.array([du, 0, 0]) + s.T * dv + s.Nw * dw
    def at(s, v, w=0.0): return s.P(0, v, w)

def face_with_recess(F, vc, hx, hy, rr, depth, rim=0.01, fil=0.012, seg=3):
    """穴あきの平面＋なめらかな縁＋くぼみ。(本体側メッシュ, くぼみ内側メッシュ) を返す"""
    P2, N2 = rrect_loop(hx, hy, rr, seg); P2 = P2 + [0, vc]; n = len(P2)
    def vn(d2, dw):  # 2D法線成分と面法線成分から3D法線
        v = F.D(d2[0], d2[1], dw); return v / np.linalg.norm(v)
    # --- 平面部：穴の外周の各点を法線方向に外枠までまっすぐ伸ばし、穴と外枠をはしご状につなぐ
    #     （放射状に伸ばした線どうしは交差しないので、三角形が穴に重ならない）
    hole = P2 + N2 * rim
    V, NN, I = [], [], []
    for p in hole: V.append(F.P(p[0], p[1])); NN.append(F.Nw)
    corner_of = {(0, 1): (F.hw, F.L), (1, 2): (-F.hw, F.L), (2, 3): (-F.hw, 0.0), (3, 0): (F.hw, 0.0)}
    def ray_hit(p, d):   # 外枠（右0・上1・左2・下3）との交点と辺の番号
        cands = []
        if d[0] > 1e-9: cands.append(((F.hw - p[0]) / d[0], 0))
        if d[1] > 1e-9: cands.append(((F.L - p[1]) / d[1], 1))
        if d[0] < -1e-9: cands.append(((-F.hw - p[0]) / d[0], 2))
        if d[1] < -1e-9: cands.append(((0.0 - p[1]) / d[1], 3))
        t, e = min(cands)
        return p + d * t, e
    hits = [ray_hit(p, q) for p, q in zip(hole, N2)]
    out_idx = []
    for p, e in hits:
        out_idx.append(len(V)); V.append(F.P(p[0], p[1])); NN.append(F.Nw)
    for k in range(n):
        j = (k + 1) % n
        hk, hj = k, j
        ok, oj = out_idx[k], out_idx[j]
        ek, ej = hits[k][1], hits[j][1]
        if ek == ej:
            I += [hk, ok, oj, hk, oj, hj]
        else:   # 辺が変わるところは外枠の角をはさむ
            c = corner_of[(ek, ej)]
            ci = len(V); V.append(F.P(c[0], c[1])); NN.append(F.Nw)
            I += [hk, ok, ci, hk, ci, oj, hk, oj, hj]
    # --- 縁の丸み（面→壁）: 本体側
    rings_body, rings_in = [], []
    for k in range(3):
        th = math.pi / 2 * k / 2
        ring = []
        for p, q in zip(P2, N2):
            cen = p + q * rim
            pos2 = cen - q * rim * math.sin(th); w = -rim + rim * math.cos(th)
            ring.append((F.P(pos2[0], pos2[1], w), vn(-q * math.sin(th), math.cos(th))))
        rings_body.append(ring)
    # --- 壁→底の丸み と 底: くぼみ側
    rings_in.append([(F.P(p[0], p[1], -rim), vn(-q, 0)) for p, q in zip(P2, N2)])
    for k in range(3):
        th = math.pi / 2 * k / 2
        ring = []
        for p, q in zip(P2, N2):
            cen = p - q * fil
            pos2 = cen + q * fil * math.cos(th); w = -(depth - fil) - fil * math.sin(th)
            ring.append((F.P(pos2[0], pos2[1], w), vn(-q * math.cos(th), math.sin(th))))
        rings_in.append(ring)
    def stitch(rings, V, NN, I, cap=None):
        base = len(V)
        for ring in rings:
            for p, q in ring: V.append(p); NN.append(q)
        for r_ in range(len(rings) - 1):
            for k in range(n):
                a, b = base + r_ * n + k, base + r_ * n + (k + 1) % n
                I += [a, b, b + n, a, b + n, a + n]
        if cap is not None:
            c = len(V); V.append(cap[0]); NN.append(cap[1]); last = base + (len(rings) - 1) * n
            for k in range(n): I += [last + k, last + (k + 1) % n, c]
    stitch(rings_body, V, NN, I)
    body = fix_winding(Mesh(V, NN, I))
    V2, N2_, I2 = [], [], []
    stitch(rings_in, V2, N2_, I2, cap=(F.P(0, vc, -depth), F.Nw))
    return body, fix_winding(Mesh(V2, N2_, I2))

def plain_face(F):
    V = [F.P(-F.hw, 0), F.P(F.hw, 0), F.P(F.hw, F.L), F.P(-F.hw, F.L)]
    return fix_winding(Mesh(V, [F.Nw] * 4, [0, 1, 2, 0, 2, 3]))

def node_on(F, name, v, w, children, u=0.0):
    return Node(name, None, None, t=F.P(u, v, w), rot_x=F.tilt, children=children)

# ---------------------------------------------------------------- 形
BW = 0.60; HW = BW / 2
SIDE_R = 0.03
ARC = 4
import os
DECK_DEG = float(os.environ.get("DECK_DEG", 40))   # ボタン面の傾き（水平から）
DECK_Y = 0.78                                        # ボタン面の手前の高さ
PROFILE = [            # 側面シルエット (z, y) と角の丸み
    ((-0.30, 0.00), 0.03),   # 0 背面下
    (( 0.27, 0.00), 0.03),   # 1 前面下
    (( 0.27, DECK_Y), 0.05),                                        # 2 前面上 → ボタン面
    (( 0.06, DECK_Y + 0.21 * math.tan(math.radians(DECK_DEG))), 0.04),  # 3 ボタン面 → モニター面（入隅）
    ((-0.03, 1.52), 0.07),   # 4 モニター面上
    ((-0.24, 1.52), 0.07),   # 5 天面後ろ
    ((-0.30, 0.95), 0.08),   # 6 背面の絞り
]
outline, starts = fillet_outline([p for p, _ in PROFILE], [r for _, r in PROFILE], ARC)
def seg_after(k):  # 角kの後ろの直線区間（index, 始点, 終点）
    i = starts[k] + ARC; return i, outline[i][0], outline[(i + 1) % len(outline)][0]

i_front, a_front, b_front = seg_after(1)   # 前面
i_mon, a_mon, b_mon = seg_after(3)         # モニター面
i_btn, a_btn, b_btn = seg_after(2)         # ボタン面
FHW = HW - SIDE_R
F_FRONT = Face(a_front, b_front, FHW)
F_MON = Face(a_mon, b_mon, FHW)
F_BTN = Face(a_btn, b_btn, FHW)

def color_group(i):
    """輪郭の区間ごとの色分け"""
    k_of = lambda k: range(starts[k], starts[k] + ARC)
    if i in k_of(1) or i == i_front or i in k_of(2): return "Front"
    if i == i_btn: return "Deck"
    if i in k_of(3) or i == i_mon: return "Face"
    return "Body"
shell = swept_shell(outline, BW, SIDE_R, 3, skip={i_front, i_mon}, group=color_group)
fz = F_FRONT.O[2]

# 払い出し口（前面のくぼみ）と モニター（埋め込み）
POCKET_VC = 0.285 - F_FRONT.O[1]
front_body, pocket_in = face_with_recess(F_FRONT, POCKET_VC, 0.16, 0.105, 0.035, 0.14, rim=0.012, fil=0.02)
MON_VC = 0.18
mon_body, mon_in = face_with_recess(F_MON, MON_VC, 0.235, 0.14, 0.02, 0.025, rim=0.008, fil=0.008)

children = [
    Node("Shell", shell["Body"], M_BODY),
    Node("ShellFront", merge([shell["Front"], front_body]), M_FRONT),
    Node("ShellDeck", shell["Deck"], M_DECK),
    Node("ShellFace", merge([shell["Face"], mon_body]), M_FACE),
    Node("PayoutPocket", pocket_in, M_STEEL),
    Node("MonitorRecess", mon_in, M_BEZEL),
]
children.append(node_on(F_FRONT, "PayoutChuteFrame", POCKET_VC + 0.05, -0.139,
                        [Node("PayoutChute", quad(0.22, 0.05), M_DARK)]))
SW, SH = 0.44, 0.2475
children.append(node_on(F_MON, "Monitor", MON_VC, -0.0235, [Node("Screen", quad(SW, SH), M_SCREEN)]))
# ポップ（モニター上の小さなロゴ帯）
POP_V = MON_VC + 0.14 + 0.012 + 0.075
children.append(node_on(F_MON, "Pop", POP_V, 0.0, [
    Node("PopPlate", rounded_plate(0.44, 0.13, 0.006, 0.02), M_BEZEL),
    Node("TopperLogo", quad(0.42, 0.11, (0, 0, 0.0065)), M_LOGO),
]))
# 前面：ハザード帯・デカール
children += [
    Node("FrontDecal", quad(0.40, 0.17, (0, 0.62, fz + 0.001)), M_DECAL),
]
# メダル投入口（払い出し口の右上）
children.append(Node("CoinSlot", None, None, t=(0.205, 0.465, fz), children=[
    Node("CoinSlotPlate", rounded_plate(0.07, 0.11, 0.006, 0.012), M_CHROME),
    Node("CoinSlotHole", quad(0.007, 0.042, (0, -0.012, 0.0062)), M_DARK),
    Node("CoinSlotArrow", Mesh([[-0.011, 0.045, 0.0062], [0.011, 0.045, 0.0062], [0, 0.03, 0.0062]], [[0, 0, 1]] * 3, [0, 1, 2]), M_RED),
]))
# ボタン（斜面に1個、出っ張りなし）
btn_face = node_on(F_BTN, "ControlPanel", F_BTN.L / 2, 0.0, [
    Node("Button", None, None, rot_x=90, children=[
        Node("ButtonRing", cylinder(0.075, 0.008, 20, (0, 0.004, 0), caps=(False, True)), M_CHROME),
        Node("ButtonCap", merge([cylinder(0.064, 0.02, 20, (0, 0.014, 0), caps=(False, False)),
                                 dome(0.064, 20, 3, (0, 0.024, 0), sy=0.3)]), M_RED),
    ])])
children.append(btn_face)
# LED：前面の左右の角
for side, sx in (("L", -1), ("R", 1)):
    px = sx * (FHW + SIDE_R * 0.7071); pz = fz - SIDE_R + SIDE_R * 0.7071
    children.append(Node(f"LED_Body_{side}", cylinder(0.006, 0.62, 6, (px, 0.40, pz), caps=(False, False)), M_LED))
led = hline(cylinder(0.006, BW - 2 * SIDE_R - 0.02, 6, caps=(False, False)))
_c = outline[starts[2] + ARC // 2]   # 前面→ボタン面の角の中ほど
children.append(Node("LED_Deck", led.moved([0, _c[0][1] - _c[1][1] * 0.004, _c[0][0] - _c[1][0] * 0.004]), M_LED))

root = Node("JariCabinet", None, None, children=children)

# ---------------------------------------------------------------- glTF writer
def write_glb(root, path):
    gltf = dict(asset=dict(version="2.0", generator="jari-cabinet-py"), scenes=[dict(nodes=[0])], scene=0,
                nodes=[], meshes=[], materials=[], accessors=[], bufferViews=[], buffers=[])
    blob = bytearray(); mat_idx = {}

    def add_view(data, target):
        while len(blob) % 4: blob.append(0)
        off = len(blob); blob.extend(data)
        gltf["bufferViews"].append(dict(buffer=0, byteOffset=off, byteLength=len(data), target=target))
        return len(gltf["bufferViews"]) - 1

    def add_acc(arr, typ, comp, target, mm=False):
        bv = add_view(arr.tobytes(), target)
        a = dict(bufferView=bv, componentType=comp, count=len(arr), type=typ)
        if mm: a["min"] = arr.min(0).tolist(); a["max"] = arr.max(0).tolist()
        gltf["accessors"].append(a); return len(gltf["accessors"]) - 1

    def get_mat(name):
        if name not in mat_idx:
            m = MATS[name]
            lin = lambda c: [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c]   # glTFの色はリニア
            d = dict(name=name, pbrMetallicRoughness=dict(baseColorFactor=lin(m["color"]) + [1.0],
                     metallicFactor=m["metallic"], roughnessFactor=m["rough"]))
            if m["emissive"]: d["emissiveFactor"] = lin(m["emissive"])
            gltf["materials"].append(d); mat_idx[name] = len(gltf["materials"]) - 1
        return mat_idx[name]

    def visit(n):
        idx = len(gltf["nodes"]); nd = dict(name=n.name); gltf["nodes"].append(nd)
        if any(n.t): nd["translation"] = [float(x) for x in n.t]
        if n.rot_x:
            h = math.radians(n.rot_x) / 2; nd["rotation"] = [math.sin(h), 0, 0, math.cos(h)]
        if n.mesh is not None:
            m = n.mesh
            attrs = dict(POSITION=add_acc(m.v.astype(np.float32), "VEC3", 5126, 34962, True),
                         NORMAL=add_acc((m.n / np.linalg.norm(m.n, axis=1, keepdims=True)).astype(np.float32), "VEC3", 5126, 34962))
            if m.uv is not None: attrs["TEXCOORD_0"] = add_acc(m.uv, "VEC2", 5126, 34962)
            ind = add_acc(m.i.astype(np.uint32), "SCALAR", 5125, 34963)
            gltf["meshes"].append(dict(name=n.name + "_mesh", primitives=[dict(attributes=attrs, indices=ind, material=get_mat(n.material))]))
            nd["mesh"] = len(gltf["meshes"]) - 1
        if n.children: nd["children"] = [visit(c) for c in n.children]
        return idx

    visit(root)
    while len(blob) % 4: blob.append(0)
    gltf["buffers"].append(dict(byteLength=len(blob)))
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4: js += b" "
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942)); f.write(blob)

if __name__ == "__main__":
    write_glb(root, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "virtual", "jari_cabinet.glb"))
    print("written")
