import Foundation
import os
import EventKit

class CalendarManager: NSObject {
    
    private let coreDataManager: CoreDataManager
    private let bgReadingsAccessor: BgReadingsAccessor
    private let logger = Logger(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryCalendarManager)
    private let eventStore = EKEventStore()
    private var timeStampLastProcessedReading = Date(timeIntervalSince1970: 0.0)
    
    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
        self.bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
    }
    
    public func processNewReading(lastConnectionStatusChangeTimeStamp: Date?) {
        if UserDefaults.standard.createCalendarEvent {
            createCalendarEvent(lastConnectionStatusChangeTimeStamp: lastConnectionStatusChangeTimeStamp)
        }
    }
    
    public func setCalendarDelivery(enabled: Bool) {
        UserDefaults.standard.createCalendarEvent = enabled
        if !enabled {
            if EKEventStore.authorizationStatus(for: .event) == .authorized {
                if let calendar = getCalendar() {
                    deleteAllEvents(in: calendar)
                } else {
                    logger.error("Nu a fost găsit niciun calendar.")
                }
            } else {
                logger.info("Accesul la calendar nu este autorizat.")
            }
        } else {
            requestCalendarAccessIfNeeded()
        }
    }
    
    private func createCalendarEvent(lastConnectionStatusChangeTimeStamp: Date?) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else {
            logger.info("Accesul la calendar nu este autorizat. Dezactivez livrarea către calendar.")
            UserDefaults.standard.createCalendarEvent = false
            return
        }
        
        guard let calendar = getCalendar() else {
            logger.error("Nu a fost găsit niciun calendar.")
            return
        }
        
        if Int(Date().timeIntervalSince(timeStampLastProcessedReading)) < (UserDefaults.standard.calendarInterval * 60 - 10) {
            logger.info("Mai puțin de \(UserDefaults.standard.calendarInterval) minute de la ultimul eveniment, nu se va crea un nou eveniment.")
            return
        }
        
        let lastReading = bgReadingsAccessor.get2LatestBgReadings(minimumTimeIntervalInMinutes: 4.0)
        
        guard lastReading.count > 0 else {
            logger.info("Nu există citiri noi de procesat.")
            return
        }
        
        guard abs(lastReading[0].timeStamp.timeIntervalSinceNow) < 5 * 60 else {
            logger.info("Ultima citire este mai veche de 5 minute.")
            return
        }
        
        deleteAllEvents(in: calendar)
        
        var title = lastReading[0].unitizedString(unitIsMgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        
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
            title = title + " " + lastReading[0].slopeArrow()
        }
        
        if UserDefaults.standard.displayDeltaInCalendarEvent && lastReading.count > 1 {
            title = title + " " + lastReading[0].unitizedDeltaString(
                previousBgReading: lastReading[1],
                showUnit: UserDefaults.standard.displayUnitInCalendarEvent,
                highGranularity: true,
                mgDl: UserDefaults.standard.bloodGlucoseUnitIsMgDl)
        } else if UserDefaults.standard.displayUnitInCalendarEvent {
            title = title + " " + (UserDefaults.standard.bloodGlucoseUnitIsMgDl ? Texts_Common.mgdl : Texts_Common.mmol)
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
            logger.error("Eroare la salvarea evenimentului: \(error.localizedDescription)")
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
        
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            UserDefaults.standard.calenderId = defaultCalendar.title
            return defaultCalendar
        } else {
            logger.error("Nu există un calendar implicit pentru evenimente noi.")
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
                    logger.error("Eroare la ștergerea evenimentului: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func requestCalendarAccessIfNeeded() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    self.logger.info("Accesul to calendar was autorised.")
                } else {
                    self.logger.error("Acces to calendar was refused.")
                }
            }
        case .denied, .restricted:
            logger.error("Acces to calendar was refused.")
        case .authorized:
            logger.info("Acces to calendar was already autorised.")
        @unknown default:
            logger.error("unknown state.")
        }
    }
}
