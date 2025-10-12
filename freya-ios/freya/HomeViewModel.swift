import Foundation
import Combine
import FirebaseFirestore

final class HomeViewModel: ObservableObject {
    @Published var score: SkinScore?
    @Published var sections: [RoutineSection] = []
    @Published var completedStepIds: Set<String> = []
    @Published var recentScores: [ScoreListItem] = []
    @Published var selectedScoreId: String?

    private var listeners: [ListenerRegistration] = []

    func start(uid: String, reportId: String, scoreId: String) {
        stop()

        // Score: latest list + selected detail
        let scoresCol = Firestore.firestore()
            .collection("skinScores").document(uid)
            .collection("items")

        // Listen to latest 7 for chips
        listeners.append(
            scoresCol.order(by: "createdAt", descending: true).limit(to: 7)
                .addSnapshotListener { [weak self] snap, _ in
                    guard let docs = snap?.documents else { return }
                    let items: [ScoreListItem] = docs.map { d in
                        let data = d.data()
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                        let overall = data["skin_score_total_0_100"] as? Int ?? 0
                        let subs = data["subscores"] as? [String: Any] ?? [:]
                        let s = Subscores(
                            barrierHydration: subs["barrierHydration"] as? Int ?? 0,
                            complexion: subs["complexion"] as? Int ?? 0,
                            acneTexture: subs["acneTexture"] as? Int ?? 0,
                            fineLines: subs["fineLines"] as? Int ?? 0,
                            eyes: subs["eyes"] as? Int ?? 0
                        )
                        return ScoreListItem(id: d.documentID, overall: overall, createdAt: createdAt, subscores: s)
                    }
                    self?.recentScores = items
                    if self?.selectedScoreId == nil {
                        self?.selectedScoreId = items.first?.id
                    }
                    self?.updateSelectedScore()
                }
        )

        // Also watch the provided scoreId doc directly for initial load
        listeners.append(
            scoresCol.document(scoreId).addSnapshotListener { [weak self] snap, _ in
                guard let data = snap?.data() else { return }
                self?.score = Self.parseScore(data)
            }
        )

        // Routine: skinReports/{uid}/items/{reportId}.reportData.initial_routine
        let reportRef = Firestore.firestore()
            .collection("skinReports").document(uid)
            .collection("items").document(reportId)

        listeners.append(reportRef.addSnapshotListener { [weak self] snap, _ in
            guard let data = snap?.data(),
                  let reportData = data["reportData"] as? [String: Any],
                  let initial = reportData["initial_routine"] as? [String: Any] else { return }
            self?.sections = Self.parseRoutine(initial)
        })
    }

    func stop() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    func toggle(stepId: String) {
        if completedStepIds.contains(stepId) {
            completedStepIds.remove(stepId)
        } else {
            completedStepIds.insert(stepId)
        }
    }

    func selectScore(id: String) {
        selectedScoreId = id
        updateSelectedScore()
    }

    private func updateSelectedScore() {
        guard let id = selectedScoreId, let item = recentScores.first(where: { $0.id == id }) else { return }
        score = SkinScore(overall: item.overall, subscores: item.subscores, createdAt: item.createdAt)
    }

    private static func parseScore(_ data: [String: Any]) -> SkinScore {
        let overall = data["skin_score_total_0_100"] as? Int ?? 0
        let subs = data["subscores"] as? [String: Any] ?? [:]
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()

        let s = Subscores(
            barrierHydration: subs["barrierHydration"] as? Int ?? 0,
            complexion: subs["complexion"] as? Int ?? 0,
            acneTexture: subs["acneTexture"] as? Int ?? 0,
            fineLines: subs["fineLines"] as? Int ?? 0,
            eyes: subs["eyes"] as? Int ?? 0
        )
        return SkinScore(overall: overall, subscores: s, createdAt: createdAt)
    }

    private static func parseRoutine(_ initial: [String: Any]) -> [RoutineSection] {
        func steps(from arr: [[String: Any]], section: String) -> [RoutineStep] {
            arr.compactMap { dict in
                let id = (dict["stepId"] ?? dict["slotId"]) as? String ?? UUID().uuidString
                let stepName = (dict["slotType"] as? String) ?? (dict["stepName"] as? String) ?? "Step"
                let productRef = dict["productRef"] as? [String: Any]
                let productName = productRef?["name"] as? String
                let brand = productRef?["brand"] as? String
                let img = (dict["imageUrl"] as? String) ?? (productRef?["imageUrl"] as? String)
                return RoutineStep(
                    id: id,
                    section: section,
                    stepName: stepName.capitalized,
                    productName: productName,
                    brand: brand,
                    imageUrl: img.flatMap(URL.init)
                )
            }
        }

        let am = (initial["AM"] as? [[String: Any]] ?? [])
        let pm = (initial["PM"] as? [[String: Any]] ?? [])

        return [
            RoutineSection(id: "AM", title: "AM Routine", steps: steps(from: am, section: "AM")),
            RoutineSection(id: "PM", title: "PM Routine", steps: steps(from: pm, section: "PM"))
        ].filter { !$0.steps.isEmpty }
    }
}


