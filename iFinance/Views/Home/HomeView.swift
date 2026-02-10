//
//  HomeView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI

struct HomeView: View {
    @State private var sentences: [DailySentence] = []
    @State private var currentSentence: DailySentence?
    @State private var isLoading = true
    
    // MARK: - State for share sheet
    @State private var isShareSheetPresented = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    // 全屏加载指示器（居中）
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let s = currentSentence {
                    // 主内容（带圆角）
                    VStack(spacing: 20) {
                        // 图片容器（确保圆角生效）
                        ZStack {
                            // 背景图片
                            if let url = URL(string: s.picture2) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        Color.gray.opacity(0.3)
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .failure:
                                        Color.gray.opacity(0.3)
                                    @unknown default:
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 360, height: 480)
                            } else {
                                Color.gray.opacity(0.3)
                                    .frame(width: 360, height: 480)
                            }
                            
                            // 文字遮罩层
                            VStack {
                                Spacer()
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 140)
                            }
                            .frame(width: 360, height: 480)
                            
                            // 文字内容
                            VStack {
                                Spacer()
                                // 名言左对齐，作者右对齐
                                Text(s.content)
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Text(s.note)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 360, height: 480)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 32)) // 【关键】圆角应用在此
                        
                        // 操作按钮
                        HStack(spacing: 52) {
                            Button {
                                Task {
                                    await refreshSentenceAsync()
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.headline)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(radius: 4)
                            }
                            
                            Button {
                                prepareShareContent(sentence: s)
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.headline)
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .shadow(radius: 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }
            .navigationTitle("一言")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderView(isTransactionView: false)
                }
            }
            .sheet(isPresented: $isShareSheetPresented) {
                ActivityViewController(activityItems: shareItems, applicationActivities: nil)
            }
            .onAppear {
                loadSentencesFromJSON()
            }
        }
    }
    
    private func loadSentencesFromJSON() {
        isLoading = true
        guard let url = Bundle.main.url(forResource: "EconomicQuotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let quotes = try? JSONDecoder().decode([DailySentence].self, from: data) else {
            print("❌ 无法加载 EconomicQuotes.json")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        sentences = quotes
        selectRandomSentence()
        isLoading = false
    }
    
    // 【关键】异步刷新方法：显示加载状态
    private func refreshSentenceAsync() async {
        isLoading = true
        // 模拟微小延迟（实际可省略，但提升 UX 感知）
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒
        selectRandomSentence()
        isLoading = false
    }
    
    private func selectRandomSentence() {
        guard !sentences.isEmpty else { return }
        currentSentence = sentences.randomElement()
    }
    
    // MARK: - 分享内容准备
    private func prepareShareContent(sentence: DailySentence) {
        let text = "\(sentence.content)\n— \(sentence.note)"
        shareItems = [text]
        if let url = URL(string: sentence.picture2) {
            shareItems.append(url)
        }
        isShareSheetPresented = true
    }
}

// MARK: - ActivityViewController 封装（用于 SwiftUI）
struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 预览支持
#Preview {
    HomeView()
}
