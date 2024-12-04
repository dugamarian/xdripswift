//
//  LiveActivityIntent.swift
//  xdrip
//
//  Created by Marian Dugaesescu on 13/10/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

#if canImport(AppIntents)
import AppIntents
#endif
import Foundation


struct RestartLiveActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource {
        "Restart Live Activity"
    }

    static var description: IntentDescription? {
        IntentDescription("Restarts the glucose monitoring live activity.", categoryName: "Live Activity")
    }
   
    @MainActor
    func perform() async throws -> some IntentResult {
        
        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)
        let bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        var bgReadings = bgReadingsAccessor.getLatestBgReadings(
            limit: nil,
            fromDate: Date(timeIntervalSinceNow: -14400),
            forSensor: nil,
            ignoreRawData: true,
            ignoreCalculatedValue: false
        )
        
        bgReadings.sort { $0.timeStamp > $1.timeStamp }

        guard bgReadings.count >= 2 else {
            throw IntentError.message("Not enough glucose data to calculate trend.")
        }

        var bgReadingValues: [Double] = []
        var bgReadingDates: [Date] = []

        for bgReading in bgReadings {
            bgReadingValues.append(bgReading.calculatedValue)
            bgReadingDates.append(bgReading.timeStamp)
        }

        let isMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        let urgentLowLimitInMgDl = UserDefaults.standard.urgentLowMarkValue
        let lowLimitInMgDl = UserDefaults.standard.lowMarkValue
        let highLimitInMgDl = UserDefaults.standard.highMarkValue
        let urgentHighLimitInMgDl = UserDefaults.standard.urgentHighMarkValue
        let dataSourceDescription = ""

        let currentReading = bgReadings[0]
        let previousReading = bgReadings[1]

        let deltaChangeInMgDl = currentReading.calculatedValue - previousReading.calculatedValue

    
        let curentSlope = currentReading.slopeOrdinal()
    
        let size = UserDefaults.standard.liveActivityType

        let contentState = XDripWidgetAttributes.ContentState(
            bgReadingValues: bgReadingValues,
            bgReadingDates: bgReadingDates,
            isMgDl: isMgDl,
            slopeOrdinal: curentSlope,
            deltaValueInUserUnit: deltaChangeInMgDl,
            urgentLowLimitInMgDl: urgentLowLimitInMgDl,
            lowLimitInMgDl: lowLimitInMgDl,
            highLimitInMgDl: highLimitInMgDl,
            urgentHighLimitInMgDl: urgentHighLimitInMgDl,
            liveActivityType: size,
            dataSourceDescription: dataSourceDescription
        )

        // Restart the live activity
    
            LiveActivityManager.shared.runActivity(contentState: contentState, forceRestart: true)
        

        return .result()
    }
}
