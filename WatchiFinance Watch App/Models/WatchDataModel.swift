//
//  WatchDataModel.swift
//  WatchiFinance Watch App
//
//  管理手表端数据：通过 WatchConnectivity 与 iPhone 同步
//

import Foundation
import Combine
import WatchConnectivity
import os.log

private let logger = Logger(subsystem: "com.liube.ifinance.watch", category: "WatchDataModel")

// MARK: - 账单传输模型

struct WatchBill: Identifiable, Codable {
    var id: String
    let amount: Double
    let type: String       // "expenditure" / "income"
    let category: String
    let note: String?
    let date: Date         // ISO8601

    init(id: String = UUID().uuidString, amount: Double, type: String, category: String, note: String? = nil, date: Date = Date()) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.note = note
        self.date = date
    }

    /// 编码为字典发送给 iPhone（通过 WCSession）
    func toPayload() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "amount": amount,
            "type": type,
            "category": category,
            "date": ISO8601DateFormatter().string(from: date)
        ]
        if let note { dict["note"] = note }
        return dict
    }

    static func from(_ payload: [String: Any]) -> WatchBill? {
        guard let id = payload["id"] as? String,
              let amount = payload["amount"] as? Double,
              let type = payload["type"] as? String,
              let category = payload["category"] as? String else {
            return nil
        }
        let note = payload["note"] as? String
        let dateString = payload["date"] as? String
        let date = dateString.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        return WatchBill(id: id, amount: amount, type: type, category: category, note: note, date: date)
    }
}

// MARK: - 数据模型

@MainActor
final class WatchDataModel: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchDataModel()

    // Published data
    @Published private(set) var todayBills: [WatchBill] = []
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var syncMessage: String? = nil

    // 本地缓存（用于离线展示）
    private var cachedBills: [WatchBill] = []

    // Computed properties for UI
    var todayExpense: Double {
        todayBills.filter { $0.type == "expenditure" }.reduce(0) { $0 + $1.amount }
    }

    var todayIncome: Double {
        todayBills.filter { $0.type == "income" }.reduce(0) { $0 + $1.amount }
    }

    var todayBalance: Double {
        todayIncome - todayExpense
    }

    var todayCount: Int {
        todayBills.count
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        loadCachedBills()
        refreshTodayBills()
    }

    // MARK: - Public API

    /// 发送新账单到 iPhone
    func sendBill(_ bill: WatchBill) async -> Bool {
        guard WCSession.default.isReachable else {
            logger.warning("iPhone 未连接，尝试缓存")
            cacheBill(bill)
            addLocalBill(bill)
            return false
        }

        let payload = bill.toPayload()
        do {
            try WCSession.default.updateApplicationContext(["action": "addBill", "bill": payload])
            logger.info("账单已发送到 iPhone: \(bill.category) ¥\(bill.amount)")
            addLocalBill(bill)
            return true
        } catch {
            logger.error("发送失败: \(error.localizedDescription)")
            cacheBill(bill)
            addLocalBill(bill)
            return false
        }
    }

    /// 刷新今日数据（请求 iPhone 同步）
    func requestSync() {
        guard WCSession.default.isReachable else {
            logger.info("iPhone 未连接，使用本地缓存")
            return
        }
        do {
            try WCSession.default.updateApplicationContext(["action": "requestTodayBills"])
            logger.info("已请求同步今日数据")
        } catch {
            logger.error("同步请求失败: \(error)")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                logger.error("WCSession 激活失败: \(error)")
            } else {
                logger.info("WCSession 激活成功: \(state.rawValue)")
                switch state {
                case .activated:
                    self.isReachable = session.isReachable
                    self.requestSync()
                case .notActivated:
                    break
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async {
            if let action = userInfo["action"] as? String {
                switch action {
                case "todayBills":
                    if let billsArray = userInfo["bills"] as? [[String: Any]] {
                        let bills = billsArray.compactMap(WatchBill.from)
                        self.todayBills = bills
                        self.cachedBills = bills
                        self.saveCache(bills)
                        logger.info("收到 \(bills.count) 条今日账单")
                    }
                default:
                    break
                }
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable {
                self.requestSync()
            }
        }
    }

    // MARK: - Local Cache (UserDefaults)

    private let billsCacheKey = "WatchBillsCache"

    private func saveCache(_ bills: [WatchBill]) {
        do {
            let data = try JSONEncoder().encode(bills)
            UserDefaults.standard.set(data, forKey: billsCacheKey)
        } catch {
            logger.error("缓存保存失败: \(error)")
        }
    }

    private func loadCachedBills() {
        guard let data = UserDefaults.standard.data(forKey: billsCacheKey),
              let bills = try? JSONDecoder().decode([WatchBill].self, from: data) else {
            return
        }
        cachedBills = bills
        filterToday(from: bills)
    }

    private func cacheBill(_ bill: WatchBill) {
        cachedBills.append(bill)
        saveCache(cachedBills)
    }

    private func addLocalBill(_ bill: WatchBill) {
        todayBills.append(bill)
        // 更新本地缓存中的今天数据
        cachedBills.append(bill)
        saveCache(cachedBills)
    }

    private func refreshTodayBills() {
        filterToday(from: cachedBills)
    }

    private func filterToday(from allBills: [WatchBill]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        todayBills = allBills.filter { bill in
            calendar.isDate(bill.date, inSameDayAs: startOfDay)
        }
    }
}
