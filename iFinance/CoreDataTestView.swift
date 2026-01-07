//
//  CoreDataTestView.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/21.
//

import SwiftUI
internal import CoreData

struct CoreDataTestView: View {
    @State var textInput: String
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("添加测试名称", text: $textInput)
                    .font(.headline)
                    .frame(height: 55)
                    .padding(.leading)
                    .background(Color(.init(gray: 0.96, alpha: 1)))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 30)
                
                Button {
                    addTest(text: textInput)
                } label: {
                    Text("保存")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(Color.pink.opacity(0.9))
                        .cornerRadius(10)
                        .padding()
                }
                
                List {
                }
            }
            .navigationTitle("测试")
        }
    }
    func addTest(text: String) {
        let newTest = TestEntity(context: viewContext)
        newTest.name = textInput
        
        do {
            try viewContext.save()
        } catch let error {
            print(error.localizedDescription)
        }
    }
}

#Preview {
    CoreDataTestView(textInput: "")
}
