//
//  LogView.swift
//  Chukkoomi
//
//  Created by 서지민 on 11/7/25.
//

import SwiftUI
import ComposableArchitecture

struct LogView: View {

    let store: StoreOf<LogFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                // 현재 저장된 토큰 표시
                VStack(alignment: .leading, spacing: 8) {
                    Text("저장된 토큰")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    if let accessToken = KeychainManager.shared.load(for: .accessToken) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AccessToken:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(accessToken.prefix(40) + "...")
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("AccessToken: 없음")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    if let refreshToken = KeychainManager.shared.load(for: .refreshToken) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RefreshToken:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(refreshToken.prefix(40) + "...")
                                .font(.caption2)
                                .fontDesign(.monospaced)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    } else {
                        Text("RefreshToken: 없음")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 8)
                .background(Color.gray.opacity(0.1))

                Divider()

                // 새로고침 버튼
                Button {
                    viewStore.send(.fetchLogsButtonTapped)
                } label: {
                    if viewStore.isLoading {
                        ProgressView()
                    } else {
                        Label("로그 새로고침", systemImage: "arrow.clockwise")
                    }
                }
                .padding()

                // 에러 메시지
                if let errorMessage = viewStore.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                // 로그 리스트
                if viewStore.logs.isEmpty {
                    Spacer()
                    Text("로그가 없습니다.\n새로고침 버튼을 눌러주세요.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                } else {
                    List(viewStore.logs.indices, id: \.self) { index in
                        let log = viewStore.logs[index]
                        VStack(alignment: .leading, spacing: 8) {
                            // 메서드와 경로
                            HStack {
                                Text(log.method)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(methodColor(log.method))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)

                                Text(log.routePath)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            // 상태 코드
                            HStack {
                                Text("상태:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Text(log.statusCode)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor(log.statusCode))
                            }

                            // 시간
                            Text(log.date)
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            // Body
                            if !log.body.isEmpty && log.body != "{}" {
                                Text("Body: \(log.body)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("서버 로그")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewStore.send(.fetchLogsButtonTapped)
            }
        }
    }

    // MARK: - Helper Methods
    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": return .blue
        case "POST": return .green
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .gray
        }
    }

    private func statusColor(_ statusCode: String) -> Color {
        guard let code = Int(statusCode) else { return .gray }
        switch code {
        case 200..<300: return .green
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .gray
        }
    }
}
