//
//  LA.swift
//  xdrip
//
//  Created by Marian Dugaesescu on 26/12/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import WidgetKit
import SwiftUI

struct SmartStackLiveActivityContentView: View {
    @Environment(\.widgetFamily) var activityFamily
    @Environment(\.colorScheme) var colorScheme
    @State var context: ActivityViewContext<XDripWidgetAttributes>
    func overrideChartHeight() -> Double {
        let height = activityFamily.toSidebarRowSize == .small ? ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewHeightWatchAccessoryRectangular

        return height
    }
    
    func overrideChartWidth() -> Double {
        return activityFamily.toSidebarRowSize == .small ? ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangularSmall : ConstantsGlucoseChartSwiftUI.viewWidthWatchAccessoryRectangular
    }
    
    var body: some View {
        if context.state.liveActivityType == .minimal {
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
                        Spacer()
                        Text(context.state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.2)
                            .lineLimit(1)
                            .padding(.top, 10)
                    }
                    .padding([.horizontal, .top], 10)
                    
                    //     Spacer()
                    
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
                        // 1) Header cu BG Value, Arrow, Delta
                        HStack(alignment: .lastTextBaseline, spacing: 20) {
                            Text("\(context.state.bgValueStringInUserChosenUnit) \(context.state.trendArrow())")
                                .font(.system(size: activityFamily.toSidebarRowSize == .small ? 24 : 32))
                                .fontWeight(.bold)
                                .foregroundStyle(context.state.bgTextColor())
                                .minimumScaleFactor(0.2)
                                .lineLimit(1)
                       
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(context.state.deltaChangeStringInUserChosenUnit())
                                    .font(.system(size: activityFamily.toSidebarRowSize == .small ? 4 : 12))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(context.state.deltaChangeTextColor())
                                    .lineLimit(1)
                                
                                Text(context.state.bgUnitString)
                                    .font(.system(size: activityFamily.toSidebarRowSize == .small ? 4 : 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, activityFamily.toSidebarRowSize == .small ? 2 : 4)
                        .padding(.bottom, 2)
                   //     .padding([.leading, .trailing], 2)
                        
                        // 2) Chart adaptat la dimensiunea ceasului
                        GlucoseChartView(glucoseChartType: .watchAccessoryRectangular, bgReadingValues: entry.widgetState.bgReadingValues, bgReadingDates: entry.widgetState.bgReadingDates, isMgDl: entry.widgetState.isMgDl, urgentLowLimitInMgDl: entry.widgetState.urgentLowLimitInMgDl, lowLimitInMgDl: entry.widgetState.lowLimitInMgDl, highLimitInMgDl: entry.widgetState.highLimitInMgDl, urgentHighLimitInMgDl: entry.widgetState.urgentHighLimitInMgDl, liveActivityType: nil, hoursToShowScalingHours: nil, glucoseCircleDiameterScalingHours: nil, overrideChartHeight: entry.widgetState.overrideChartHeight(), overrideChartWidth: entry.widgetState.overrideChartWidth(), highContrast: nil)
                        // 3) Footer
                        HStack {
                            Text(context.state.dataSourceDescription)
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.colorSecondary)
                                .font(.system(size: activityFamily.toSidebarRowSize == .small ? 4 : 12))
                            
                            Spacer()
                            
                            Text("\(context.state.bgReadingDate?.formatted(date: .omitted, time: .shortened) ?? "--:--")")
                                .font(.caption)
                                .foregroundStyle(.colorTertiary)
                                .font(.system(size: activityFamily.toSidebarRowSize == .small ? 4 : 12))
                        }
                        .padding(.top, 4)
                     //   .padding(.bottom, 1)
                        .padding([.leading, .trailing], 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(0)
                } // GeometryReader
            }
        }
    }
}

        
extension WidgetFamily {
    var toSidebarRowSize: SidebarRowSize {
        switch self {
        case .systemSmall:  return .small
        case .systemMedium: return .medium
        case .systemLarge:  return .large
        default:            return .medium // fallback
        }
    }
}
