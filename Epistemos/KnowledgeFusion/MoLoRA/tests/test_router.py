"""Tests for the AdaFuse centroid router."""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mlx.core as mx
from molora_inference import AdaFuseRouter


def _make_router(centroids_dict: dict):
    """Create a router from a dict of {name: centroid_array}."""
    router = AdaFuseRouter.__new__(AdaFuseRouter)
    router.domain_names = list(centroids_dict.keys())
    router.centroids = mx.stack(list(centroids_dict.values()))
    router.active = True
    return router


def test_routes_to_nearest_centroid():
    """Token hidden states route to the nearest centroid."""
    d = 32
    centroids = {
        "knowledge": mx.array([1.0] + [0.0] * (d - 1)),
        "style": mx.array([0.0, 1.0] + [0.0] * (d - 2)),
        "tool": mx.array([0.0, 0.0, 1.0] + [0.0] * (d - 3)),
    }
    router = _make_router(centroids)

    # Close to knowledge centroid
    h = mx.array([[0.9, 0.1, 0.0] + [0.0] * (d - 3)])
    route = router.route(h)
    mx.eval(route)
    assert int(route[0]) == 0, f"Expected 0 (knowledge), got {int(route[0])}"

    # Close to style centroid
    h2 = mx.array([[0.1, 0.9, 0.0] + [0.0] * (d - 3)])
    route2 = router.route(h2)
    mx.eval(route2)
    assert int(route2[0]) == 1, f"Expected 1 (style), got {int(route2[0])}"

    # Close to tool centroid
    h3 = mx.array([[0.0, 0.1, 0.9] + [0.0] * (d - 3)])
    route3 = router.route(h3)
    mx.eval(route3)
    assert int(route3[0]) == 2, f"Expected 2 (tool), got {int(route3[0])}"


def test_batch_routing():
    """Multiple tokens route correctly in a batch."""
    d = 16
    centroids = {
        "a": mx.array([1.0] + [0.0] * (d - 1)),
        "b": mx.array([0.0, 1.0] + [0.0] * (d - 2)),
    }
    router = _make_router(centroids)

    h = mx.array([
        [0.9, 0.1] + [0.0] * (d - 2),  # → a (0)
        [0.1, 0.9] + [0.0] * (d - 2),  # → b (1)
        [0.8, 0.2] + [0.0] * (d - 2),  # → a (0)
    ])
    routes = router.route(h)
    mx.eval(routes)

    assert int(routes[0]) == 0
    assert int(routes[1]) == 1
    assert int(routes[2]) == 0


def test_determinism():
    """Same input always produces same route."""
    d = 16
    centroids = {
        "x": mx.array([1.0] + [0.0] * (d - 1)),
        "y": mx.array([0.0, 1.0] + [0.0] * (d - 2)),
    }
    router = _make_router(centroids)

    h = mx.array([[0.7, 0.3] + [0.0] * (d - 2)])
    route1 = router.route(h)
    route2 = router.route(h)
    mx.eval(route1, route2)

    assert int(route1[0]) == int(route2[0])


def test_inactive_router_defaults_to_zero():
    """Inactive router (no centroids) routes everything to adapter 0."""
    router = AdaFuseRouter.__new__(AdaFuseRouter)
    router.centroids = None
    router.active = False
    router.domain_names = []

    h = mx.random.normal((4, 64))
    routes = router.route(h)
    mx.eval(routes)

    for i in range(4):
        assert int(routes[i]) == 0


def test_single_adapter():
    """With one adapter, all tokens route to it."""
    d = 16
    centroids = {"only": mx.array([1.0] + [0.0] * (d - 1))}
    router = _make_router(centroids)

    h = mx.random.normal((8, d))
    routes = router.route(h)
    mx.eval(routes)

    for i in range(8):
        assert int(routes[i]) == 0


if __name__ == "__main__":
    tests = [
        test_routes_to_nearest_centroid,
        test_batch_routing,
        test_determinism,
        test_inactive_router_defaults_to_zero,
        test_single_adapter,
    ]
    for test in tests:
        try:
            test()
            print(f"  PASS: {test.__name__}")
        except Exception as e:
            print(f"  FAIL: {test.__name__}: {e}")
