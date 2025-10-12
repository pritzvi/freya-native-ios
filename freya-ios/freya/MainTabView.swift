import SwiftUI

struct MainTabView: View {
    let uid: String
    let reportId: String
    let scoreId: String

    var body: some View {
        TabView {
            HomeView(uid: uid, reportId: reportId, scoreId: scoreId)
                .tabItem { Label("Home", systemImage: "house.fill") }

            Text("Products")
                .tabItem { Label("Products", systemImage: "bag.fill") }
            Text("Chat")
                .tabItem { Label("Chat", systemImage: "ellipsis.bubble.fill") }
            Text("Progress")
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}


