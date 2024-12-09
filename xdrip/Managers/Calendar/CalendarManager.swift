import Foundation
import EventKit
import os

class CalendarManager: NSObject {
    
    // MARK: - Private Properties
    
    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private let eventStore = EKEventStore()
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCalendarManager)

    private var timeStampLastProcessedReading = Date(timeIntervalSince1970: 0.0)

    private var isDeliveryOn: Bool = false
    
   
    private var calendarInterval: Int = 10
    private var bloodGlucoseUnitIsMgDl: Bool = true
    private var displayVisualIndicatorInCalendarEvent: Bool = false
    private var displayTrendInCalendarEvent: Bool = true
    private var displayDeltaInCalendarEvent: Bool = false
    private var displayUnitInCalendarEvent: Bool = true
    private var calendarId: String? = nil
    private var lastConnectionStatusChangeTimeStamp: Date? = Date(timeIntervalSince1970: 0)
    
    // MARK: - Initializer
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
    }
    
    // MARK: - Public Functions
    
    func processNewReading(lastConnectionStatusChangeTimeStamp: Date?) {
        guard isDeliveryOn else { return }
        createCalendarEventToStore()
    }
    
    func startCalendarDelivery() {
        
        isDeliveryOn = true
        createCalendarEventToStore()
    }
    
    func stopCalendarDelivery() {
   
        isDeliveryOn = false
        
        guard let calendar = getCalendar(byTitle: calendarId) else {
            trace("No suitable calendar found while stopping delivery.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        deleteAllEvents(in: calendar)
    }
 
    func configureDelivery(
        calendarInterval: Int,
        bloodGlucoseUnitIsMgDl: Bool,
        displayVisualIndicatorInCalendarEvent: Bool,
        displayTrendInCalendarEvent: Bool,
        displayDeltaInCalendarEvent: Bool,
        displayUnitInCalendarEvent: Bool,
        calendarId: String?,
        lastConnectionStatusChangeTimeStamp: Date?
    ) {
        self.calendarInterval = calendarInterval
        self.bloodGlucoseUnitIsMgDl = bloodGlucoseUnitIsMgDl
        self.displayVisualIndicatorInCalendarEvent = displayVisualIndicatorInCalendarEvent
        self.displayTrendInCalendarEvent = displayTrendInCalendarEvent
        self.displayDeltaInCalendarEvent = displayDeltaInCalendarEvent
        self.displayUnitInCalendarEvent = displayUnitInCalendarEvent
        self.calendarId = calendarId
        self.lastConnectionStatusChangeTimeStamp = lastConnectionStatusChangeTimeStamp
    }
    
    // MARK: - Private Functions
    
    private func createCalendarEventToStore() {
        guard isDeliveryOn else {
            trace("Delivery is off, no event will be created.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            trace("No authorization for calendar access.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        guard let calendar = getCalendar(byTitle: calendarId) else {
            trace("No suitable calendar found.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        let timeSinceLast = Int(Date().timeIntervalSince(timeStampLastProcessedReading))
        if timeSinceLast < (calendarInterval * 60 - 10) {
            trace("Less than %d minutes since last event. Not creating a new one.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, calendarInterval)
            return
        }

        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        guard lastReading.count > 0 else {
            trace("No new readings to process.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        guard abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 5 * 60 else {
            trace("Latest reading is older than 5 minutes.", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        deleteAllEvents(in: calendar)

        var title = lastReading[0].unitizedString(unitIsMgDl: bloodGlucoseUnitIsMgDl).description
   
        if (!lastReading[0].hideSlope && displayTrendInCalendarEvent) {
            title = title + " " + lastReading[0].slopeArrow()
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = ConstantsCalendar.textInCreatedEvent
        event.startDate = Date()
        event.endDate = Date(timeIntervalSinceNow: 60 * 10)
        event.calendar = calendar
        
        do {
            try eventStore.save(event, span: .thisEvent)
            timeStampLastProcessedReading = lastReading[0].timeStamp
        } catch let error {
            trace("Error while saving event: %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, error.localizedDescription)
        }
    }
    
    private func getCalendar(byTitle title: String?) -> EKCalendar? {
        if let title = title {
            for cal in eventStore.calendars(for: .event) {
                if cal.title == title {
                    return cal
                }
            }
            return eventStore.defaultCalendarForNewEvents
        } else {
            return eventStore.defaultCalendarForNewEvents
        }
    }
    
    private func deleteAllEvents(in calendar: EKCalendar) {
        let predicate = eventStore.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -24*3600),
            end: Date(),
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if let notes = event.notes, notes.contains(find: ConstantsCalendar.textInCreatedEvent) {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                } catch let error {
                    trace("Error removing event: %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    private func trace(_ message: StaticString, log: OSLog, category: String, type: OSLogType, _ args: CVarArg...) {
        os_log(message, log: log, type: type, args)
    }
}
