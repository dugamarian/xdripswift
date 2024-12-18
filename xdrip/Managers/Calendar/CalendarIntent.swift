import AppIntents
import EventKit

struct SetCalendarDeliveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Calendar Delivery"
    
    static var description = IntentDescription(
        "Configure and enable the delivery",
        categoryName: "Calendar Management"
    )
    
    @Parameter(title: "Enable Calendar Delivery")
    var isEnabled: Bool
    
    @Parameter(title: "Calendar", default: nil)
    var calendar: CalendarEntity

    @Parameter(title: "Trend", default: false)
    var displayTrendInCalendarEvent: Bool

    @Parameter(title: "Delta", default: false)
    var displayDeltaInCalendarEvent: Bool

    @Parameter(title: "Glucose Unit", default: false)
    var displayUnitInCalendarEvent: Bool

    @Parameter(title: "Interval", default: 0)
    var calendarInterval: Int

    @Parameter(title: "Visual Indicator", default: false)
    var displayVisualIndicatorInCalendarEvent: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)
        let calendarManager = CalendarManager(coreDataManager: coreDataManager)
        
        UserDefaults.standard.calenderId = calendar.id
        UserDefaults.standard.displayTrendInCalendarEvent = displayTrendInCalendarEvent
        UserDefaults.standard.displayDeltaInCalendarEvent = displayDeltaInCalendarEvent
        UserDefaults.standard.displayUnitInCalendarEvent = displayUnitInCalendarEvent
        UserDefaults.standard.calendarInterval = calendarInterval
        UserDefaults.standard.displayVisualIndicatorInCalendarEvent = displayVisualIndicatorInCalendarEvent

        if isEnabled {
            calendarManager.startCalendarDelivery()
        } else {
            calendarManager.stopCalendarDelivery()
        }
        
        return .result()
    }
}

struct StopCalendarDeliveryIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Calendar Delivery"
    static var description = IntentDescription(
        "Stop delivering data to the calendar.",
        categoryName: "Calendar Management"
    )
    
    @MainActor
    func perform() async throws -> some IntentResult {
        let coreDataManager = await CoreDataManager.create(for: ConstantsCoreData.modelName)
        let calendarManager = CalendarManager(coreDataManager: coreDataManager)
        
        calendarManager.stopCalendarDelivery()
        
        return .result()
    }
}

struct CalendarEntity: AppEntity {
    static var defaultQuery = CalendarQuery()
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Calendar"
    }
    
    var id: String
    var name: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CalendarQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CalendarEntity] {
        let eventStore = EKEventStore()
        let allCalendars = eventStore.calendars(for: .event)
        let filtered = allCalendars.filter { identifiers.contains($0.calendarIdentifier) }
        return filtered.map { CalendarEntity(id: $0.calendarIdentifier, name: $0.title) }
    }
    
    func suggestedEntities() async throws -> [CalendarEntity] {
        let eventStore = EKEventStore()
        let allCalendars = eventStore.calendars(for: .event)
        return allCalendars.map { CalendarEntity(id: $0.calendarIdentifier, name: $0.title) }
    }
}
