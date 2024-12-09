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
        
        if isEnabled {
            calendarManager.startCalendarDelivery()
            return .result()
        } else {
            calendarManager.stopCalendarDelivery()
            return .result()
        }
    }
}
