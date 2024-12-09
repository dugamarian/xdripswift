
import AppIntents

@available(iOS 16.0, *)
struct SetCalendarDeliveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Calendar Delivery"
    static var description = IntentDescription(
        "Enable or disable the delivery of data to the calendar.",
        categoryName: "Calendar Management"
    )

    @Parameter(title: "Enable Calendar Delivery")
    var isEnabled: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        
        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)

        let calendarManager = CalendarManager(coreDataManager: coreDataManager)
   
        calendarManager.configureDelivery(
            calendarInterval: 10,
            bloodGlucoseUnitIsMgDl: true,
            displayVisualIndicatorInCalendarEvent: true,
            displayTrendInCalendarEvent: true,
            displayDeltaInCalendarEvent: true,
            displayUnitInCalendarEvent: true,
            calendarId: nil,
            lastConnectionStatusChangeTimeStamp: nil
        )
        
        if isEnabled {
            calendarManager.startCalendarDelivery()
        } else {
            calendarManager.stopCalendarDelivery()
        }

        return .result()
    }
}
