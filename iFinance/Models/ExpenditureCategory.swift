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
	
