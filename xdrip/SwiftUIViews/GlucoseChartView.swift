//
//  GlucoseChartView.swift
//  xdrip
//
//  Created by Paul Plant on 13/01/2024.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Charts
import SwiftUI
import Foundation

struct GlucoseChartView: View {
    
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    
    let chartType: GlucoseChartType // shortened to chartType to make reading easier below
    let isMgDl: Bool
    let urgentLowLimitInMgDl: Double
    let lowLimitInMgDl: Double
    let highLimitInMgDl: Double
    let urgentHighLimitInMgDl: Double
    let liveActivityType: LiveActivityType
    let hoursToShow: Double
    let glucoseCircleDiameter: Double
    let chartHeight: Double
    let chartWidth: Double
    let showHighContrast: Bool
    
    init(
        glucoseChartType: GlucoseChartType,
        bgReadingValues: [Double]?,
        bgReadingDates: [Date]?,
        isMgDl: Bool,
        urgentLowLimitInMgDl: Double,
        lowLimitInMgDl: Double,
        highLimitInMgDl: Double,
        urgentHighLimitInMgDl: Double,
        liveActivityType: LiveActivityType?,
        hoursToShowScalingHours: Double?,
        glucoseCircleDiameterScalingHours: Double?,
        overrideChartHeight: Double?,
        overrideChartWidth: Double?,
        highContrast: Bool?
    ) {
        
        self.chartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivityType = liveActivityType ?? .normal
        self.showHighContrast = highContrast ?? false
        
        // hoursToShow can be overridden for zoom, otherwise it is derived
        self.hoursToShow = hoursToShowScalingHours ?? chartType.hoursToShow(liveActivityType: self.liveActivityType)
        
        self.chartHeight = overrideChartHeight ?? chartType.viewSize(liveActivityType: self.liveActivityType).height
        self.chartWidth = overrideChartWidth ?? chartType.viewSize(liveActivityType: self.liveActivityType).width
        
        // Determine the diameter of data points
        self.glucoseCircleDiameter =
            chartType.glucoseCircleDiameter(liveActivityType: self.liveActivityType)
            * ((glucoseCircleDiameterScalingHours ?? self.hoursToShow) / self.hoursToShow)
        
        self.bgReadingValues = []
        self.bgReadingDates = []
        
        // Filter only the data that falls within the hoursToShow interval
        if let bgReadingValues = bgReadingValues, let bgReadingDates = bgReadingDates {
            var index = 0
            for _ in bgReadingValues {
                if bgReadingDates[index] > Date().addingTimeInterval(-hoursToShow * 60 * 60) {
                    self.bgReadingValues.append(bgReadingValues[index])
                    self.bgReadingDates.append(bgReadingDates[index])
                }
                index += 1
            }
        }
        
        // ─────────────────────────────────────────────────────────────────────
        //  Integration: remove outliers, fill in missing data, then smooth
        // ─────────────────────────────────────────────────────────────────────
        
        // 1) Remove outliers
        var (fDates, fValues) = removeOutliersFromPairs(
            dates: self.bgReadingDates,
            values: self.bgReadingValues,
            sigma: 3.0
        )
        
        // 2) Fill missing data every 1 minute
        (fDates, fValues) = fillMissingDates(
            dates: fDates,
            values: fValues,
            intervalInMinutes: 1
        )
        
        // 3) Smoothing (moving average) - adjust windowSize for more/less smoothing
        fValues = smoothValues(fValues, windowSize: 3)
        
        // Update arrays
        self.bgReadingDates = fDates
        self.bgReadingValues = fValues
    }
    
    /// Blood glucose color based on user-defined limits
    func bgColor(bgValueInMgDl: Double) -> Color {
        if chartType != .widgetSystemSmallStandBy || !showHighContrast {
            if bgValueInMgDl >= urgentHighLimitInMgDl || bgValueInMgDl <= urgentLowLimitInMgDl {
                return .red
            } else if bgValueInMgDl >= highLimitInMgDl || bgValueInMgDl <= lowLimitInMgDl {
                return .yellow
            } else {
                return .green
            }
        } else {
            return .white
        }
    }
    
    // Example of generating some values for the X axis (not fully used below, but we keep it)
    func xAxisValues() -> [Date] {
        let startDate: Date = bgReadingDates.last ?? Date().addingTimeInterval(-hoursToShow * 3600)
        let endDate: Date = Date()
        
        let amountOfFullHours = Int(ceil(endDate.timeIntervalSince(startDate) / 3600))
        let mappingArray = Array(1...amountOfFullHours)
        let intervalBetweenAxisValues: Int = chartType.intervalBetweenAxisValues(liveActivityType: liveActivityType)
        
        let startDateLower = Date(timeIntervalSinceReferenceDate:
                                    (startDate.timeIntervalSinceReferenceDate / 3600.0).rounded(.down) * 3600.0)
        
        let xAxisValues: [Date] = stride(
            from: 1,
            to: mappingArray.count + 1,
            by: intervalBetweenAxisValues
        ).map {
            startDateLower.addingTimeInterval(Double($0)*3600)
        }
        
        return xAxisValues
    }
    
    var body: some View {
        // Determine Y domain based on smoothed values
        let domain = (
            min(
                (bgReadingValues.min() ?? 40),
                urgentLowLimitInMgDl
            ) - 6
        ) ... (
            max(
                (bgReadingValues.max() ?? urgentHighLimitInMgDl),
                urgentHighLimitInMgDl
            ) + 6
        )
        
        let yAxisLineSize = chartType.yAxisLineSize()
        
        Chart {
            // urgentLow line
            if domain.contains(urgentLowLimitInMgDl) {
                RuleMark(y: .value("", urgentLowLimitInMgDl))
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: yAxisLineSize,
                            dash: [2 * yAxisLineSize, 6 * yAxisLineSize]
                        )
                    )
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }
            
            // urgentHigh line
            if domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: yAxisLineSize,
                            dash: [2 * yAxisLineSize, 6 * yAxisLineSize]
                        )
                    )
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }

            // Low line
            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: yAxisLineSize,
                            dash: [4 * yAxisLineSize, 3 * yAxisLineSize]
                        )
                    )
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }
            
            // High line
            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(
                        StrokeStyle(
                            lineWidth: yAxisLineSize,
                            dash: [4 * yAxisLineSize, 3 * yAxisLineSize]
                        )
                    )
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }
            
            // Phantom point at the start
            PointMark(
                x: .value("Time", Date().addingTimeInterval(-hoursToShow * 3600)),
                y: .value("BG", 100)
            )
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)

            // Show data points
            ForEach(bgReadingValues.indices, id: \.self) { index in
                PointMark(
                    x: .value("Time", bgReadingDates[index]),
                    y: .value("BG", bgReadingValues[index])
                )
                .symbol(Circle())
                .symbolSize(glucoseCircleDiameter)
                .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[index]))
            }
            
            // Phantom point at the end
            PointMark(
                x: .value("Time", Date().addingTimeInterval(5 * 60)),
                y: .value("BG", 100)
            )
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: chartType.xAxisLabelEveryHours())) {
                if let value = $0.as(Date.self) {
                    if chartType.xAxisShowLabels() {
                        AxisValueLabel {
                            let shouldHideLabel =
                                abs(Date().distance(to: value))
                                    < ConstantsGlucoseChartSwiftUI.xAxisLabelFirstClippingInMinutes
                                ||
                                abs(Date().addingTimeInterval(-hoursToShow * 3600).distance(to: value))
                                    < ConstantsGlucoseChartSwiftUI.xAxisLabelLastClippingInMinutes
                            
                            Text(!shouldHideLabel ? value.formatted(.dateTime.hour()) : "")
                                .foregroundStyle(Color(.colorSecondary))
                                .font(.footnote)
                                .offset(
                                    x: chartType.xAxisLabelOffsetX(),
                                    y: chartType.xAxisLabelOffsetY()
                                )
                        }
                    }
                    
                    AxisGridLine()
                        .foregroundStyle(ConstantsGlucoseChartSwiftUI.xAxisGridLineColor)
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [lowLimitInMgDl, highLimitInMgDl]) {
                if let value = $0.as(Double.self) {
                    AxisValueLabel {
                        Text(value.mgDlToMmolAndToString(mgDl: isMgDl))
                            .foregroundStyle(Color(.colorPrimary))
                            .font(.footnote)
                            .offset(
                                x: chartType.yAxisLabelOffsetX(),
                                y: chartType.yAxisLabelOffsetY()
                            )
                    }
                }
            }
            
            AxisMarks(values: [urgentLowLimitInMgDl, urgentHighLimitInMgDl]) {
                if let value = $0.as(Double.self) {
                    AxisValueLabel {
                        Text(value.mgDlToMmolAndToString(mgDl: isMgDl))
                            .foregroundStyle(Color(.colorSecondary))
                            .font(.footnote)
                            .offset(
                                x: chartType.yAxisLabelOffsetX(),
                                y: chartType.yAxisLabelOffsetY()
                            )
                    }
                }
            }
        }
        .if({ return chartType.frame() ? true : false }()) { view in
            view.frame(width: chartWidth, height: chartHeight)
        }
        .if({ return chartType.aspectRatio().enable ? true : false }()) { view in
            view.aspectRatio(
                chartType.aspectRatio().aspectRatio,
                contentMode: chartType.aspectRatio().contentMode
            )
        }
        .if({ return chartType.padding().enable ? true : false }()) { view in
            view.padding(chartType.padding().padding)
        }
        .chartYAxis(chartType.yAxisShowLabels())
        .chartYScale(domain: domain)
        .background(chartType.backgroundColor())
        .clipShape(RoundedRectangle(cornerRadius: chartType.cornerRadius()))
    }
}

// ─────────────────────────────────────────────────────────────────────
//  Helper functions for outliers, interpolation, and smoothing
// ─────────────────────────────────────────────────────────────────────

/// Eliminates outliers based on the range [mean - sigma*stdev, mean + sigma*stdev].
private func removeOutliersFromPairs(
    dates: [Date],
    values: [Double],
    sigma: Double = 3.0
) -> ([Date], [Double]) {
    guard !dates.isEmpty, dates.count == values.count else {
        return ([], [])
    }
    
    let mean = values.reduce(0, +) / Double(values.count)
    let squaredDiffs = values.map { pow($0 - mean, 2) }
    let stdev = sqrt(squaredDiffs.reduce(0, +) / Double(values.count))
    
    let lowerBound = mean - sigma * stdev
    let upperBound = mean + sigma * stdev
    
    var filteredDates: [Date] = []
    var filteredValues: [Double] = []
    
    for i in 0..<dates.count {
        let val = values[i]
        if val >= lowerBound && val <= upperBound {
            filteredDates.append(dates[i])
            filteredValues.append(val)
        }
    }
    
    return (filteredDates, filteredValues)
}

/// Generates data at a fixed interval (e.g. every 5 minutes) and linearly interpolates missing values.
private func fillMissingDates(
    dates: [Date],
    values: [Double],
    intervalInMinutes: Int = 5
) -> ([Date], [Double]) {
    // Sort the data if they're not already sorted
    let combined = zip(dates, values).sorted { $0.0 < $1.0 }
    let sortedDates = combined.map { $0.0 }
    let sortedValues = combined.map { $0.1 }

    guard !sortedDates.isEmpty else { return ([], []) }
    
    let startDate = sortedDates.first!
    let endDate = sortedDates.last!
    
    var generatedDates: [Date] = []
    var generatedValues: [Double] = []
    
    var currentDate = startDate
    while currentDate <= endDate {
        generatedDates.append(currentDate)
        
        if let interpolVal = interpolateValue(
            for: currentDate,
            inDates: sortedDates,
            inValues: sortedValues
        ) {
            generatedValues.append(interpolVal)
        } else {
            // fallback to 0 or another value
            generatedValues.append(0)
        }
        
        currentDate = currentDate.addingTimeInterval(Double(intervalInMinutes * 60))
    }
    
    return (generatedDates, generatedValues)
}

/// Linear interpolation between two points (Date & Double).
private func interpolateValue(
    for targetDate: Date,
    inDates dates: [Date],
    inValues values: [Double]
) -> Double? {
    // index of the last point <= targetDate
    guard let firstIndex = dates.lastIndex(where: { $0 <= targetDate }),
          let secondIndex = dates.firstIndex(where: { $0 >= targetDate }) else {
        return nil
    }
    
    // If it's exactly a known point
    if dates[firstIndex] == targetDate {
        return values[firstIndex]
    }
    if dates[secondIndex] == targetDate {
        return values[secondIndex]
    }
    
    // If it's the same index, there's no space for interpolation
    if firstIndex == secondIndex {
        return values[firstIndex]
    }
    
    let dateA = dates[firstIndex]
    let dateB = dates[secondIndex]
    let valA = values[firstIndex]
    let valB = values[secondIndex]
    
    let total = dateB.timeIntervalSince(dateA)
    let partial = targetDate.timeIntervalSince(dateA)
    if total == 0 { return valA } // theoretical fallback
    
    let ratio = partial / total
    let interpVal = valA + ratio * (valB - valA)
    return interpVal
}

/// Smoothing using a moving average with a ±windowSize window.
/// Example: windowSize=3 => ~7 points (3 before, 1 current, 3 after).
private func smoothValues(
    _ values: [Double],
    windowSize: Int
) -> [Double] {
    guard !values.isEmpty, windowSize > 0 else { return values }
    
    var smoothed: [Double] = Array(repeating: 0, count: values.count)
    
    for i in 0..<values.count {
        let startIndex = max(0, i - windowSize)
        let endIndex = min(values.count - 1, i + windowSize)
        
        var sum = 0.0
        var count = 0
        
        for j in startIndex...endIndex {
            sum += values[j]
            count += 1
        }
        smoothed[i] = sum / Double(count)
    }
    
    return smoothed
}
