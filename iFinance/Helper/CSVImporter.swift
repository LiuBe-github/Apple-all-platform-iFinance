//
//  CSVImporter.swift
//  iFinance
//
//  CSV 导入纯逻辑：行解析 + 行到 Bill 的映射（含用户隔离字段）
//  供 SettingView 导入入口与单元测试共用
//

import Foundation
internal import CoreData

enum CSVImporter {

    // MARK: - 格式化器（static 复用）

    private static let isoFormatter = ISO8601DateFormatter()

    private static let fallbackDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private static let validTypes: Set<String> = ["income", "expenditure", "transfer"]

    // MARK: - 行解析

    /// 把 CSV 文本解析为行数组；支持引号包裹、"" 转义、CRLF/LF/CR 换行、跳过空行
    /// - Note: Swift 中 `"\r\n"` 是**一个** Character，因此换行判断必须同时覆盖 `\n` / `\r\n` / `\r`
    static func parseRows(_ input: String) -> [[String]] {
        var rows: [[String]] = [], curRow: [String] = [], curField = "", inQ = false
        let chars = Array(input)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch == "\"" {
                if inQ && i + 1 < chars.count && chars[i + 1] == "\"" {
                    curField.append("\"")
                    i += 1
                } else {
                    inQ.toggle()
                }
            } else if ch == "," && !inQ {
                curRow.append(curField); curField = ""
            } else if (ch == "\n" || ch == "\r\n" || ch == "\r") && !inQ {
                curRow.append(curField)
                if !curRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(curRow)
                }
                curRow = []
                curField = ""
            }
            else if ch != "\r" {
                curField.append(ch)
            }
            i += 1
        }
        if !curField.isEmpty || !curRow.isEmpty {
            curRow.append(curField)
            if !curRow.allSatisfy({ $0.isEmpty }) {
                rows.append(curRow)
            }
        }
        return rows
    }

    // MARK: - 行 → Bill

    /// 把一行（date,type,category,amount,note）映射为 Bill；非法行返回 nil（调用方计入 skipped）
    /// - Parameter identifier: 当前账号标识，写入 createdBy / updatedBy（账单可见性依赖）
    static func makeBill(row: [String], context: NSManagedObjectContext, identifier: String) -> Bill? {
        guard row.count >= 5 else { return nil }
        let type = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard validTypes.contains(type) else { return nil }
        let date = isoFormatter.date(from: row[0].trimmingCharacters(in: .whitespacesAndNewlines))
            ?? fallbackDateFormatter.date(from: row[0])
        guard let amount = Decimal(string: row[3], locale: posixLocale) else { return nil }

        let bill = Bill(context: context)
        bill.id = UUID()
        bill.date = date ?? Date()
        bill.type = type
        bill.category = row[2].isEmpty ? nil : row[2]
        bill.note = row[4].isEmpty ? nil : row[4]
        bill.amount = NSDecimalNumber(decimal: amount)
        bill.createdAt = Date()
        bill.updatedAt = Date()
        bill.createdBy = identifier
        bill.updatedBy = identifier
        return bill
    }
}
