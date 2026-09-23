//
//  ShareSheet.swift
//  iFinance
//
//  系统分享组件封装
//

import SwiftUI
import UIKit

/// 系统分享 Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
