//
//  ARFaceViewContainer.swift
//  freya
//
//  Created by Prithvi B on 1/4/25.
//

import SwiftUI
import ARKit
import SceneKit
import CoreImage
import UIKit
import Combine


/// Controller that lets SwiftUI trigger overlay visibility and clean-frame capture.
final class ARFaceController: ObservableObject {
    fileprivate var _setVisible: ((Bool) -> Void)?
    fileprivate var _captureClean: ((_ hideOverlay: Bool, _ hideDelay: TimeInterval, _ completion: @escaping (UIImage?) -> Void) -> Void)?

    func setOverlayVisible(_ visible: Bool) {
        _setVisible?(visible)
    }

    /// Captures a pure camera frame (no SceneKit overlays). For UX, you can hide the overlay briefly.
    func captureCleanFrame(hideOverlayDuringCapture: Bool = true,
                           hideDelay: TimeInterval = 0.05,
                           completion: @escaping (UIImage?) -> Void) {
        _captureClean?(hideOverlayDuringCapture, hideDelay, completion)
    }
}

struct ARFaceViewContainer: UIViewRepresentable {
    @Binding var capturedImage: UIImage?
    var controller: ARFaceController

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARSCNView {
        let v = ARSCNView(frame: .zero)
        v.delegate = context.coordinator
        v.scene = SCNScene()
        v.automaticallyUpdatesLighting = false

        guard ARFaceTrackingConfiguration.isSupported else { return v }
        let cfg = ARFaceTrackingConfiguration()
        cfg.isLightEstimationEnabled = false
        v.session.run(cfg, options: [.resetTracking, .removeExistingAnchors])

        context.coordinator.view = v
        context.coordinator.parent = self

        // Wire controller hooks
        controller._setVisible = { [weak coord = context.coordinator] visible in
            coord?.setOverlayVisible(visible)
        }
        controller._captureClean = { [weak coord = context.coordinator] hide, delay, completion in
            coord?.captureCleanFrame(hideOverlayDuringCapture: hide, hideDelay: delay, completion: completion)
        }

        return v
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    // MARK: - Coordinator
    final class Coordinator: NSObject, ARSCNViewDelegate {
        fileprivate weak var view: ARSCNView?
        fileprivate var parent: ARFaceViewContainer?
        private var remesh: Remesher?
        private let overlayNode = SCNNode()  // container for lines + dots
        private var didAutoCapture = false
        private let ciContext = CIContext(options: nil) // reuse for performance

        // MARK: Overlay visibility
        func setOverlayVisible(_ visible: Bool) {
            overlayNode.isHidden = !visible  // Hides node + all children. (Apple docs) :contentReference[oaicite:5]{index=5}
        }

        // MARK: Capture a clean camera frame
        func captureCleanFrame(hideOverlayDuringCapture: Bool,
                               hideDelay: TimeInterval,
                               completion: @escaping (UIImage?) -> Void) {
            // UX: briefly hide overlay before capture (not required for purity, but requested)
            if hideOverlayDuringCapture { setOverlayVisible(false) }

            // Small delay so the user sees the mesh disappear before we capture
            DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay) { [weak self] in
                guard let self, let v = self.view,
                      let frame = v.session.currentFrame else { // Access current frame (Apple docs) :contentReference[oaicite:6]{index=6}
                    if hideOverlayDuringCapture { self?.setOverlayVisible(true) }
                    completion(nil)
                    return
                }

                let pb = frame.capturedImage // Raw camera buffer (YCbCr). (Apple docs) :contentReference[oaicite:7]{index=7}
                let uiImage = self.pixelBufferToUIImage(pb, mirrorHorizontally: true) // TrueDepth/front → mirror for selfie feel

                if hideOverlayDuringCapture { self.setOverlayVisible(true) }
                completion(uiImage)
            }
        }

        // MARK: ARSCNViewDelegate
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            // Draw wireframe last so it’s visible
            overlayNode.renderingOrder = 1000
            return overlayNode
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

                let m = SCNMaterial()
                m.lightingModel = .constant
                m.emission.contents = UIColor.white
                m.diffuse.contents = UIColor.white
                m.isDoubleSided = true
                m.writesToDepthBuffer = false
                m.readsFromDepthBuffer = false
                m.transparency = 0.88
                g.firstMaterial = m

                overlayNode.geometry = g

                if let dots = remesh.makeVertexDotNode() {
                    dots.renderingOrder = 1001
                    overlayNode.addChildNode(dots)
                }

                if !didAutoCapture {
                    didAutoCapture = true
                    // No auto-capture here anymore; user explicitly taps capture.
                }
                return
            }

            if let g = remesh?.updateGeometryVertices(geometry: overlayNode.geometry, with: fa.geometry) {
                overlayNode.geometry = g
            }
        }

        // MARK: CVPixelBuffer -> UIImage
        /// Converts ARKit camera buffer to an upright UIImage for the current interface orientation.
        /// Front camera → mirrored variants.
        private func pixelBufferToUIImage(_ pb: CVPixelBuffer, mirrorHorizontally: Bool) -> UIImage? {
            var ci = CIImage(cvPixelBuffer: pb) // raw camera image (unoriented). Apple: capturedImage is raw.
            // Get the current interface orientation from the ARSCNView's window scene.
            let interfaceOrientation: UIInterfaceOrientation = {
                if let io = view?.window?.windowScene?.interfaceOrientation { return io }
                // Sensible default if unknown
                return .portrait
            }()

            // Map UIInterfaceOrientation → CGImagePropertyOrientation (front camera = mirrored)
            // Portrait phone + front camera typically needs .leftMirrored to be "selfie upright".
            let cgOrient: CGImagePropertyOrientation = {
                switch interfaceOrientation {
                case .portrait:            return mirrorHorizontally ? .leftMirrored  : .right
                case .portraitUpsideDown:  return mirrorHorizontally ? .rightMirrored : .left
                case .landscapeLeft:       return mirrorHorizontally ? .downMirrored  : .up
                case .landscapeRight:      return mirrorHorizontally ? .upMirrored    : .down
                default:                   return mirrorHorizontally ? .leftMirrored  : .right
                }
            }()

            // Rotate/orient the CIImage to match how the UI will display it.
            ci = ci.oriented(cgOrient) // Core Image applies the orientation transform.
            // Apple: CIImage.oriented(_:) rotates/flips to the given CGImagePropertyOrientation.
            // https://developer.apple.com/documentation/coreimage/ciimage/oriented(_:)

            // Render to CGImage then wrap in UIImage. UIImage orientation can be .up now.
            let rect = ci.extent
            guard let cg = ciContext.createCGImage(ci, from: rect) else { return nil }
            return UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)
        }

    }
}

// === Remesher (unchanged) ===

final class Remesher {
    private(set) var keepIdx: [Int] = []
    private var keptUV: [SIMD2<Float>] = []
    private var keptPos: [SIMD3<Float>] = []
    private var edges: [(Int16, Int16)] = []
    private let addVertexDots: Bool
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
        var flat: [Int16] = []; flat.reserveCapacity(edges.count * 2)
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

    func updateGeometryVertices(geometry: SCNGeometry?, with fg: ARFaceGeometry) -> SCNGeometry? {
        guard let geometry = geometry else { return nil }
        keptPos = keepIdx.map { fg.vertices[$0] }
        let vSource = SCNGeometrySource(vertices: keptPos.map(SCNVector3.init))
        let elem = geometry.elements.first!
        let newGeom = SCNGeometry(sources: [vSource], elements: [elem])
        newGeom.firstMaterial = geometry.firstMaterial

        if let dots = dotsNode {
            updateVertexDotPositions(dotNode: dots, vertices: keptPos)
        }
        return newGeom
    }

    func makeVertexDotNode() -> SCNNode? {
        guard addVertexDots else { return nil }
        let parent = SCNNode()
        let dotSize: CGFloat = 0.0022

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
            n.constraints = [SCNBillboardConstraint()]
            parent.addChildNode(n)
        }
        self.dotsNode = parent

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

    private func build(from fg: ARFaceGeometry) {
        let uvs: [SIMD2<Float>] = fg.textureCoordinates.map { SIMD2<Float>($0.x, $0.y) }

        func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
            let t = max(0, min(1, (x - e0) / max(1e-6, e1 - e0)))
            return t * t * (3 - 2 * t)
        }
        func foreheadMask(_ uv: SIMD2<Float>) -> Float {
            let t = smoothstep(0.78, 0.82, uv.y)
            return max(0, min(1, t))
        }

        var idxForehead: [Int] = []
        var idxRest: [Int] = []
        for i in uvs.indices {
            if foreheadMask(uvs[i]) > 0.5 { idxForehead.append(i) } else { idxRest.append(i) }
        }

        let n = uvs.count
        let ph = Float(idxForehead.count) / Float(max(1, n))
        let kTotal = max(8, 260)

        let kF_prop = Float(kTotal) * ph
        let kF = max(4, Int(round(0.5 * kF_prop)))
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

        var minU: SIMD2<Float> = SIMD2<Float>(1,1)
        var maxU: SIMD2<Float> = SIMD2<Float>(0,0)
        for p in pts { minU = min(minU, p); maxU = max(maxU, p) }

        let grid = Int(ceil(sqrt(Double(k))))
        var seeds: [SIMD2<Float>] = []; seeds.reserveCapacity(k)
        for gy in 0..<grid {
            for gx in 0..<grid where seeds.count < k {
                let fx = (Float(gx) + 0.5) / Float(grid)
                let fy = (Float(gy) + 0.5) / Float(grid)
                let s = SIMD2<Float>(minU.x + (maxU.x - minU.x)*fx, minU.y + (maxU.y - minU.y)*fy)
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
