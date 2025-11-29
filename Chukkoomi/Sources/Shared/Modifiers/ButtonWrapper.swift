//
//  ButtonWrapper.swift
//  CustomModifier
//
//  Created by Jimin on 11/4/25.
//

import SwiftUI

private struct ButtonWrapper: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        Button(action: action) {
            content
        }
    }
}

extension View {
    func buttonWrapper(action: @escaping () -> Void) -> some View {
        modifier(ButtonWrapper(action: action))
    }
}
