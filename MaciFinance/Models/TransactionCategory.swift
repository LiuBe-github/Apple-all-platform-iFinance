//
//  TransactionCategory.swift
//  MaciFinance
//

protocol TransactionCategory: Equatable, Hashable, RawRepresentable where RawValue == String {
    var icon: String { get }
}
