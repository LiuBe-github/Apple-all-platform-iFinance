//
//  AppBackgroundClock.swift
//  iFinance
//
//  全局共享的背景动画时钟：以 10fps 发布时间，App 非活跃时自动暂停。
//  目的：多个页面（Tab 之间会同时存活）共用同一份计时，避免每个页面各跑一份动画。
//  说明：本文件是 iOS 主版与 SwiftData 版的同名副本，改一处请同步另一处。
//

import Foundation
import Combine
import UIKit

@MainActor
final class AppBackgroundClock: ObservableObject {
    static let shared = AppBackgroundClock()

    /// 10fps：光斑漂移速度很慢，10fps 足够平滑，渲染次数只有原来的 1/3
    private static let interval: TimeInterval = 0.1

    /// 当前时间（相对参考日期，秒）
    @Published private(set) var time: TimeInterval = Date().timeIntervalSinceReferenceDate

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    private init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.start() }
        })
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
                                           object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        })
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.time = Date().timeIntervalSinceReferenceDate
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
