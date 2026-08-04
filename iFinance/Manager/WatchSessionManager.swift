//
//  WatchSessionManager.swift
//  iFinance
//
//  iPhone 端 WCSession 接收管理器
//  负责接收来自 Apple Watch 的账单数据并写入 Core Data
//

import Foundation
import WatchConnectivity
internal import CoreData
import os.log

private let logger = Logger(subsystem: "com.liube.ifinance", category: "WatchSessionManager")

final class WatchSessionManager: NSObject {

    static let shared = WatchSessionManager()

    private override init() {
        super.init()
    }

    // MARK: - 激活 Session

    func activate() {
        guard WCSession.isSupported() else {
            logger.warning("此设备不支持WCSession")
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        logger.info("WCSession已请求激活（iPhone端）")
    }

    // MARK: - 私有：将 Watch 账单写入 Core Data

    private func saveBillFromWatch(_ payload: [String: Any]) {
        guard
            let idString = payload["id"] as? String,
            let amount = payload["amount"] as? Double,
            let type = payload["type"] as? String,
            let category = payload["category"] as? String,
            let dateString = payload["date"] as? String,
            let date = ISO8601DateFormatter().date(from: dateString)
        else {
            logger.error("Watch 账单 payload 字段不完整，跳过写入")
            return
        }

        let note = payload["note"] as? String
        // Watch 端可能没有正确设置 userIdentifier（返回 "anonymous"）
        // 优先使用 Watch 传来的有效 userIdentifier；若为 nil 或 "anonymous"，则使用当前登录用户
        let watchUserId = payload["userIdentifier"] as? String
        let userIdentifier: String
        if let id = watchUserId, id != "anonymous" {
            userIdentifier = id
        } else {
            userIdentifier = PersistenceController.currentUserIdentifier
        }

        let context = PersistenceController.shared.container.viewContext

        // 幂等：若已存在相同 id 则跳过
        let fetchRequest: NSFetchRequest<Bill> = Bill.fetchRequest()
        let targetUUID = UUID(uuidString: idString) ?? UUID()
        fetchRequest.predicate = NSPredicate(format: "id == %@", targetUUID as CVarArg)
        fetchRequest.fetchLimit = 1
        if (try? context.fetch(fetchRequest).first) != nil {
            logger.info("账单 \(idString) 已存在，跳过重复写入")
            return
        }

        let bill = Bill(context: context)
        bill.id = UUID(uuidString: idString) ?? UUID()
        bill.amount = NSDecimalNumber(value: amount)
        bill.type = type
        bill.category = category
        bill.note = note
        bill.date = date
        bill.createdAt = Date()
        bill.createdBy = userIdentifier
        bill.updatedAt = Date()
        bill.updatedBy = userIdentifier

        do {
            try context.save()
            logger.info("Watch 账单已写入 Core Data：\(category) ¥\(amount)，归属用户：\(userIdentifier ?? "nil")")
        } catch {
            logger.error("Watch 账单写入失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 私有：将今日账单推送回 Watch

    private func sendTodayBillsToWatch(session: WCSession) {
        let context = PersistenceController.shared.container.viewContext
        let userIdentifier = PersistenceController.currentUserIdentifier

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "createdBy == %@", userIdentifier),
            NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        ])

        guard let bills = try? context.fetch(request) else { return }

        let billsArray: [[String: Any]] = bills.map { bill in
            var dict: [String: Any] = [
                "id": bill.id?.uuidString ?? UUID().uuidString,
                "amount": bill.amount?.doubleValue ?? 0,
                "type": bill.type ?? "expenditure",
                "category": bill.category ?? "",
                "date": ISO8601DateFormatter().string(from: bill.date ?? Date())
            ]
            if let note = bill.note { dict["note"] = note }
            return dict
        }

        do {
            try session.transferUserInfo(["action": "todayBills", "bills": billsArray])
            logger.info("已推送 \(bills.count) 条今日账单到 Watch")
        } catch {
            logger.error("推送今日账单失败：\(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let error {
            logger.error("iPhone WCSession 激活失败：\(error.localizedDescription)")
        } else {
            logger.info("iPhone WCSession 激活成功，状态：\(activationState.rawValue)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        logger.info("WCSession inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        logger.info("WCSession deactivated，重新激活")
        session.activate()
    }

    /// 接收 Watch 通过 updateApplicationContext 发来的消息
    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        logger.info("收到 Watch applicationContext：\(applicationContext.keys.joined(separator: ", "))")
        DispatchQueue.main.async {
            guard let action = applicationContext["action"] as? String else { return }
            switch action {
            case "addBill":
                if let payload = applicationContext["bill"] as? [String: Any] {
                    self.saveBillFromWatch(payload)
                }
            case "requestTodayBills":
                self.sendTodayBillsToWatch(session: session)
            default:
                logger.warning("未知 action：\(action)")
            }
        }
    }

    /// 接收 Watch 通过 transferUserInfo 发来的消息（更可靠，推荐未来改用此方式）
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async {
            guard let action = userInfo["action"] as? String else { return }
            switch action {
            case "addBill":
                if let payload = userInfo["bill"] as? [String: Any] {
                    self.saveBillFromWatch(payload)
                }
            case "requestTodayBills":
                self.sendTodayBillsToWatch(session: session)
            default:
                break
            }
        }
    }
}
