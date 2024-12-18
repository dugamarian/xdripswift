import Foundation
import os
import EventKit

class CalendarManager: NSObject {
    
    // MARK: - private properties

    private let coreDataManager: CoreDataManager

    private let bgReadingsAccessor: BgReadingsAccessor

    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCalendarManager)

    private let eventStore = EKEventStore()
   
    private var timeStampLastProcessedReading = Date(timeIntervalSince1970: 0.0)
    
    // MARK: - initializer
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
    }
    
    // MARK: - public functions
    
    private func trace(_ message: StaticString, log: OSLog, category: String, type: OSLogType = .default, _ args: CVarArg...) {
           os_log(message, log: log, type: type, args)
       }
    
    public func processNewReading(lastConnectionStatusChangeTimeStamp: Date?) {
        if UserDefaults.standard.createCalendarEvent {
            createCalendarEvent(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
        }
    }
    
    public func startCalendarDelivery() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            UserDefaults.standard.createCalendarEvent = true
        case .notDetermined:
            eventStore.requestAccess(to: .event) { (granted, error) in
                if granted {
                    UserDefaults.standard.createCalendarEvent = true
                } else {
                    self.trace("Access to the calendar was denied", log: self.log, category: ConstantsLog.categoryCalendarManager, type: .error)
                    UserDefaults.standard.createCalendarEvent = false
                }
            }
        case .denied, .restricted:
            self.trace("Access to the calendar is denied or restricted", log: self.log, category: ConstantsLog.categoryCalendarManager, type: .error)
            UserDefaults.standard.createCalendarEvent = false
        case .fullAccess:
            self.trace("Full Access to the calendar is granted", log: self.log, category: ConstantsLog.categoryCalendarManager, type: .error)
        case .writeOnly:
            self.trace("Calendar is write only", log: self.log, category: ConstantsLog.categoryCalendarManager, type: .error)
        @unknown default:
            UserDefaults.standard.createCalendarEvent = false
        }
    }
    
    public func stopCalendarDelivery() {
        UserDefaults.standard.createCalendarEvent = false
        if let calendar = getCalendar() {
            deleteAllEvents(in: calendar)
        }
    }
    
    private func createCalendarEvent(lastConnectionStatusChangeTimeStamp: Date?) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            trace("In createCalendarEvent, createCalendarEvent is enabled but access to calendar is not authorized, setting UserDefaults.standard.createCalendarEvent to false", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }
        
        guard let calendar = getCalendar() else {
            trace("In createCalendarEvent, there's no calendar", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        if Int(Date().timeIntervalSince(timeStampLastProcessedReading)) < (UserDefaults.standard.calendarInterval * 60 - 10) {
            trace("In createCalendarEvent, less than %{public}@ minutes since last event, will not create a new event", log: log, category: ConstantsLog.categoryCalendarManager, type: .info, UserDefaults.standard.calendarInterval.description)
            return
        }

        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)

        guard lastReading.count > 0 else {
            trace("In createCalendarEvent, there are no new readings to process", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        guard abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 5 * 60 else {
            trace("In createCalendarEvent, the latest reading is older than 5 minutes", log: log, category: ConstantsLog.categoryCalendarManager, type: .info)
            return
        }

        deleteAllEvents(in: calendar)
        
        var title = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl).description
       
        if UserDefaults.standard.displayVisualIndicatorInCalendarEvent {
            var visualIndicator = ""
            switch lastReading[0].bgRangeDescription() {
            case .inRange:
                visualIndicator = ConstantsCalendar.visualIndicatorInRange
            case .notUrgent:
                visualIndicator = ConstantsCalendar.visualIndicatorNotUrgent
            case .urgent:
                visualIndicator = ConstantsCalendar.visualIndicatorUrgent
            }
            title = visualIndicator + " " + title
        }

        if !lastReading[0].hideSlope && UserDefaults.standard.displayTrendInCalendarEvent {
            title += " " + lastReading[0].calendarSlopeArrow()
        }

        if UserDefaults.standard.displayDeltaInCalendarEvent && lastReading.count > 1 {
            title += " " + lastReading[0].unitizedDeltaString(
                previousBgReading: lastReading[1],
                showUnit: UserDefaults.standard.displayUnitInCalendarEvent,
                highGranularity: true,
                mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl
            )
        } else if UserDefaults.standard.displayUnitInCalendarEvent {
            title += " " + (UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
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
            trace("In createCalendarEvent, error while saving: %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, error.localizedDescription)
        }
    }

    private func getCalendar() -> EKCalendar? {
        if let calendarIdInUserDefaults = UserDefaults.standard.calenderId {
            for calendar in eventStore.calendars(for: .event) {
                if calendar.title == calendarIdInUserDefaults {
                    return calendar
                }
            }
        }
        UserDefaults.standard.calenderId = eventStore.defaultCalendarForNewEvents?.title
        return eventStore.defaultCalendarForNewEvents
    }
    
    private func deleteAllEvents(in calendar: EKCalendar) {
        let predicate = eventStore.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -24 * 3600),
            end: Date(),
            calendars: [calendar]
        )
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if let notes = event.notes, notes.contains(find: ConstantsCalendar.textInCreatedEvent) {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                } catch let error {
                    trace("In deleteAllEvents, error while removing: %{public}@", log: log, category: ConstantsLog.categoryCalendarManager, type: .error, error.localizedDescription)
                }
            }
        }
    }
}

