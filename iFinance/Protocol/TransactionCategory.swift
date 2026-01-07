//
//  TransactionCategory.swift
//  iFinance
//
//  Created by 刘不易 on 2026/1/28.
//

protocol TransactionCategory: Equatable, Hashable, RawRepresentable where RawValue == String {
    var icon: String { get }
}
