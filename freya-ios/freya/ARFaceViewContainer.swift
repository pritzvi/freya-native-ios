
//
//  ARFaceWireframeView.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import ARKit
import SceneKit


// Example usage:
// struct ContentView: View {
//     @State private var captured: UIImage? = nil
//     var body: some View {
//         ZStack {
//             ARFaceViewContainer(capturedImage: $captured)
//                 .ignoresSafeArea()
//             if let img = captured {
//                 Image(uiImage: img)
//                     .resizable()
//                     .scaledToFit()
//                     .frame(width: 120)
//                     .padding()
//                     .background(.black.opacity(0.4))
//                     .cornerRadius(12)
//             }
//         }
//     }
// }

struct ARFaceViewContainer: UIViewRepresentable {
    @Binding var capturedImage: UIImage?

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.delegate = context.coordinator

        // ✅ Add a scene (robustness from code 2)
        v.scene = SCNScene()

        // ✅ Match code 1's stable lighting choice
        v.automaticallyUpdatesLighting = false

        // Configure AR face tracking
        guard ARFaceTrackingConfiguration.isSupported else { return v }
        let cfg = ARFaceTrackingConfiguration()
        // Disable light estimation to keep appearance stable (like code 1)
        cfg.isLightEstimationEnabled = false

        v.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.view = v
        context.coordinator.parent = self
        return v
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator
    final class Coordinator: NSObject, ARSCNViewDelegate {
        fileprivate weak var view: ARSCNView?
        fileprivate var parent: ARFaceViewContainer?
        private var remesh: Remesher?
        private let node = SCNNode()
        private var didAutoCapture = false

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            // Draw the wireframe last so it’s visible
            node.renderingOrder = 1000
            return node
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let fa = anchor as? ARFaceAnchor else { return }

            if remesh == nil {
                remesh = Remesher(
                    faceGeo: fa.geometry,
                    targetSampleCount: 260,
                    poissonRadius: 0.0,
                    addVertexDots: true
                )
                guard let remesh else { return }
                let g = remesh.makeGeometry(from: fa.geometry)

                // Bright, always-on-top material for lines (from code 2)
                let m = SCNMaterial()
                m.lightingModel = .constant
                m.emission.contents = UIColor.white
                m.diffuse.contents = UIColor.white
                m.isDoubleSided = true
                m.writesToDepthBuffer = false
                m.readsFromDepthBuffer = false
                m.transparency = 0.88
                g.firstMaterial = m

                self.node.geometry = g

                if let dots = remesh.makeVertexDotNode() {
                    dots.renderingOrder = 1001  // dots over lines
                    self.node.addChildNode(dots)
                }

                // ✅ EXTRA from code 1: capturedImage plumbing — auto-capture once
                if !didAutoCapture {
                    didAutoCapture = true
                    captureFrame()
                }
                return
            }

            // Update vertices each frame (dot positions are also updated inside)
            if let g = remesh?.updateGeometryVertices(geometry: node.geometry, with: fa.geometry) {
                node.geometry = g
            }
        }

        // Public helper you can call from SwiftUI via other triggers
        func captureFrame() {
            guard let v = view else { return }
            // Use ARSCNView's snapshot (includes camera background composited with SceneKit content)
            let img = v.snapshot()
            parent?.capturedImage = img
        }
    }
}

// MARK: - Remesher
final class Remesher {
    private(set) var keepIdx: [Int] = []
    private var keptUV: [SIMD2<Float>] = []
    private var keptPos: [SIMD3<Float>] = []
    private var edges: [(Int16, Int16)] = []
    private let addVertexDots: Bool

    // billboard dots
    private var dotsNode: SCNNode?

    private let targetSampleCount: Int
    private let poissonRadius: Float

    init(faceGeo: ARFaceGeometry, targetSampleCount: Int, poissonRadius: Float, addVertexDots: Bool) {
        self.targetSampleCount = targetSampleCount
        self.poissonRadius = poissonRadius
        self.addVertexDots = addVertexDots
        build(from: faceGeo)
    }

    func makeGeometry(from fg: ARFaceGeometry) -> SCNGeometry {
        keptPos = keepIdx.map { fg.vertices[$0] }
        let vSource = SCNGeometrySource(vertices: keptPos.map(SCNVector3.init))

        // Safer Data construction (no deprecated init)
        var flat: [Int16] = []
        flat.reserveCapacity(edges.count * 2)
        for (a, b) in edges { flat.append(a); flat.append(b) }
        let idxData = flat.withUnsafeBytes { Data($0) }

        let element = SCNGeometryElement(
            data: idxData,
            primitiveType: .line,
            primitiveCount: edges.count,
            bytesPerIndex: MemoryLayout<Int16>.size
        )
        return SCNGeometry(sources: [vSource], elements: [element])
    }

    /// ✅ EXTRA from code 1: also updates the billboard dot positions internally.
    func updateGeometryVertices(geometry: SCNGeometry?, with fg: ARFaceGeometry) -> SCNGeometry? {
        guard let geometry = geometry else { return nil }
        keptPos = keepIdx.map { fg.vertices[$0] }
        let vSource = SCNGeometrySource(vertices: keptPos.map(SCNVector3.init))
        let elem = geometry.elements.first!
        let newGeom = SCNGeometry(sources: [vSource], elements: [elem])
        newGeom.firstMaterial = geometry.firstMaterial

        // Keep dots in sync automatically (like code 1)
        if let dots = dotsNode {
            updateVertexDotPositions(dotNode: dots, vertices: keptPos)
        }
        return newGeom
    }

    // Optional bright nodes at vertices (billboarded quads)
    func makeVertexDotNode() -> SCNNode? {
        guard addVertexDots else { return nil }
        let parent = SCNNode()
        let dotSize: CGFloat = 0.0022

        // Make dots always visible (match line material hints)
        let mat = SCNMaterial()
        mat.emission.contents = UIColor.white
        mat.diffuse.contents = UIColor.white
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = false
        mat.transparency = 0.88

        for _ in keepIdx {
            let plane = SCNPlane(width: dotSize, height: dotSize)
            plane.cornerRadius = dotSize * 0.5
            plane.firstMaterial = mat
            let n = SCNNode(geometry: plane)
            n.constraints = [SCNBillboardConstraint()] // always faces camera
            parent.addChildNode(n)
        }
        self.dotsNode = parent

        // Initialize positions immediately if we already have keptPos
        if !keptPos.isEmpty {
            updateVertexDotPositions(dotNode: parent, vertices: keptPos)
        }
        return parent
    }

    private func updateVertexDotPositions(dotNode: SCNNode, vertices: [SIMD3<Float>]) {
        let childNodes = dotNode.childNodes
        for (i, p) in vertices.enumerated() where i < childNodes.count {
            childNodes[i].position = SCNVector3(p)
        }
    }

    // MARK: Build stage
    private func build(from fg: ARFaceGeometry) {
        let uvs: [SIMD2<Float>] = fg.textureCoordinates.map { SIMD2<Float>($0.x, $0.y) }

        func foreheadMask(_ uv: SIMD2<Float>) -> Float {
            let t = smoothstep(0.78, 0.82, uv.y)
            return clamp(t, 0, 1)
        }

        var idxForehead: [Int] = []
        var idxRest: [Int] = []
        for i in uvs.indices {
            if foreheadMask(uvs[i]) > 0.5 { idxForehead.append(i) } else { idxRest.append(i) }
        }

        // Proportional allocation with forehead sparsity
        let n = uvs.count
        let ph = Float(idxForehead.count) / Float(max(1, n))
        let kTotal = max(8, targetSampleCount)

        let kF_prop = Float(kTotal) * ph
        let kF = max(4, Int(round(0.5 * kF_prop))) // 50% sparser on forehead
        let kR = max(8, kTotal - kF)

        let kF_clamped = min(kF, idxForehead.count)
        let kR_clamped = min(kR, idxRest.count)
        let kFixup = (kF - kF_clamped) + (kR - kR_clamped)
        let kF_final = kF_clamped
        let kR_final = min(kR_clamped + kFixup, idxRest.count)

        let keepF = kmeansSubsampleSubset(uvs: uvs, subset: idxForehead, k: kF_final, maxIters: 6)
        let keepR = kmeansSubsampleSubset(uvs: uvs, subset: idxRest,     k: kR_final, maxIters: 6)
        self.keepIdx = keepF + keepR
        self.keptUV  = self.keepIdx.map { uvs[$0] }

        // Triangulate merged UVs → unique edges
        let tris = delaunay(points: keptUV)
        var eset = Set<Int64>(); eset.reserveCapacity(tris.count * 3)
        func key(_ a: Int, _ b: Int) -> Int64 {
            let lo = Int16(min(a, b)), hi = Int16(max(a, b))
            return (Int64(hi) << 16) | Int64(Int32(lo) & 0xFFFF)
        }
        for (a,b,c) in tris {
            _ = eset.insert(key(a,b))
            _ = eset.insert(key(b,c))
            _ = eset.insert(key(c,a))
        }
        self.edges = eset.map {
            let lo = Int(Int16(truncatingIfNeeded: $0 & 0xFFFF))
            let hi = Int(Int16(truncatingIfNeeded: ($0 >> 16) & 0xFFFF))
            return (Int16(hi), Int16(lo))
        }
    }

    private func kmeansSubsampleSubset(uvs: [SIMD2<Float>], subset: [Int], k: Int, maxIters: Int) -> [Int] {
        if k <= 0 || subset.isEmpty { return [] }
        if k >= subset.count { return subset }

        let pts: [SIMD2<Float>] = subset.map { uvs[$0] }

        // bbox of subset
        var minU: SIMD2<Float> = SIMD2<Float>(1,1)
        var maxU: SIMD2<Float> = SIMD2<Float>(0,0)
        for p in pts { minU = min(minU, p); maxU = max(maxU, p) }

        // jittered grid seeds
        let grid = Int(ceil(sqrt(Double(k))))
        var seeds: [SIMD2<Float>] = []; seeds.reserveCapacity(k)
        for gy in 0..<grid {
            for gx in 0..<grid where seeds.count < k {
                let fx = (Float(gx) + 0.5) / Float(grid)
                let fy = (Float(gy) + 0.5) / Float(grid)
                let s = mix(minU, maxU, t: SIMD2<Float>(fx, fy))
                seeds.append(s)
            }
        }

        var centroids = seeds
        let m = pts.count
        var assign = Array(repeating: 0, count: m)
        for _ in 0..<maxIters {
            for i in 0..<m {
                var best = 0; var bd = Float.greatestFiniteMagnitude
                let p = pts[i]
                for (j, c) in centroids.enumerated() {
                    let d = simd_length_squared(p - c)
                    if d < bd { bd = d; best = j }
                }
                assign[i] = best
            }
            var sum = Array(repeating: SIMD2<Float>(0,0), count: k)
            var cnt = Array(repeating: 0, count: k)
            for i in 0..<m {
                let a = assign[i]; sum[a] += pts[i]; cnt[a] += 1
            }
            for j in 0..<k where cnt[j] > 0 {
                centroids[j] = sum[j] / Float(cnt[j])
            }
        }

        // snap to distinct originals
        var picked = Set<Int>()
        var out: [Int] = []; out.reserveCapacity(k)
        for j in 0..<k {
            let c = centroids[j]
            var bestIdxLocal = 0; var bd = Float.greatestFiniteMagnitude
            for i in 0..<m where !picked.contains(i) {
                let d = simd_length_squared(pts[i] - c)
                if d < bd { bd = d; bestIdxLocal = i }
            }
            picked.insert(bestIdxLocal)
            out.append(subset[bestIdxLocal])
        }
        return out
    }

    // small utility
    @inline(__always) private func mix(_ a: SIMD2<Float>, _ b: SIMD2<Float>, t: SIMD2<Float>) -> SIMD2<Float> {
        return a + (b - a) * t
    }

    // Minimal Delaunay (Bowyer–Watson) over 2D points
    private struct Tri { var a:Int; var b:Int; var c:Int; var cc: SIMD3<Float> }
    private struct Edge: Hashable { let u:Int; let v:Int
        init(_ i:Int,_ j:Int){ if i<j {u=i;v=j} else {u=j;v=i} } }

    private func delaunay(points: [SIMD2<Float>]) -> [(Int,Int,Int)] {
        guard points.count >= 3 else { return [] }
        let pA = SIMD2<Float>(-10, -10)
        let pB = SIMD2<Float>( 10, -10)
        let pC = SIMD2<Float>( 0,  10)

        var pts = points
        let A = pts.count; pts.append(pA)
        let B = pts.count; pts.append(pB)
        let C = pts.count; pts.append(pC)

        func circ(_ p: SIMD2<Float>, _ q: SIMD2<Float>, _ r: SIMD2<Float>) -> SIMD3<Float> {
            let ax=p.x, ay=p.y, bx=q.x, by=q.y, cx=r.x, cy=r.y
            let d = 2 * (ax*(by-cy) + bx*(cy-ay) + cx*(ay-by))
            if abs(d) < 1e-6 { return SIMD3<Float>(0,0,Float.greatestFiniteMagnitude) }
            let ux = ((ax*ax+ay*ay)*(by-cy) + (bx*bx+by*by)*(cy-ay) + (cx*cx+cy*cy)*(ay-by))/d
            let uy = ((ax*ax+ay*ay)*(cx-bx) + (bx*bx+by*by)*(ax-cx) + (cx*cx+cy*cy)*(bx-ax))/d
            let r2 = (ux-ax)*(ux-ax) + (uy-ay)*(uy-ay)
            return SIMD3<Float>(ux, uy, sqrt(max(0, r2)))
        }
        func contains(_ cc: SIMD3<Float>, _ p: SIMD2<Float>) -> Bool {
            distance(SIMD2<Float>(cc.x, cc.y), p) <= cc.z
        }

        var triangles: [Tri] = [Tri(a:A,b:B,c:C,cc:circ(pts[A],pts[B],pts[C]))]

        for i in 0..<points.count {
            var bad: [Int] = []
            for (tidx,t) in triangles.enumerated() {
                if contains(t.cc, pts[i]) { bad.append(tidx) }
            }
            var poly = [Edge:Int]()
            for tidx in bad.sorted(by: >) {
                let t = triangles.remove(at: tidx)
                let e = [Edge(t.a,t.b), Edge(t.b,t.c), Edge(t.c,t.a)]
                for ed in e { poly[ed, default: 0] ^= 1 }
            }
            for (ed, cnt) in poly where cnt == 1 {
                let a = ed.u, b = ed.v, c = i
                triangles.append(Tri(a:a,b:b,c:c,cc:circ(pts[a],pts[b],pts[c])))
            }
        }
        triangles.removeAll { $0.a >= points.count || $0.b >= points.count || $0.c >= points.count }
        return triangles.map { ($0.a,$0.b,$0.c) }
    }
}

// MARK: - tiny helpers
@inline(__always) private func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = clamp((x - e0) / max(1e-6, e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
}
@inline(__always) private func clamp<T: Comparable>(_ v: T, _ a: T, _ b: T) -> T { max(a, min(b, v)) }
