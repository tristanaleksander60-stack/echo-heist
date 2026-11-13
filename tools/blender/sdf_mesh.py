"""Signed-distance modelling for soft organic kit pieces (the skinned first-person gloves, docs/art/fp_hands_v2).

Pure numpy (no scikit-image): primitives and smooth unions as vectorised distance functions, a Surface Nets mesher
(one vertex per sign-changing cell, one quad per sign-changing grid edge: a single watertight shell with even,
rounded topology), a projection of the vertices onto the zero level set, analytic normals from the field's gradient,
and an SDF ambient-occlusion estimate for baked vertex shading.

Every function takes points as an (N, 3) float array. A field is any callable P -> (N,) distances (negative inside).
"""
import numpy as np


# ---------------------------------------------------------------- primitives

def round_cone(a, b, ra, rb):
    """A capsule from a to b whose radius goes ra -> rb (linear along the axis; fine for gentle tapers)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    L2 = float(ba @ ba)

    def f(P):
        pa = P - a
        t = np.clip((pa @ ba) / L2, 0.0, 1.0)
        q = pa - t[:, None] * ba
        return np.linalg.norm(q, axis=1) - (ra + (rb - ra) * t)
    return f


def ellipsoid(c, r):
    """An ellipsoid (centre c, radii r): the usual bound-corrected approximation."""
    c, r = np.asarray(c, float), np.asarray(r, float)

    def f(P):
        q = (P - c) / r
        k0 = np.linalg.norm(q, axis=1)
        k1 = np.linalg.norm(q / r, axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    return f


def rounded_box(c, half, rad, warp=None):
    """A box (centre c, half extents) with every edge rounded by rad. warp(Q) -> Q may reshape the local coordinates
    first (tapers, domes): not an exact distance any more, which the mesher does not need."""
    c, half = np.asarray(c, float), np.asarray(half, float)

    def f(P):
        Q = P - c
        if warp is not None:
            Q = warp(Q)
        q = np.abs(Q) - half + rad
        out = np.linalg.norm(np.maximum(q, 0.0), axis=1)
        inside = np.minimum(np.max(q, axis=1), 0.0)
        return out + inside - rad
    return f


def smin(da, db, k):
    """Polynomial smooth minimum: the union of two fields blended over k (0 = a hard union)."""
    if k <= 0:
        return np.minimum(da, db)
    h = np.clip(0.5 + 0.5 * (db - da) / k, 0.0, 1.0)
    return db + (da - db) * h - k * h * (1.0 - h)


def union(fields_k):
    """[(field, k)]: folded left to right, each smooth-unioned onto what came before over its k."""
    def f(P):
        d = fields_k[0][0](P)
        for g, k in fields_k[1:]:
            d = smin(d, g(P), k)
        return d
    return f


# ---------------------------------------------------------------- mesher

_CORNERS = np.array([(i, j, k) for k in (0, 1) for j in (0, 1) for i in (0, 1)])
_EDGES = [(a, b) for a in range(8) for b in range(a + 1, 8) if int(np.abs(_CORNERS[a] - _CORNERS[b]).sum()) == 1]


def surface_nets(field, lo, hi, step):
    """Meshes field < 0 inside the box lo..hi at `step`. Returns (verts (V, 3), quads (Q, 4)), outward winding."""
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    n = np.ceil((hi - lo) / step).astype(int) + 1
    xs = [lo[i] + step * np.arange(n[i]) for i in range(3)]
    G = np.stack(np.meshgrid(*xs, indexing="ij"), axis=-1)
    F = field(G.reshape(-1, 3)).reshape(n)
    F[0, :, :] = F[-1, :, :] = F[:, 0, :] = F[:, -1, :] = F[:, :, 0] = F[:, :, -1] = np.abs(F).max() + 1.0  # closed
    nx, ny, nz = n - 1
    corner_f = np.stack([F[i:i + nx, j:j + ny, k:k + nz] for i, j, k in _CORNERS], axis=-1)       # (nx,ny,nz,8)
    corner_p = np.stack([G[i:i + nx, j:j + ny, k:k + nz] for i, j, k in _CORNERS], axis=-2)       # (nx,ny,nz,8,3)
    neg = corner_f < 0
    active = neg.any(-1) & ~neg.all(-1)
    idx = -np.ones((nx, ny, nz), int)
    cells = np.argwhere(active)
    idx[tuple(cells.T)] = np.arange(len(cells))
    cf, cp = corner_f[active], corner_p[active]
    acc = np.zeros((len(cells), 3))
    cnt = np.zeros(len(cells))
    for a, b in _EDGES:
        fa, fb = cf[:, a], cf[:, b]
        m = (fa < 0) != (fb < 0)
        t = np.where(m, fa / np.where(m, fa - fb, 1.0), 0.0)
        acc[m] += cp[m, a] + t[m, None] * (cp[m, b] - cp[m, a])
        cnt[m] += 1
    verts = acc / np.maximum(cnt, 1)[:, None]
    quads = []
    # an edge along axis `ax` from grid point g to g + e_ax: the four cells around it
    for ax in range(3):
        o1, o2 = (ax + 1) % 3, (ax + 2) % 3
        sl0 = [slice(0, n[i]) for i in range(3)]
        sl0[ax] = slice(0, n[ax] - 1)
        sl1 = list(sl0)
        sl1[ax] = slice(1, n[ax])
        f0, f1 = F[tuple(sl0)], F[tuple(sl1)]
        cross = (f0 < 0) != (f1 < 0)
        g = np.argwhere(cross)
        g = g[(g[:, o1] >= 1) & (g[:, o2] >= 1) & (g[:, o1] < n[o1] - 1) & (g[:, o2] < n[o2] - 1)]
        if len(g) == 0:
            continue
        inside_first = F[tuple(g.T)] < 0

        def cell(d1, d2):
            c = g.copy()
            c[:, o1] -= d1
            c[:, o2] -= d2
            return idx[tuple(c.T)]
        q = np.stack([cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)], axis=1)
        q[inside_first] = q[inside_first][:, ::-1]
        quads.append(q)
    quads = np.concatenate(quads)
    quads = quads[(quads >= 0).all(1)]
    return verts, quads


def gradient(field, P, h=1e-4):
    e = np.eye(3) * h
    return np.stack([(field(P + e[i]) - field(P - e[i])) / (2 * h) for i in range(3)], axis=1)


def project(field, P, iters=3):
    """Moves points onto the zero level set along the gradient (Newton steps)."""
    P = np.array(P, float)
    for _ in range(iters):
        d = field(P)
        g = gradient(field, P)
        P -= (d / np.maximum((g * g).sum(1), 1e-12))[:, None] * g
    return P


def normals(field, P):
    g = gradient(field, P)
    return g / np.maximum(np.linalg.norm(g, axis=1), 1e-12)[:, None]


def occlusion(field, P, N, step, samples=5, strength=1.0):
    """SDF ambient occlusion: 1 = open, lower in creases (between the fingers, under the thumb, at the cuff)."""
    occ = np.zeros(len(P))
    w = 1.0
    for i in range(1, samples + 1):
        h = step * i
        occ += w * np.maximum(0.0, h - field(P + N * h)) / h
        w *= 0.5
    return np.clip(1.0 - strength * occ, 0.0, 1.0)
