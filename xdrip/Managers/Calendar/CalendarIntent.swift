//
//  CalendarIntent.swift
//  xdrip
//
//  Created by Marian Dugaesescu on 25/10/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//


import AppIntents
import UIKit

@available(iOS 16.0, *)
struct SetCalendarDeliveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Calendar Delivery"

    static var description = IntentDescription(
        "Enable or disable the delivery of data to the calendar.",
        categoryName: "Calendar Management"
    )

    @Parameter(
        title: "Enable Calendar Delivery",
        default: true
    )
    var enable: Bool

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
     
        guard let appDelegate = await UIApplication.shared.delegate as? AppDelegate else {
            throw NSError(domain: "CalendarManagerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access AppDelegate"])
        }

        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)

        let calendarManager = CalendarManager(coreDataManager: coreDataManager)

        calendarManager.setCalendarDelivery(enabled: enable)

        return .result()
    }
}
