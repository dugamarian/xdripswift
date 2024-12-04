import Foundation
import os
import EventKit

@MainActor
class CalendarManager: NSObject {
    
    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private let logger = Logger(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCalendarManager)
    private let eventStore = EKEventStore()
    private var timeStampLastProcessedReading = Date(timeIntervalSince1970: 0.0)
    
    private let sharedUserDefaults = UserDefaults(suiteName: "group.com.xdrip4ios.xdrip")
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
    }
    
    public func processNewReading(lastConnectionStatusChangeTimeStamp: Date?) {
        if sharedUserDefaults?.bool(forKey: "createCalendarEvent") == true {
            createCalendarEvent(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
        }
    }
    
    public func setCalendarDelivery(enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: "createCalendarEvent")
        if !enabled {
            if EKEventStore.authorizationStatus(for: .event) == .authorized {
                if let calendar = getCalendar() {
                    deleteAllEvents(in: calendar)
                } else {
                    logger.error("No calendar found.")
                }
            } else {
                logger.info("Calendar access is not authorized.")
            }
        } else {
            await requestCalendarAccessIfNeeded()
        }
    }
    
    private func createCalendarEvent(lastConnectionStatusChangeTimeStamp: Date?) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            logger.info("Calendar access is not authorized. Disabling calendar delivery.")
            sharedUserDefaults?.set(false, forKey: "createCalendarEvent")
            return
        }
        
        guard let calendar = getCalendar() else {
            logger.error("No calendar found.")
            return
        }
        
        if Int(Date().timeIntervalSince(timeStampLastProcessedReading)) < ((sharedUserDefaults?.integer(forKey: "calendarInterval") ?? 15) * 60 - 10) {
            logger.info("Less than \(self.sharedUserDefaults?.integer(forKey: "calendarInterval") ?? 15) minutes since the last event, a new event will not be created.")
            return
        }
        
        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        guard lastReading.count > 0 else {
            logger.info("No new readings to process.")
            return
        }
        
        guard abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 5 * 60 else {
            logger.info("The last reading is older than 5 minutes.")
            return
        }
        
        deleteAllEvents(in: calendar)
        
        let unitIsMgDl = UserDefaults.standard.bloodGlucoseUnitIsMgDl
        var title = lastReading[0].unitizedString(unitIsMgDl: unitIsMgDl)
        
        let displayVisualIndicator = UserDefaults.standard.displayVisualIndicatorInCalendarEvent
        if displayVisualIndicator {
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
        
        let displayTrend = UserDefaults.standard.displayTrendInCalendarEvent
        if !lastReading[0].hideSlope && displayTrend {
            title = title + " " + lastReading[0].calendarSlopeArrow()
        }
        
        let displayDelta = UserDefaults.standard.displayDeltaInCalendarEvent
        let displayUnit = UserDefaults.standard.displayUnitInCalendarEvent
        if displayDelta && lastReading.count > 1 {
            title = title + " " + lastReading[0].unitizedDeltaString(
                previousBgReading: lastReading[1],
                showUnit: displayUnit,
                highGranularity: true,
                mgDl: unitIsMgDl)
        } else if displayUnit {
            title = title + " " + (unitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
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
            logger.error("Error saving event: \(error.localizedDescription)")
        }
    }
    
    private func getCalendar() -> EKCalendar? {
        if let calendarIdInUserDefaults = sharedUserDefaults?.string(forKey: "calenderId") {
            for calendar in eventStore.calendars(for: .event) {
                if calendar.title == calendarIdInUserDefaults {
                    return calendar
                }
            }
        }
        
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            sharedUserDefaults?.set(defaultCalendar.title, forKey: "calenderId")
            return defaultCalendar
        } else {
            logger.error("No default calendar for new events.")
            return nil
        }
    }
    
    private func deleteAllEvents(in calendar: EKCalendar) {
        let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSinceNow: -24 * 3600), end: Date(), calendars: [calendar])
        
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            if let notes = event.notes, notes.contains(ConstantsCalendar.textInCreatedEvent) {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                } catch let error {
                    logger.error("Error deleting event: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func requestCalendarAccessIfNeeded() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            if Bundle.main.isExtension {
                logger.error("Cannot request calendar access in an extension.")
                return
            }
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                if granted {
                    logger.info("Calendar access has been authorized.")
                } else {
                    logger.error("Calendar access has been denied.")
                }
            } catch {
                logger.error("Error requesting calendar access: \(error.localizedDescription)")
            }
        case .denied, .restricted:
            logger.error("Calendar access has been denied.")
        case .authorized:
            logger.info("Calendar access is already authorized.")
        case .fullAccess:
            logger.info("Full Acces.")
        case .writeOnly:
            logger.info("Write only.")
        @unknown default:
            logger.error("Unknown authorization status.")
        }
    }
}

extension Bundle {
    var isExtension: Bool {
        return bundleURL.pathExtension == "appex"
    }
}
