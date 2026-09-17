#!/usr/bin/env python3
"""Measure an exported dog GLB and print the nodes/root_scale it needs.

Meshy's rig-step Height field does not reliably survive export, so the only
honest way to size a delivery is to measure it. Run this on the .glb before
touching the .import file.

    python3 tools/measure_dog_glb.py assets/models/dogs/shadow/shadow.glb 1.2
"""
import json
import struct
import sys


def _compose(node):
	if "matrix" in node:
		m = node["matrix"]
		return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
	tx, ty, tz = node.get("translation", [0, 0, 0])
	x, y, z, w = node.get("rotation", [0, 0, 0, 1])
	sx, sy, sz = node.get("scale", [1, 1, 1])
	rot = [
		[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
		[2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
		[2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
	]
	out = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
	for i in range(3):
		for j, s in enumerate((sx, sy, sz)):
			out[i][j] = rot[i][j] * s
		out[i][3] = (tx, ty, tz)[i]
	return out


def _mul(a, b):
	return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def measure(path):
	blob = open(path, "rb").read()
	length, _kind = struct.unpack("<II", blob[12:20])
	gltf = json.loads(blob[20:20 + length].decode("utf-8"))
	nodes = gltf["nodes"]
	identity = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]
	world = {}

	def walk(index, parent):
		world[index] = _mul(parent, _compose(nodes[index]))
		for child in nodes[index].get("children", []):
			walk(child, world[index])

	for scene in gltf["scenes"]:
		for root in scene["nodes"]:
			walk(root, identity)

	joints = [j for skin in gltf.get("skins", []) for j in skin["joints"]]
	if not joints:
		raise SystemExit(f"{path}: no skin — the delivery is not rigged")
	# The silhouette, not the rig, is what you see: measure the skinned vertex
	# bounds. Paw pads sit below the lowest joint and ear tips above the highest.
	lows, highs = [], []
	for mesh in gltf.get("meshes", []):
		for prim in mesh["primitives"]:
			acc = gltf["accessors"][prim["attributes"]["POSITION"]]
			if "min" in acc:
				lows.append(acc["min"][1])
				highs.append(acc["max"][1])
	if not lows:
		raise SystemExit(f"{path}: no POSITION bounds in the accessors")
	return min(lows), max(highs), len(joints)


def main():
	if len(sys.argv) < 2:
		raise SystemExit(__doc__)
	path = sys.argv[1]
	target = float(sys.argv[2]) if len(sys.argv) > 2 else None
	low, high, count = measure(path)
	span = high - low
	print(f"{path}")
	print(f"  {count} joints, mesh y={low:.6f} .. {high:.6f}")
	print(f"  height, ears included = {span:.6f} glb units")
	if target:
		scale = target / span
		print(f"  nodes/root_scale = {scale:.1f}   for model_height = {target}")
		print(f"  feet will sit {low * scale:+.3f} m off the ground")


if __name__ == "__main__":
	main()
