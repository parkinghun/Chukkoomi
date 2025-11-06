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
                        let a = try await NetworkManager.shared.performRequest(UserRouter.validateEmail("kyh"), as: BasicMessageDTO.self)
                        print(a.message)
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .padding()
    }
    
    struct BasicMessageDTO: Decodable {
        let message: String
    }
}

#Preview {
    NetworkTestView()
}
