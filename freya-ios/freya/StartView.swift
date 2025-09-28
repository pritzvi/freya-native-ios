//
//  StartView.swift
//  freya
//
//  Created by Prithvi B on 9/27/25.
//

import SwiftUI

struct StartView: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text("freya")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fontDesign(.rounded)
            
            Spacer()
            
            NavigationLink(destination: QuickStartView()) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationView {
        StartView()
    }
}
