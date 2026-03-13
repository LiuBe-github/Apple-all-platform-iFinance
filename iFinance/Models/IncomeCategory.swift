//
//  IncomeCategory.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/13.
//

import Foundation
import SwiftUI

enum IncomeCategory: String, CaseIterable, TransactionCategory {
    case salary = "工资"
    case bonus = "奖金"
    case workOvertime = "加班"
    case wealthy = "福利"
    case publicReserveFund = "公积金"
    case redPacket = "红包"
    case partTime = "兼职"
    case sideOccupation = "副业"
    case refundTax = "退税"
    case unexpectedIncom = "意外收入"
    case other = "其他"

    var localizedKey: String {
        switch self {
        case .salary: return "cat.inc.salary"
        case .bonus: return "cat.inc.bonus"
        case .workOvertime: return "cat.inc.overtime"
        case .wealthy: return "cat.inc.benefit"
        case .publicReserveFund: return "cat.inc.fund"
        case .redPacket: return "cat.inc.redpacket"
        case .partTime: return "cat.inc.parttime"
        case .sideOccupation: return "cat.inc.side"
        case .refundTax: return "cat.inc.tax"
        case .unexpectedIncom: return "cat.inc.unexpected"
        case .other: return "cat.inc.other"
        }
    }

    var localizedDisplayName: String {
        let text = L10n.string(localizedKey)
        return text == localizedKey ? rawValue : text
    }
    
    var icon: String {
        switch self {
        case .salary: return "wallet.bifold"
        case .bonus: return "dollarsign.circle"
        case .workOvertime: return "display"
        case .wealthy: return "heart.text.square"
        case .publicReserveFund: return "dollarsign.bank.building"
        case .redPacket: return "dollarsign.square"
        case .partTime: return "person.crop.circle.badge.plus"
        case .sideOccupation: return "keyboard"
        case .refundTax: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .unexpectedIncom: return "exclamationmark.bubble"
        case .other: return "ellipsis"
        
        }
    }
}
