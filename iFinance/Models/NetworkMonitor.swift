//
//  NetworkMonitor.swift
//  iFinance
//
//  Created by 刘不易 on 2026/2/8.
//

import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    let monitor = NWPathMonitor()
    private var monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var isExpensive = false // 是否为蜂窝等高成本网络
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isConstrained || path.isExpensive
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    deinit {
        monitor.cancel()
    }
}
