//
//  AuthView.swift
//  ReadFolio
//
//  Created by Christian Lo Conte on 01/06/2026.
//


import SwiftUI

struct AuthView: View {
    @State private var showLogin = true

    var body: some View {
        VStack {
            if showLogin {
                LoginView(switchToSignUp: { showLogin = false })
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                SignUpView(switchToLogin: { showLogin = true })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showLogin)
    }
}