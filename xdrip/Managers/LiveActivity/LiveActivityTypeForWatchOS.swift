//
//  LiveActivityType 2.swift
//  xdrip
//
//  Created by Marian Dugaesescu on 07/01/2025.
//  Copyright © 2025 Johan Degraeve. All rights reserved.
//


import Foundation

/// type of live activity to be shown, if any
public enum LiveActivityTypeForWatchOS: Int, CaseIterable, Codable {
    
    public static var allCasesForList: [LiveActivityTypeForWatchOS] {
        return [.disabled, .simpleType, .withChartType]
    }
  
    
    case disabled = 0 
    case simpleType = 1
    case withChartType = 2
    
    var description: String {
        switch self {
        case .disabled:
            return Texts_SettingsView.liveActivityTypeDisabled
        case .simpleType:
            return Texts_SettingsView.liveActivityTypeSimpleType
        case .withChartType:
            return Texts_SettingsView.liveActivityTypeWithChart
        }
    }
    
    var debugDescription: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .simpleType:
            return "Standard"
        case .withChartType:
            return "Chart"
        }
    }
    
    /// this is used for presentation in list. It allows to order the types in the view, different than they case ordering, and so allows to add new cases
    init?(forRowAt row: Int) {
        switch row {
        case 0:
            self = .disabled
        case 1:
            self = .simpleType
        case 2:
            self = .withChartType
        default:
            fatalError("in liveActivityType initializer init(forRowAt row: Int), there's no case for the rownumber")
        }
    }
    
}

