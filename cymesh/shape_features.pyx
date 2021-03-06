# cython: boundscheck=False
# cython: wraparound=True
# cython: initializedcheck=False
# cython: nonecheck=False
# cython: cdivision=True
from libc.math cimport sqrt
from libc.stdlib cimport rand, srand, RAND_MAX

import numpy as np
cimport numpy as np

from cymesh.vector3D cimport vdist, vangle, vsub
from cymesh.mesh cimport Mesh
from cymesh.structures cimport Vert

ctypedef double (*vert_metric)(Vert, Vert)

cdef double[:] create_features(vert_metric metric, Mesh mesh, tuple hrange, \
                               int n_points, int n_bins, int rseed) except *:
    cdef int i, j, n, n_verts
    cdef double mean_value, rms, hmin, hmax
    cdef double[:] values = np.zeros(n_points)
    cdef double values_sqr = 0

    srand(rseed)

    if hrange is not None:
        hmin = hrange[0]
        hmax = hrange[1]

    n_verts = len(mesh.verts)
    n = 0

    while n < n_points:
        i = rand() % (n_verts-1)
        j = rand() % (n_verts-1)
        if i != j:
            values[n] = metric(mesh.verts[i], mesh.verts[j])
            values_sqr += values[n] * values[n]
            n += 1

    rms = sqrt(values_sqr / n_points) # Normalize by the root-mean-square.

    for i in range(n_points):
        values[i] /= rms
        if hrange is not None:
            values[i] = max(hmin, values[i])
            values[i] = min(hmax, values[i])

    return np.histogram(values, bins=n_bins, density=True)[0]

cdef double d2_metric(Vert a, Vert b):
    return vdist(a.p, b.p)

cdef double a2_metric(Vert a, Vert b):
    return vangle(a.normal, b.normal)

cpdef double[:] d2_features(Mesh mesh, tuple hrange=(0.0, 3.0), int n_points=1024,
                            int n_bins=64, int rseed=123) except *:
    """ 3D Shape features from 'Matching 3D Models with Shape Distributions'
        Paper pdf: https://graphics.stanford.edu/courses/cs468-01-fall/Papers/osada_funkhouser_chazelle_dobkin.pdf
        Returns a feature vector of size 'bins' from arbitrary sized mesh.
    """
    return create_features(d2_metric, mesh, hrange, n_points, n_bins, rseed)

cpdef double[:] a2_features(Mesh mesh, tuple hrange=(0.0, 3.0), int n_points=1024,
                            int n_bins=64, int rseed=123) except *:
    """ Similar to d2 features but use the angle between the normal directions.
    """
    mesh.calculateNormals()
    return create_features(a2_metric, mesh, hrange, n_points, n_bins, rseed)


cpdef double[:] a3_features(Mesh mesh, tuple hrange=(0.0, 3.0), int n_points=1024,
                            int n_bins=64, int rseed=123) except *:
    """ Similar to d2 features but use the angle between the normal directions.
    """
    cdef int i, j, k, n, n_verts
    cdef double mean_value, rms, hmin, hmax
    cdef double[:] values = np.zeros(n_points)
    cdef double[:] tmp_a = np.zeros(3)
    cdef double[:] tmp_b = np.zeros(3)
    cdef double values_sqr = 0

    srand(rseed)

    n = 0
    n_verts = len(mesh.verts)

    if hrange is not None:
        hmin = hrange[0]
        hmax = hrange[1]

    while n < n_points:
        i = rand() % (n_verts-1)
        j = rand() % (n_verts-1)
        k = rand() % (n_verts-1)
        if i != k and i != j and j != k:
            vsub(tmp_a, mesh.verts[i].p, mesh.verts[j].p)
            vsub(tmp_b, mesh.verts[k].p, mesh.verts[j].p)
            values[n] = vangle(tmp_a, tmp_b)
            values_sqr += values[n] * values[n]
            n += 1

    rms = sqrt(values_sqr / n_points) # Normalize by the root-mean-square.

    for i in range(n_points):
        values[i] /= rms
        if hrange is not None:
            values[i] = max(hmin, values[i])
            values[i] = min(hmax, values[i])

    return np.histogram(values, bins=n_bins, density=True)[0]