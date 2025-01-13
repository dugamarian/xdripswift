//
//  XDripWidgetLiveActivity.swift
//  XDripWidget
//
//  Created by Paul Plant on 29/12/23.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI


func isAlarm(glucoseValue: Double, context: ActivityViewContext<XDripWidgetAttributes>) -> Bool {
    return (glucoseValue < Double(context.state.lowLimitInMgDl)) || (glucoseValue > Double(context.state.highLimitInMgDl))
}

func relativeDateText(_ date: Date?) -> some View {
    let dateToUse = date ?? Date()
    let isOlderThan10Minutes = Date().timeIntervalSince(dateToUse) > 600

    return Text(dateToUse, style: .relative)
        .font(.system(size: 15))
        .foregroundStyle(isOlderThan10Minutes ? Color.red : Color.primary)
        .minimumScaleFactor(0.2)
        .lineLimit(1)
        .padding(.top, 10)
}

struct XDripWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: XDripWidgetAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 15) {
                        Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                            .font(.system(size: 90))
                            .bold()
                            .foregroundStyle(context.state.bgTextColor())
                        
                        Text("Last reading at \(context.state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                            .font(.system(size: 24))
                            .foregroundStyle(.colorTertiary)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            } compactLeading: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                        .font(.system(size: 250))
                        .bold()
                        .foregroundStyle(context.state.bgTextColor())
                        .minimumScaleFactor(0.1)
                }
            } compactTrailing: {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.deltaChangeStringInUserChosenUnit())
                        .font(.system(size: 180))
                        .fontWeight(.semibold)
                        .foregroundStyle(context.state.deltaChangeTextColor())
                        .minimumScaleFactor(0.1)
                    
                }
            } minimal: {
                VStack(spacing: 2) {
                    Text("\(context.state.bgValueStringInUserChosenUnit)")
                        .font(.system(size: 24))
                        .bold()
                        .foregroundStyle(context.state.bgTextColor())
                        .minimumScaleFactor(0.1)
                }
            }
            .widgetURL(URL(string: "xdripswift"))
            .keylineTint(context.state.bgTextColor())
        }
        .extraFamilies()
    }
}

struct XDripWidgetLiveActivity_Previews: PreviewProvider {
    static func bgDateArray() -> [Date] {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-3600 * 12)
        var currentDate = startDate
        var dateArray: [Date] = []

        while currentDate < endDate {
            dateArray.append(currentDate)
            currentDate = currentDate.addingTimeInterval(60 * 5)
        }
        return dateArray
    }

    static func bgValueArray() -> [Double] {
        var bgValueArray: [Double] = Array(repeating: 0, count: 144)
        var currentValue: Double = 100
        var increaseValues = true

        for index in bgValueArray.indices {
            let randomValue = Double(Int.random(in: -10..<10))
            
            if currentValue < 80 {
                increaseValues = true
                bgValueArray[index] = currentValue + abs(randomValue)
            } else if currentValue > 160 {
                increaseValues = false
                bgValueArray[index] = currentValue - abs(randomValue)
            } else {
                bgValueArray[index] = currentValue + (increaseValues ? randomValue : -randomValue)
            }
            currentValue = bgValueArray[index]
        }
        return bgValueArray
    }

    static let attributes = XDripWidgetAttributes()

    static let contentState = XDripWidgetAttributes.ContentState(
        bgReadingValues: bgValueArray(),
        bgReadingDates: bgDateArray(),
        isMgDl: true,
        slopeOrdinal: 5,
        deltaValueInUserUnit: -2,
        urgentLowLimitInMgDl: 70,
        lowLimitInMgDl: 80,
        highLimitInMgDl: 140,
        urgentHighLimitInMgDl: 180,
        liveActivityType: .large,
        dataSourceDescription: "Dexcom G6",
        liveActivityForWatchOS: .withChartType
    )

    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Compact")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Expanded")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
    }
}

func overrideChartHeight() -> Double {
    let height = isSmallScreen() ? ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangular

    
    return height
}

func overrideChartWidth() -> Double {
    return isSmallScreen() ? ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangular
}



struct LockScreenLiveActivityContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    static let viewWidthWatchApp: CGFloat = 190
    static let viewHeightWatchApp: CGFloat = 90
   
    var body: some View {
        VStack {
            if context.state.liveActivityType == .minimal {
                HStack(alignment: .center) {
                    VStack {
                        Text("\(context.state.bgValueStringInUserChosenUnit) \(context.state.trendArrow())")
                            .font(.system(size: 38))
                            .fontWeight(.bold)
                            .foregroundStyle(context.state.bgTextColForMinimalView())
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(context.state.deltaChangeStringInUserChosenUnit()) \(context.state.bgUnitString)")
                            .foregroundStyle(.secondary)
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                    }
                    Spacer()
                
     
                    Text("Updated \(Text(context.state.bgReadingDate ?? Date(), style: .relative))")
                        .foregroundStyle(.secondary)
                            .opacity(1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                          
                    }
                
                .activityBackgroundTint(.black)
                       
                .padding([.top, .bottom], 10)
                .padding([.leading, .trailing], 55)
                .privacySensitive()
                .foregroundStyle(Color.primary)
                .background(BackgroundStyle.background.opacity(0.8))
                .activityBackgroundTint(.clear)
                

            } else if context.state.liveActivityType == .normal {
                HStack(spacing: 5) {
                                   VStack(spacing: 0) {
                                       Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                                           .font(.system(size: 44))
                                           .bold()
                                           .foregroundStyle(context.state.bgTextColor())
                                           .minimumScaleFactor(0.1)
                                           .lineLimit(1)
                                           .padding(.trailing, 20)
                                       HStack(alignment: .firstTextBaseline, spacing: 4) {
                                           Text(context.state.deltaChangeStringInUserChosenUnit())
                                               .font(.system(size: 20))
                                               .fontWeight(.semibold)
                                               .foregroundStyle(Color.white)
                                               .minimumScaleFactor(0.2)
                                               .lineLimit(1)
                                           Text(context.state.bgUnitString)
                                               .font(.system(size: 15))
                                               .foregroundStyle(.colorTertiary)
                                               .minimumScaleFactor(0.2)
                                               .lineLimit(1)
                                           Text(context.state.bgReadingDate ?? Date(), style: .relative)
                                               .foregroundStyle(.colorTertiary)
                                               .opacity(1)
                                               .lineLimit(1)
                                               .font(.system(size: 15))
                                       }
                                       .padding(.leading, 15)
                                   }
                                   ZStack {
                                       GlucoseChartView(
                                           glucoseChartType: .liveActivity,
                                           bgReadingValues: context.state.bgReadingValues,
                                           bgReadingDates: context.state.bgReadingDates,
                                           isMgDl: context.state.isMgDl,
                                           urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl,
                                           lowLimitInMgDl: context.state.lowLimitInMgDl,
                                           highLimitInMgDl: context.state.highLimitInMgDl,
                                           urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl,
                                           liveActivityType: .normal,
                                           hoursToShowScalingHours: 5,
                                           glucoseCircleDiameterScalingHours: nil,
                                           overrideChartHeight: nil,
                                           overrideChartWidth: nil,
                                           highContrast: nil
                                       )
                                   }
                                   .padding(.trailing, 20)
                               }
                               
                               .activityBackgroundTint(.black)
                               .padding(.top, 14)
                               .padding(.bottom, 12)
                               .padding([.leading, .trailing], 12)
            } else {
                ZStack {
                    VStack(spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 20) {
                         
                            Text("\(context.state.bgValueStringInUserChosenUnit) \(context.state.trendArrow())")
                                .font(.system(size: 32))
                                .fontWeight(.bold)
                                .foregroundStyle(context.state.bgTextColor())
                                .scaledToFill()
                                .minimumScaleFactor(0.2)
                                .lineLimit(1)
                            
                            Spacer()
                        
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(context.state.deltaChangeStringInUserChosenUnit())
                                    .font(.system(size: 28))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(context.state.deltaChangeTextColor())
                                    .lineLimit(1)
                                    
                                Text(context.state.bgUnitString)
                                    .font(.system(size: 28))
                                    .foregroundStyle(.colorTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .padding([.leading, .trailing], 15)
                        
                        GlucoseChartView(
                            glucoseChartType: .liveActivity,
                            bgReadingValues: context.state.bgReadingValues,
                            bgReadingDates: context.state.bgReadingDates,
                            isMgDl: context.state.isMgDl,
                            urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl,
                            lowLimitInMgDl: context.state.lowLimitInMgDl,
                            highLimitInMgDl: context.state.highLimitInMgDl,
                            urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl,
                            liveActivityType: .large,
                            hoursToShowScalingHours: nil,
                            glucoseCircleDiameterScalingHours: nil,
                            overrideChartHeight: nil,
                            overrideChartWidth: nil,
                            highContrast: nil
                        )
                   
                        HStack {
                            Text("Updated \(Text(context.state.bgReadingDate ?? Date(), style: .relative)) ago")
                                .font(.caption)
                                .foregroundStyle(.colorSecondary)
                            
                            Spacer()
                            
                            Text(context.state.dataSourceDescription)
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.colorSecondary)
  
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                        .padding([.leading, .trailing], 15)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(0)
                }
                .activityBackgroundTint(.black)
            }
        }
    }
}

struct EarlierLockScreenLiveActivityContentView: View {
    let context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        LockScreenLiveActivityContentView(context: context)
    }
}

    
@available(iOS 18, *)
struct SmartStackLiveActivityContentView: View {
    @Environment(\.widgetFamily) var activityFamily
    @Environment(\.colorScheme) var colorScheme
    @State var context: ActivityViewContext<XDripWidgetAttributes>
 
    var body: some View {
    
        if context.state.liveActivityForWatchOS == .simpleType {
            ZStack {
                context.state.backgroundWidgetColor()
                    .ignoresSafeArea()
                
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(context.state.deltaChangeStringInUserChosenUnit()) \(context.state.bgUnitString)")
                                .minimumScaleFactor(0.2)
                                .lineLimit(1)
                                .padding(.top, 10)
                            
                        }
                        
                        Text(context.state.bgReadingDate ?? Date(), style: .relative)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                            .padding(.top, 10)
                    }
                    .padding([.horizontal, .top], 10)
  
                    HStack(spacing: 5) {
                        Text(context.state.bgValueStringInUserChosenUnit)
                            .foregroundColor(.white)
                            .font(.system(size: 90))
                            .minimumScaleFactor(0.5)
                            .padding(.bottom, 20)
                        
                        
                        Text(context.state.trendArrow())
                            .font(.system(size: 25))
                            .lineLimit(1)
                            .padding(.bottom, 25)
                        
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                }
            }
        } else {
            ZStack {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Text("\(context.state.bgValueStringInUserChosenUnit)\(context.state.trendArrow())")
                                .font(.system(size: activityFamily.toSidebarRowSize == .small ? 20 : 24))
                                .fontWeight(.bold)
                                .foregroundStyle(context.state.bgTextColor())
                                .lineLimit(1)
                               
                       
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(context.state.deltaChangeStringInUserChosenUnit())
                                    .font(.system(size: activityFamily.toSidebarRowSize == .small ? 20 : 24))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(context.state.deltaChangeTextColor())
                                    .lineLimit(1)
                           
                                Text(context.state.bgReadingDate ?? Date(), style: .relative)
                                    .font(.system(size: activityFamily.toSidebarRowSize == .small ? 10 : 16))
                                    .font(.caption)
                                    .foregroundStyle(Color.primary)
                                
                            }
                        }

                        .padding([.leading, .trailing], 10)
        
                        GlucoseChartView(
                            glucoseChartType: .watchAccessoryRectangular,
                            bgReadingValues: context.state.bgReadingValues,
                            bgReadingDates: context.state.bgReadingDates,
                            isMgDl: context.state.isMgDl,
                            urgentLowLimitInMgDl: context.state.urgentLowLimitInMgDl,
                            lowLimitInMgDl: context.state.lowLimitInMgDl,
                            highLimitInMgDl: context.state.highLimitInMgDl,
                            urgentHighLimitInMgDl: context.state.urgentHighLimitInMgDl,
                            liveActivityType: nil,
                            hoursToShowScalingHours: 5, //6,
                            glucoseCircleDiameterScalingHours: 3, // 1.7,
                            overrideChartHeight: 50, // geo.size.height * 0.50,
                            overrideChartWidth: overrideChartWidth(),
                            highContrast: nil
                        )
                    }
                  //  .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
         //   .activityBackgroundTint(.black)
        }
    }
}

@available(iOS 18.0, *)
struct NewerLockScreenLiveActivityContentView: View {
    @Environment(\.activityFamily) var activityFamily
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        switch activityFamily {
        case .small:
            SmartStackLiveActivityContentView(context: context)
        case .medium:
            LockScreenLiveActivityContentView(context: context)
        @unknown default:
            LockScreenLiveActivityView(context: context)
        }
    }
}

struct LockScreenLiveActivityView: View {
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    
    var body: some View {
        if #available(iOS 18.0, *) {
            NewerLockScreenLiveActivityContentView(context: context)
        } else {
            LockScreenLiveActivityContentView(context: context)
        }
    }
}

extension WidgetFamily {
    var toSidebarRowSize: SidebarRowSize {
        switch self {
        case .systemSmall:  return .small
        case .systemMedium: return .medium
        case .systemLarge:  return .large
        default:            return .medium
        }
    }
}



struct ScreenConstants {
    static let pixelWidthLimitForSmallScreen: CGFloat = 320
}

/// Verifică dacă lățimea ecranului este sub un anumit prag
func isSmallScreen() -> Bool {
    return UIScreen.main.bounds.size.width < ScreenConstants.pixelWidthLimitForSmallScreen
}
