//
//  WatchStateModel.swift
//  xDrip Watch App
//
//  Created by Paul Plant on 11/2/24.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UserNotifications
import Combine
import Foundation
import SwiftUI
import WatchConnectivity
import WidgetKit
import WatchKit // Import necesar pentru WKExtendedRuntimeSession

/// holds the watch state and allows updates and computed properties/variables to be generated for the different views that use it
/// also used to update the ComplicationSharedUserDefaultsModel in the app group so that the complication can access the data
final class WatchStateModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate, WKApplicationDelegate, WKExtendedRuntimeSessionDelegate {
    
    // MARK: - Watch Connectivity
    var session: WCSession
    
    // Timer pentru refresh UI
    let timer = Timer.publish(every: 1, tolerance: 0.5, on: .main, in: .common).autoconnect()
    @Published var timerControlDate = Date()
    
    // Valorile BG
    var bgReadingValues: [Double] = []
    var bgReadingDates: [Date] = []
    var bgReadingDatesAsDouble: [Double] = []
    
    // MARK: - Extended Runtime Session
    var extendedSession: WKExtendedRuntimeSession!
    
    // MARK: - Init
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        
        // Set delegate-ul pentru WCSession
        session.delegate = self
        session.activate()
        
        // Inițializează extendedSession, dar NU o pornim încă.
        extendedSession = WKExtendedRuntimeSession()
        extendedSession.delegate = self
    }
    
    // MARK: - Handle background tasks (dacă folosești scenariul cu WKRefreshBackgroundTask)
   
    
  
    // MARK: - Public Published vars
    @Published var isMgDl: Bool = true
    @Published var slopeOrdinal: Int = 2
    @Published var deltaValueInUserUnit: Double = 0
    @Published var urgentLowLimitInMgDl: Double = 60
    @Published var lowLimitInMgDl: Double = 80
    @Published var highLimitInMgDl: Double = 170
    @Published var urgentHighLimitInMgDl: Double = 250
    @Published var updatedDate: Date = Date()
    @Published var activeSensorDescription: String = ""
    @Published var sensorAgeInMinutes: Double = 0
    @Published var sensorMaxAgeInMinutes: Double = 14400
    @Published var timeStampOfLastFollowerConnection: Date = Date()
    @Published var secondsUntilFollowerDisconnectWarning: Int = 60 * 6
    @Published var timeStampOfLastHeartBeat: Date = Date()
    @Published var secondsUntilHeartBeatDisconnectWarning: Int = 90
    @Published var isMaster: Bool = true
    @Published var followerDataSourceType: FollowerDataSourceType = .nightscout
    @Published var followerBackgroundKeepAliveType: FollowerBackgroundKeepAliveType = .normal
    @Published var keepAliveIsDisabled: Bool = false
    @Published var liveDataIsEnabled: Bool = false
    @Published var remainingComplicationUserInfoTransfers: Int = 99
    
    @Published var lastUpdatedTextString: String = Texts_WatchApp.requestingData
    @Published var lastUpdatedTimeString: String = ""
    @Published var lastUpdatedTimeAgoString: String = ""
    @Published var debugString: String = "Debug..."
    @Published var chartHoursIndex: Int = 1
    @Published var requestingDataIconColor: Color = ConstantsAppleWatch.requestingDataIconColorInactive
    @Published var lastComplicationUpdateTimeStamp: Date = .distantPast
    
    @Published var updateBigNumberViewDate: Date = Date()
    @Published var updateMainViewDate: Date = Date()
    
    
    
    // MARK: - Alte funcții
    
    func bgValueInMgDl() -> Double? {
        return bgReadingValues.isEmpty ? nil : bgReadingValues[0]
    }
    
    func bgValueStringInUserChosenUnit() -> String {
        if let bgReadingDate = bgReadingDate(), let bgValueInMgDl = bgValueInMgDl(), bgReadingDate > Date().addingTimeInterval(-60 * 20) {
            return bgReadingValues.isEmpty ? (isMgDl ? "---" : "-.-") : bgValueInMgDl.mgDlToMmolAndToString(mgDl: isMgDl)
        } else {
            return isMgDl ? "---" : "-.-"
        }
    }
    
    func bgReadingDate() -> Date? {
        return bgReadingDates.isEmpty ? nil : bgReadingDates.first
    }
    
    func bgUnitString() -> String {
        return isMgDl ? Texts_Common.mgdl : Texts_Common.mmol
    }
    
    func bgTextColor() -> Color {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 7), let bgValueInMgDl = bgValueInMgDl() {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .gray
        }
    }
    
    func lastUpdatedMinsAgoString() -> String {
        if let bgReadingDate = bgReadingDate() {
            let diffComponents = Calendar.current.dateComponents([.hour], from: bgReadingDate, to: Date())
            
            if let hours = diffComponents.hour, hours >= 1 {
                return bgReadingDate.daysAndHoursAgo(appendAgo: true)
            } else {
                return bgReadingDate.daysAndHoursAgoFull(appendAgo: true)
            }
        } else {
            return "Waiting..."
        }
    }
    
    func lastUpdatedTimeColor() -> Color {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 7) {
            return .colorSecondary
        } else if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 12) {
            return .yellow
        } else if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 22) {
            return .red
        } else {
            return .colorTertiary
        }
    }
    
    func trendArrow() -> String {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 20) {
            switch slopeOrdinal {
            case 7: return "\u{2193}\u{2193}" // ↓↓
            case 6: return "\u{2193}"         // ↓
            case 5: return "\u{2198}"         // ↘
            case 4: return "\u{2192}"         // →
            case 3: return "\u{2197}"         // ↗
            case 2: return "\u{2191}"         // ↑
            case 1: return "\u{2191}\u{2191}" // ↑↑
            default: return ""
            }
        } else {
            return ""
        }
    }
    
    func deltaChangeStringInUserChosenUnit() -> String {
        if let bgReadingDate = bgReadingDate(), bgReadingDate > Date().addingTimeInterval(-60 * 20) {
            let deltaValueAsString = isMgDl ? deltaValueInUserUnit.mgDlToMmolAndToString(mgDl: isMgDl)
                                            : deltaValueInUserUnit.mmolToString()
            
            var deltaSign: String = ""
            if deltaValueInUserUnit > 0 {
                deltaSign = "+"
            }
            
            return deltaValueInUserUnit == 0.0
                ? (isMgDl ? "+0" : "+0.0")
                : (deltaSign + deltaValueAsString)
        } else {
            return "-"
        }
    }
    
    func activeSensorProgress() -> (progress: Float, textColor: Color) {
        if sensorAgeInMinutes > 0 {
            let sensorTimeLeftInMinutes = sensorMaxAgeInMinutes - sensorAgeInMinutes
            let progress = Float(1 - (sensorTimeLeftInMinutes / sensorMaxAgeInMinutes))
            
            if sensorTimeLeftInMinutes < 0 {
                return (1.0, ConstantsHomeView.sensorProgressExpiredSwiftUI)
            } else if sensorTimeLeftInMinutes <= ConstantsHomeView.sensorProgressViewUrgentInMinutes {
                return (progress, ConstantsHomeView.sensorProgressViewProgressColorUrgentSwiftUI)
            } else if sensorTimeLeftInMinutes <= ConstantsHomeView.sensorProgressViewWarningInMinutes {
                return (progress, ConstantsHomeView.sensorProgressViewProgressColorWarningSwiftUI)
            } else {
                return (progress, ConstantsHomeView.sensorProgressNormalTextColorSwiftUI)
            }
        } else {
            return (0, ConstantsHomeView.sensorProgressNormalTextColorSwiftUI)
        }
    }
    
    func getFollowerConnectionNetworkStatus() -> (image: Image, color: Color) {
        if timeStampOfLastFollowerConnection > Date().addingTimeInterval(-Double(secondsUntilFollowerDisconnectWarning)) {
            return (Image(systemName: "network"), .green)
        } else {
            if followerBackgroundKeepAliveType != .disabled {
                return (Image(systemName: "network.slash"), .red)
            } else {
                return (Image(systemName: "network.slash"), .gray)
            }
        }
    }
    
    func getFollowerBackgroundKeepAliveColor() -> Color {
        if followerBackgroundKeepAliveType == .heartbeat {
            if let timeDifferenceInSeconds = Calendar.current.dateComponents([.second], from: timeStampOfLastHeartBeat, to: Date()).second,
               timeDifferenceInSeconds > secondsUntilHeartBeatDisconnectWarning {
                return .red
            } else {
                return .green
            }
        } else {
            return .gray
        }
    }
    
    func requestWatchStateUpdate() {
        guard session.activationState == .activated else {
            session.activate()
            return
        }
        if session.isReachable {
            DispatchQueue.main.async {
                self.requestingDataIconColor = ConstantsAppleWatch.requestingDataIconColorPending
                self.debugString = self.debugString.replacingOccurrences(of: "Idle", with: "Fetching")
            }
            
            print("Requesting watch state update from iOS")
            
            session.sendMessage(["requestWatchUpdate": "watchState"], replyHandler: nil) { error in
                print("WatchStateModel error: " + error.localizedDescription)
            }
        }
    }
    
    func gaugeModel() -> (minValue: Double, maxValue: Double, nilValue: Double, gaugeGradient: Gradient) {
        if let bgReadingDate = bgReadingDate(), bgReadingDate < Date().addingTimeInterval(-60 * 7) {
            return (0, 1, 0.5, Gradient(colors: [.gray]))
        }
        
        var minValue: Double = lowLimitInMgDl
        var maxValue: Double = highLimitInMgDl
        var colorArray = [Color]()
        
        if let bgValueInMgDl = bgValueInMgDl() {
            if bgValueInMgDl >= urgentHighLimitInMgDl {
                maxValue = ConstantsCalibrationAlgorithms.maximumBgReadingCalculatedValue
            } else if bgValueInMgDl >= highLimitInMgDl {
                maxValue = urgentHighLimitInMgDl
            }
            
            if bgValueInMgDl <= urgentLowLimitInMgDl {
                minValue = ConstantsCalibrationAlgorithms.minimumBgReadingCalculatedValue
            } else if bgValueInMgDl <= lowLimitInMgDl {
                minValue = urgentLowLimitInMgDl
            }
        }
        
        let nilValue = minValue + ((maxValue - minValue) / 2)
        
        let minValueRoundedDown = Double(10 * Int(minValue / 10))
        let maxValueRoundedUp = Double(10 * Int(maxValue / 10)) + 10
        
        let reducedGranularity = (maxValueRoundedUp - minValueRoundedDown) > 200
        
        for currentValue in stride(from: minValueRoundedDown, through: maxValueRoundedUp, by: reducedGranularity ? 20 : 10) {
            if currentValue > urgentHighLimitInMgDl || currentValue <= urgentLowLimitInMgDl {
                colorArray.append(.red)
            } else if currentValue > highLimitInMgDl || currentValue <= lowLimitInMgDl {
                colorArray.append(.yellow)
            } else {
                colorArray.append(.green)
            }
        }
        
        return (minValue, maxValue, nilValue, Gradient(colors: colorArray))
    }
    
    // MARK: - Private functions
    
    private func processWatchStateFromDictionary(dictionary: [String: Any]) {
        let bgReadingDatesFromDictionary: [Double] = dictionary["bgReadingDatesAsDouble"] as? [Double] ?? [0]
        
        if let lastBgReadingDateFromDictionaryReceived = bgReadingDatesFromDictionary.first,
           Date(timeIntervalSince1970: lastBgReadingDateFromDictionaryReceived) > Date(timeIntervalSinceNow: -3600 * 12) {
            
            bgReadingDates = bgReadingDatesFromDictionary.map { Date(timeIntervalSince1970: $0) }
            bgReadingValues = dictionary["bgReadingValues"] as? [Double] ?? [100]
            
            isMgDl = dictionary["isMgDl"] as? Bool ?? true
            slopeOrdinal = dictionary["slopeOrdinal"] as? Int ?? 0
            deltaValueInUserUnit = dictionary["deltaValueInUserUnit"] as? Double ?? 0
            urgentLowLimitInMgDl = dictionary["urgentLowLimitInMgDl"] as? Double ?? 60
            lowLimitInMgDl = dictionary["lowLimitInMgDl"] as? Double ?? 70
            highLimitInMgDl = dictionary["highLimitInMgDl"] as? Double ?? 180
            urgentHighLimitInMgDl = dictionary["urgentHighLimitInMgDl"] as? Double ?? 250
            updatedDate = dictionary["updatedDate"] as? Date ?? .now
            activeSensorDescription = dictionary["activeSensorDescription"] as? String ?? ""
            sensorAgeInMinutes = dictionary["sensorAgeInMinutes"] as? Double ?? 0
            sensorMaxAgeInMinutes = dictionary["sensorMaxAgeInMinutes"] as? Double ?? 0
            isMaster = dictionary["isMaster"] as? Bool ?? true
            followerDataSourceType = FollowerDataSourceType(rawValue: dictionary["followerDataSourceTypeRawValue"] as? Int ?? 0) ?? .nightscout
            followerBackgroundKeepAliveType = FollowerBackgroundKeepAliveType(rawValue: dictionary["followerBackgroundKeepAliveTypeRawValue"] as? Int ?? 0) ?? .normal
            timeStampOfLastFollowerConnection = Date(timeIntervalSince1970: dictionary["timeStampOfLastFollowerConnection"] as? Double ?? 0)
            secondsUntilFollowerDisconnectWarning = dictionary["secondsUntilFollowerDisconnectWarning"] as? Int ?? 0
            timeStampOfLastHeartBeat = Date(timeIntervalSince1970: dictionary["timeStampOfLastHeartBeat"] as? Double ?? 0)
            secondsUntilHeartBeatDisconnectWarning = dictionary["secondsUntilHeartBeatDisconnectWarning"] as? Int ?? 0
            keepAliveIsDisabled = dictionary["keepAliveIsDisabled"] as? Bool ?? false
            remainingComplicationUserInfoTransfers = dictionary["remainingComplicationUserInfoTransfers"] as? Int ?? 99
            liveDataIsEnabled = dictionary["liveDataIsEnabled"] as? Bool ?? false
            
            if let bgReadingDate = bgReadingDate() {
                lastUpdatedTextString = Texts_WatchApp.lastReading + " "
                lastUpdatedTimeString = bgReadingDate.formatted(date: .omitted, time: .shortened)
                lastUpdatedTimeAgoString = bgReadingDate.daysAndHoursAgo(appendAgo: true)
            } else {
                lastUpdatedTextString = Texts_WatchApp.noSensorData
                lastUpdatedTimeString = ""
                lastUpdatedTimeAgoString = ""
            }
            
            debugString = generateDebugString()
            
            updateComplicationData()
        }
    }
    
    private func updateComplicationData() {
        guard let sharedUserDefaults = UserDefaults(suiteName: Bundle.main.appGroupSuiteName) else { return }
        
        let bgReadingDatesAsDouble = bgReadingDates.map { $0.timeIntervalSince1970 }
        
        let complicationSharedUserDefaultsModel = ComplicationSharedUserDefaultsModel(
            bgReadingValues: bgReadingValues,
            bgReadingDatesAsDouble: bgReadingDatesAsDouble,
            isMgDl: isMgDl,
            slopeOrdinal: slopeOrdinal,
            deltaValueInUserUnit: deltaValueInUserUnit,
            urgentLowLimitInMgDl: urgentLowLimitInMgDl,
            lowLimitInMgDl: lowLimitInMgDl,
            highLimitInMgDl: highLimitInMgDl,
            urgentHighLimitInMgDl: urgentHighLimitInMgDl,
            keepAliveIsDisabled: keepAliveIsDisabled,
            liveDataIsEnabled: liveDataIsEnabled
        )
        
        if let stateData = try? JSONEncoder().encode(complicationSharedUserDefaultsModel) {
            sharedUserDefaults.set(stateData, forKey: "complicationSharedUserDefaults.\(Bundle.main.mainAppBundleIdentifier)")
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        
        lastComplicationUpdateTimeStamp = .now
    }
    
    private func generateDebugString() -> String {
        var debugString = "Last state: \(Date().formatted(date: .omitted, time: .standard))"
        
        if let bgReadingDate = bgReadingDate() {
            debugString += "\nBG updated: \(bgReadingDate.formatted(date: .omitted, time: .standard))"
        } else {
            debugString += "\nBG updated: ---"
        }
        
        debugString += "\nBG values: \(bgReadingValues.count)"
        debugString += "\nComp enabled: \(liveDataIsEnabled.description)"
        debugString += "\nComp remain: \(remainingComplicationUserInfoTransfers.description)/50"
        
        if !isMaster {
            debugString += "\nFollower conn.: \(timeStampOfLastFollowerConnection.formatted(date: .omitted, time: .standard))"
            if followerBackgroundKeepAliveType == .heartbeat {
                debugString += "\nLast heartbeat: \(timeStampOfLastHeartBeat.formatted(date: .omitted, time: .standard))"
            }
        }
        
        debugString += "\nScreen width: \(Int(WKInterfaceDevice.current().screenBounds.size.width))"
        debugString += "\niOS app: Idle"
        
        return debugString
    }
}

// MARK: - WCSessionDelegate
extension WatchStateModel: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated {
            print("WCSession activated. Putem porni Extended Runtime Session.")
            requestWatchStateUpdate()
            
            // Pornește acum sesiunea extinsă, când aplicația e sigur activă
            startExtendedSessionIfNeeded()
        } else {
            print("WCSession nu e activat. Stare: \(activationState.rawValue)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        // Poți vedea dacă watch-ul devine reachable / unreachable
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Tratează mesaje sub formă de Data (dacă folosești așa ceva)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let watchStateAsDictionary = message["watchState"] as? [String : Any] {
            DispatchQueue.main.async {
                self.processWatchStateFromDictionary(dictionary: watchStateAsDictionary)
                self.requestingDataIconColor = ConstantsAppleWatch.requestingDataIconColorActive
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.requestingDataIconColor = ConstantsAppleWatch.requestingDataIconColorInactive
                }
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        if let watchStateAsDictionary = userInfo["watchState"] as? [String : Any] {
            DispatchQueue.main.async {
                self.processWatchStateFromDictionary(dictionary: watchStateAsDictionary)
            }
        }
    }
    
    
    // MARK: - WKExtendedRuntimeSessionDelegate
    
    public func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Pornim / repornim sesiunea extinsă dacă vrem să rămână activă în background
                startExtendedSessionIfNeeded()
                
                // După ce ai făcut ce trebuie, marchezi task-ul complet
                backgroundTask.setTaskCompletedWithSnapshot(false)
                
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    // Metodă de pornire "sigură" a sesiunii extinse
    func startExtendedSessionIfNeeded() {
        // REVIZUIRE: Adăugăm un switch care să trateze toate stările posibile
        switch extendedSession.state {
        case .notStarted:
            print("[startExtendedSessionIfNeeded] WKExtendedRuntimeSession este .notStarted. Apelăm extendedSession.start().")
            extendedSession.start()
            
        case .scheduled:
            // Aici apare mesajul când deja a fost planificată pornirea
            print("[startExtendedSessionIfNeeded] Sesiunea este .scheduled — nu mai apelăm start() încă o dată.")
            
        case .running:
            // Sesiunea rulează deja
            print("[startExtendedSessionIfNeeded] Sesiunea este deja .running — nu mai apelăm start().")
            
        case .invalid:
            // Eventual decizi să o repornești dacă e invalidată, dar numai dacă e logic
             extendedSession = WKExtendedRuntimeSession()
             extendedSession.delegate = self
             extendedSession.start()
            print("[startExtendedSessionIfNeeded] Sesiunea este .invalidated — decide dacă vrei să o reinițializezi.")
            
        @unknown default:
            print("[startExtendedSessionIfNeeded] Sesiunea are o stare necunoscută. Nu apelăm start().")
        }
    }
    
    
    func startExtendedSessionManually() {
        startExtendedSessionIfNeeded()
    }
    
    @objc func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("WKExtendedRuntimeSession a pornit! Stare curentă: \(extendedRuntimeSession.state.rawValue)")
    }

    @objc func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("WKExtendedRuntimeSession va expira curând. Stare curentă: \(extendedRuntimeSession.state.rawValue)")
    }
    
    @objc(extendedRuntimeSession:didInvalidateWithReason:error:)
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                error: Error?) {
        print("WKExtendedRuntimeSession a fost invalidată. Motiv: \(reason.rawValue). Eroare: \(String(describing: error))")
 
    }

   
    
    
}
