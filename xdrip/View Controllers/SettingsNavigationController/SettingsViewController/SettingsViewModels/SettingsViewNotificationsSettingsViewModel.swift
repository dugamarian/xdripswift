import UIKit
import OSLog
import ActivityKit

fileprivate enum Setting: Int, CaseIterable {
    
    /// should reading be shown in notification
    case showReadingInNotification = 0
    
    /// - minimum time between two readings, for which notification should be created (in minutes)
    /// - except if there's been a disconnect, in that case this value is not taken into account
    case notificationInterval = 1
    
    /// show live activities type, if any
    case liveActivityType = 2
    
    /// show reading in app badge
    case showReadingInAppBadge = 3
    
    /// if reading is shown in app badge, should value be multiplied with 10 yes or no
    case multipleAppBadgeValueWith10 = 4
    
    /// show live activity for watchOS
    case liveActivityForWatcOS = 5
}

/// conforms to SettingsViewModelProtocol for all general settings in the first sections screen
class SettingsViewNotificationsSettingsViewModel: NSObject, SettingsViewModelProtocol {
    
    // MARK: - Properties
    
    /// for trace
    private let log = OSLog(
        subsystem: ConstantsLog.subSystem,
        category: ConstantsLog.categorySettingsViewDataSourceSettingsViewModel
    )
    
    /// Clousure folosit pentru reîmprospătarea secțiunii
    var sectionReloadClosure: (() -> Void)?
    
    /// Array-ul de setări pe care le afișăm efectiv în UI,
    /// în funcție de logica dorită (de ex. dacă folosim mg/dL, dacă e activat showReadingInAppBadge etc.).
    /// Eliminăm .multipleAppBadgeValueWith10 dacă unitatea este mg/dl SAU dacă showReadingInAppBadge este dezactivat.
    private var displayedSettings: [Setting] {
        var all = Setting.allCases
        let removeMultipleAppBadgeIfNeeded =
            UserDefaults.standard.bloodGlucoseUnitIsMgDl
            || !UserDefaults.standard.showReadingInAppBadge
        
        if removeMultipleAppBadgeIfNeeded {
            all.removeAll { $0 == .multipleAppBadgeValueWith10 }
        }
        return all
    }
    
    // MARK: - Init
    
    override init() {
        super.init()
        addObservers()
    }
    
    // MARK: - SettingsViewModelProtocol stubs
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {
        // not used here
    }
    
    func storeSectionReloadClosure(sectionReloadClosure: @escaping (() -> Void)) {
        self.sectionReloadClosure = sectionReloadClosure
    }
    
    func storeUIViewController(uIViewController: UIViewController) {
        // not used here
    }
    
    func storeMessageHandler(messageHandler: ((String, String) -> Void)) {
        // not used here
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        // toate rândurile sunt activate la acest exemplu
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        let setting = self.setting(at: index)
        
        switch setting {
        case .showReadingInNotification,
             .showReadingInAppBadge,
             .multipleAppBadgeValueWith10:
            return .nothing
            
        case .notificationInterval:
            return SettingsSelectedRowAction.askText(
                title: Texts_SettingsView.settingsviews_IntervalTitle,
                message: Texts_SettingsView.settingsviews_IntervalMessage,
                keyboardType: .numberPad,
                text: UserDefaults.standard.notificationInterval.description,
                placeHolder: "0",
                actionTitle: nil,
                cancelTitle: nil,
                actionHandler: { (interval: String) in
                    if let interval = Int(interval) {
                        UserDefaults.standard.notificationInterval = interval
                    }
                },
                cancelHandler: nil,
                inputValidator: nil
            )
            
        case .liveActivityType:
            // live activities pot fi folosite doar în Master mode,
            // sau dacă folowerBackgroundKeepAliveType == .heartbeat
            if UserDefaults.standard.isMaster
                || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
                
                var data = [String]()
                var selectedRow: Int?
                var idx = 0
                let currentLiveActivityType = UserDefaults.standard.liveActivityType
                
                // populăm data cu descrieri
                for liveActivityType in LiveActivityType.allCasesForList {
                    data.append(liveActivityType.description)
                    
                    if liveActivityType == currentLiveActivityType {
                        selectedRow = idx
                    }
                    
                    idx += 1
                }
                
                return .selectFromList(
                    title: Texts_SettingsView.labelLiveActivityType,
                    data: data,
                    selectedRow: selectedRow,
                    actionTitle: nil,
                    cancelTitle: nil,
                    actionHandler: { (newIndex: Int) in
                        
                        let oldLiveActivityType = UserDefaults.standard.liveActivityType
                        if newIndex != selectedRow {
                            UserDefaults.standard.liveActivityType =
                                LiveActivityType(forRowAt: newIndex) ?? .disabled
                            
                            let newLiveActivityType = UserDefaults.standard.liveActivityType
                            trace(
                                "Live activity type was changed from '%{public}@' to '%{public}@'",
                                log: self.log,
                                category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel,
                                type: .info,
                                oldLiveActivityType.description,
                                newLiveActivityType.description
                            )
                        }
                    },
                    cancelHandler: nil,
                    didSelectRowHandler: nil
                )
                
            } else {
                return .showInfoText(
                    title: Texts_SettingsView.labelLiveActivityType,
                    message: Texts_SettingsView.liveActivityDisabledInFollowerModeMessage,
                    actionHandler: {}
                )
            }
            
        case .liveActivityForWatcOS:
            // la fel, poate fi folosit doar în Master mode
            if UserDefaults.standard.isMaster
                || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
                
                var data = [String]()
                var selectedRow: Int?
                var idx = 0
                let currentLiveActivityTypeForWatchOS =
                    UserDefaults.standard.liveActivityTypeForWatchOS
                
                for liveActivityTypeForWatchOS in LiveActivityTypeForWatchOS.allCasesForList {
                    data.append(liveActivityTypeForWatchOS.description)
                    
                    if liveActivityTypeForWatchOS == currentLiveActivityTypeForWatchOS {
                        selectedRow = idx
                    }
                    idx += 1
                }
                
                return .selectFromList(
                    title: Texts_SettingsView.labelLiveActivityType,
                    data: data,
                    selectedRow: selectedRow,
                    actionTitle: nil,
                    cancelTitle: nil,
                    actionHandler: { (newIndex: Int) in
                        
                        let oldLiveActivityType = UserDefaults.standard.liveActivityTypeForWatchOS
                        if newIndex != selectedRow {
                            UserDefaults.standard.liveActivityTypeForWatchOS =
                                LiveActivityTypeForWatchOS(forRowAt: newIndex) ?? .disabled
                            
                            let newLiveActivityType =
                                UserDefaults.standard.liveActivityTypeForWatchOS
                            
                            trace(
                                "Live activity type for watchOS was changed from '%{public}@' to '%{public}@'",
                                log: self.log,
                                category: ConstantsLog.categorySettingsViewNotificationsSettingsViewModel,
                                type: .info,
                                oldLiveActivityType.description,
                                newLiveActivityType.description
                            )
                        }
                    },
                    cancelHandler: nil,
                    didSelectRowHandler: nil
                )
                
            } else {
                return .showInfoText(
                    title: Texts_SettingsView.labelLiveActivityTypeForWatch,
                    message: Texts_SettingsView.liveActivityDisabledInFollowerModeMessage,
                    actionHandler: {}
                )
            }
        }
    }
    
    func sectionTitle() -> String? {
        return ConstantsSettingsIcons.notificationsSettingsIcon
            + " "
            + Texts_SettingsView.sectionTitleNotifications
    }
    
    func numberOfRows() -> Int {
        // Pur și simplu returnăm numărul de elemente pe care le afișăm
        return displayedSettings.count
    }
    
    func settingsRowText(index: Int) -> String {
        let setting = self.setting(at: index)
        
        switch setting {
        case .showReadingInNotification:
            return Texts_SettingsView.showReadingInNotification
        case .notificationInterval:
            return Texts_SettingsView.settingsviews_IntervalTitle
        case .liveActivityType:
            return Texts_SettingsView.labelLiveActivityType
        case .liveActivityForWatcOS:
            return Texts_SettingsView.labelLiveActivityTypeForWatch
        case .showReadingInAppBadge:
            return Texts_SettingsView.labelShowReadingInAppBadge
        case .multipleAppBadgeValueWith10:
            return Texts_SettingsView.multipleAppBadgeValueWith10
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        let setting = self.setting(at: index)
        switch setting {
        case .showReadingInNotification,
             .showReadingInAppBadge,
             .multipleAppBadgeValueWith10:
            return .none
            
        case .notificationInterval:
            return .disclosureIndicator
            
        case .liveActivityType:
            return (UserDefaults.standard.isMaster
                    || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat)
                ? .disclosureIndicator : .none
            
        case .liveActivityForWatcOS:
            return (UserDefaults.standard.isMaster
                    || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat)
                ? .disclosureIndicator : .none
        }
    }
    
    func detailedText(index: Int) -> String? {
        let setting = self.setting(at: index)
        
        switch setting {
        case .showReadingInNotification,
             .showReadingInAppBadge,
             .multipleAppBadgeValueWith10:
            return nil
            
        case .notificationInterval:
            return UserDefaults.standard.notificationInterval.description
            
        case .liveActivityType:
            if UserDefaults.standard.isMaster
                || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
                return UserDefaults.standard.liveActivityType.description
            } else {
                return Texts_SettingsView.liveActivityDisabledInFollowerMode
            }
            
        case .liveActivityForWatcOS:
            if UserDefaults.standard.isMaster
                || UserDefaults.standard.followerBackgroundKeepAliveType == .heartbeat {
                return UserDefaults.standard.liveActivityTypeForWatchOS.description
            } else {
                return Texts_SettingsView.liveActivityDisabledInFollowerMode
            }
        }
    }
    
    func uiView(index: Int) -> UIView? {
        let setting = self.setting(at: index)
        
        switch setting {
        case .showReadingInNotification:
            return UISwitch(
                isOn: UserDefaults.standard.showReadingInNotification,
                action: { (isOn: Bool) in
                    UserDefaults.standard.showReadingInNotification = isOn
                }
            )
            
        case .showReadingInAppBadge:
            return UISwitch(
                isOn: UserDefaults.standard.showReadingInAppBadge,
                action: { (isOn: Bool) in
                    UserDefaults.standard.showReadingInAppBadge = isOn
                }
            )
            
        case .multipleAppBadgeValueWith10:
            return UISwitch(
                isOn: UserDefaults.standard.multipleAppBadgeValueWith10,
                action: { (isOn: Bool) in
                    UserDefaults.standard.multipleAppBadgeValueWith10 = isOn
                }
            )
            
        case .notificationInterval,
             .liveActivityType,
             .liveActivityForWatcOS:
            return nil
        }
    }
    
    // MARK: - Observers
    
    private func addObservers() {
        UserDefaults.standard.addObserver(
            self,
            forKeyPath: UserDefaults.Key.followerBackgroundKeepAliveType.rawValue,
            options: .new,
            context: nil
        )
    }
    
    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey : Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard
            let keyPath = keyPath,
            let keyPathEnum = UserDefaults.Key(rawValue: keyPath)
        else {
            return
        }
        
        switch keyPathEnum {
        case .followerBackgroundKeepAliveType:
            // rulăm în main thread pt. a evita erori de acces
            DispatchQueue.main.async {
                self.sectionReloadClosure?()
            }
        default:
            break
        }
    }
    
    // MARK: - Helper
    
    /// Returnează elementul Setting care se află la index-ul listat de displayedSettings
    private func setting(at index: Int) -> Setting {
        guard index >= 0, index < displayedSettings.count else {
            fatalError("Index \(index) out of range for displayedSettings")
        }
        return displayedSettings[index]
    }
}
