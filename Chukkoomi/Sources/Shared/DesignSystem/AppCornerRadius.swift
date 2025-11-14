//
//  AppCornerRadius.swift
//  Chukkoomi
//
//  Created by 김영훈 on 11/4/25.
//

import SwiftUI

enum AppCornerRadius {
    static let value: CGFloat = 10
}

extension View {
    /// ex)  Text("").customRadius()
    func customRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.value))
    }
}
