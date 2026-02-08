//
//  HomeView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import SwiftUI
import NukeUI

struct HomeView: View {
    @StateObject private var viewModel = DailySentenceViewModel()
    
    // MARK: - State for share sheet
    @State private var isShareSheetPresented = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationStack {
            if let s = viewModel.sentence {
                ZStack {
                    VStack(spacing: 20) {
                        LazyImage(url: URL(string: s.picture2)) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .aspectRatio(contentMode: .fill) // 关键：填充模式
                            } else if state.error != nil {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                ProgressView()
                            }
                        }
                        .frame(width: 360, height: 480)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        
                        Button {
                            // 缺失函数，分享（已完成）
                            prepareShareContent(sentence: s)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    
                    VStack(spacing: 20) {
                        Text(s.content)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        
                        Text(s.note)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    }
                }
                .navigationTitle("一言")
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        HeaderView(isTransactionView: false)
                    }
                }
                .navigationBarBackButtonHidden(true)
                .sheet(isPresented: $isShareSheetPresented) {
                    ActivityViewController(activityItems: shareItems, applicationActivities: nil)
                }
            } else if viewModel.isLoading {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel.sentence == nil && !viewModel.isLoading {
                viewModel.loadSentence()
            }
        }
    }
    
    // MARK: - 分享内容准备
    private func prepareShareContent(sentence: DailySentence) {
        var items: [Any] = []
        
        // 1. 添加文字内容
        let text = "\(sentence.content)\n— \(sentence.note)"
        items.append(text)
        
        // 2. 如果有图片 URL，也尝试添加（可选）
        if let imageUrl = URL(string: sentence.picture2) {
            // 注意：ShareSheet 通常不直接支持远程 URL，但可以传入 URL 本身作为链接
            items.append(imageUrl)
        }
        
        shareItems = items
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
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

// MARK: - 预览支持（如果 DailySentenceViewModel 支持）
#Preview {
    HomeView()
}
