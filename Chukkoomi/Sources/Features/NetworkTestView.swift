//
//  NetworkTestView.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/6/25.
//

import SwiftUI

struct NetworkTestView: View {
    var body: some View {
        VStack {
            Button("Test") {
                Task {
                    do {
                        let a = try await NetworkManager.shared.performRequest(UserRouter.signUp(email: "kyh", password: "kyh", nickname: "kyh"), as: SignResponseDTO.self)
                        print(a)
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    NetworkTestView()
}
