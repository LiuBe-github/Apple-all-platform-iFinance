//
//  DailySentenceViewModel.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/6.
//

import Combine
import Foundation

class DailySentenceViewModel: ObservableObject {
    @Published var sentence: DailySentence?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    func loadSentence() {
        isLoading = true
        errorMessage = nil
        
        let url = URL(string: "https://open.iciba.com/dsapi/")!
        
        URLSession.shared.dataTask(with: url) {data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "没有数据"
                    return
                }
                
                do {
                    let decoded = try JSONDecoder().decode(DailySentence.self, from: data)
                    self.sentence = decoded
                } catch {
                    self.errorMessage = "JSON解析失败：\(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
