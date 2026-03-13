//
//  BillCategory.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/13.
//

import Foundation
import SwiftUI

enum ExpenditureCategory: String, CaseIterable, TransactionCategory {
    case foodAndBeverage = "餐饮"
    case shopping = "购物"
    case clothing = "服饰"
    case daily = "日用"
    case digital = "数码"
    case makeup = "美妆"
    case skincare = "护肤"
    case app = "应用软件"
    case housing = "住房"
    case traffic = "交通"
    case entertainment = "娱乐"
    case medical = "医疗"
    case communication = "通讯"
    case car = "汽车"
    case study = "学习"
    case office = "办公"
    case sport = "运动"
    case social = "社交"
    case personal = "人情"
    case child = "育儿"
    case pet = "宠物"
    case travel = "旅行"
    case vacation = "度假"
    case cigaretteAndAlcohol = "烟酒"
    case lottery = "彩票"

    var localizedKey: String {
        switch self {
        case .foodAndBeverage: return "cat.exp.food"
        case .shopping: return "cat.exp.shopping"
        case .clothing: return "cat.exp.clothing"
        case .daily: return "cat.exp.daily"
        case .digital: return "cat.exp.digital"
        case .makeup: return "cat.exp.makeup"
        case .skincare: return "cat.exp.skincare"
        case .app: return "cat.exp.app"
        case .housing: return "cat.exp.housing"
        case .traffic: return "cat.exp.traffic"
        case .entertainment: return "cat.exp.entertainment"
        case .medical: return "cat.exp.medical"
        case .communication: return "cat.exp.communication"
        case .car: return "cat.exp.car"
        case .study: return "cat.exp.study"
        case .office: return "cat.exp.office"
        case .sport: return "cat.exp.sport"
        case .social: return "cat.exp.social"
        case .personal: return "cat.exp.personal"
        case .child: return "cat.exp.child"
        case .pet: return "cat.exp.pet"
        case .travel: return "cat.exp.travel"
        case .vacation: return "cat.exp.vacation"
        case .cigaretteAndAlcohol: return "cat.exp.alcohol"
        case .lottery: return "cat.exp.lottery"
        }
    }

    var localizedDisplayName: String {
        let text = L10n.string(localizedKey)
        return text == localizedKey ? rawValue : text
    }
    
    var icon: String {
        switch self {
        case .foodAndBeverage: return "fork.knife"
        case .shopping: return "cart"
        case .clothing: return "tshirt"
        case .daily: return "bag"
        case .digital: return "phone"
        case .makeup: return "paintbrush.pointed"
        case .skincare: return "face.smiling"
        case .app: return "a.circle"
        case .housing: return "house"
        case .traffic: return "car"
        case .entertainment: return "gamecontroller"
        case .medical: return "heart"
        case .communication: return "phone"
        case .car: return "car"
        case .study: return "book"
        case .office: return "printer"
        case .sport: return "shoe"
        case .social: return "person.2"
        case .personal: return "person.3"
        case .child: return "figure.2.and.child.holdinghands"
        case .pet: return "cat"
        case .travel: return "airplane.departure"
        case .vacation: return "beach.umbrella"
        case .cigaretteAndAlcohol: return "takeoutbag.and.cup.and.straw"
        case .lottery: return "number"
        }
    }
}
	
