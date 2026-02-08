//
//  IncomeCategory.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/13.
//

import Foundation

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
