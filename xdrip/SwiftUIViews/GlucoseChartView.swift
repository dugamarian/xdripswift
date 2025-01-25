//
//  GlucoseChartView.swift
//  xdrip
//
//  Created by Paul Plant on 13/01/2024.
//  Copyright © 2023 Johan Degraeve. All rights reserved.

import Charts
import SwiftUI
import Foundation

struct GlucoseChartView: View {
    
    // MARK: - Stored Properties

    // Date + valori
    var bgReadingValues: [Double]
    var bgReadingDates: [Date]
    
    // Parametri chart
    let chartType: GlucoseChartType
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
    
    // MARK: - Initialization
    
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
        // 1) Inițializează proprietăți simple
        self.chartType = glucoseChartType
        self.isMgDl = isMgDl
        self.urgentLowLimitInMgDl = urgentLowLimitInMgDl
        self.lowLimitInMgDl = lowLimitInMgDl
        self.highLimitInMgDl = highLimitInMgDl
        self.urgentHighLimitInMgDl = urgentHighLimitInMgDl
        self.liveActivityType = liveActivityType ?? .normal
        self.showHighContrast = highContrast ?? false
        
        // 2) Determinare "hoursToShow"
        let localHoursToShow = hoursToShowScalingHours
            ?? chartType.hoursToShow(liveActivityType: self.liveActivityType)
        self.hoursToShow = localHoursToShow
        
        // 3) Dimensiuni chart
        self.chartHeight = overrideChartHeight
            ?? chartType.viewSize(liveActivityType: self.liveActivityType).height
        self.chartWidth = overrideChartWidth
            ?? chartType.viewSize(liveActivityType: self.liveActivityType).width
        
        // 4) Diametrul punctelor
        let diameterBase = chartType.glucoseCircleDiameter(liveActivityType: self.liveActivityType)
        let scaleFactor = (glucoseCircleDiameterScalingHours ?? localHoursToShow) / localHoursToShow
        self.glucoseCircleDiameter = diameterBase * scaleFactor
        
        // 5) Date locale (filtrare după fereastra de timp)
        var localDates: [Date] = []
        var localValues: [Double] = []
        
        if let bgValues = bgReadingValues, let bgDates = bgReadingDates {
            zip(bgDates, bgValues).forEach { (date, value) in
                // Păstrăm doar punctele din fereastra de timp
                if date > Date().addingTimeInterval(-localHoursToShow * 3600) {
                    localDates.append(date)
                    localValues.append(value)
                }
            }
        }
        
        // 6) Prelucrări: remove outliers -> fill missing -> skip final gap -> smooth
        var (fDates, fValues) = removeOutliersFromPairs(
            dates: localDates,
            values: localValues,
            sigma: 3.0
        )
        
        (fDates, fValues) = fillMissingDatesPreservingFinal(
            dates: fDates,
            values: fValues,
            intervalInMinutes: 5
        )
        
        // În loc de moving average, folosim exponential smoothing
        // cu O(n) complexitate, reducând resursele necesare
        fValues = smoothValuesSkippingLastExponential(
            fValues,
            alpha: 0.3  // Ajustează după preferințe
        )
        
        // 7) Atribuire finală
        self.bgReadingDates = fDates
        self.bgReadingValues = fValues
    }
    
    // MARK: - Body
    
    var body: some View {
        
        // Ajustăm puțin offset-ul pentru ultimul punct, mai ales pt. liveActivityLarge
        let extraRange: Double = {
            if chartType == .liveActivity {
                return 10
            } else {
                return 6
            }
        }()
        
        let minVal = min(bgReadingValues.min() ?? 40, urgentLowLimitInMgDl) - extraRange
        let maxVal = max(bgReadingValues.max() ?? urgentHighLimitInMgDl, urgentHighLimitInMgDl) + extraRange
        let domain = minVal...maxVal
        
        let yAxisLineSize = chartType.yAxisLineSize()
        
        Chart {
            // UrgentLow line
            if domain.contains(urgentLowLimitInMgDl) {
                RuleMark(y: .value("", urgentLowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }
            
            // UrgentHigh line
            if domain.contains(urgentHighLimitInMgDl) {
                RuleMark(y: .value("", urgentHighLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [2 * yAxisLineSize, 6 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisUrgentLowHighLineColor())
            }
            
            // Low line
            if domain.contains(lowLimitInMgDl) {
                RuleMark(y: .value("", lowLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }
            
            // High line
            if domain.contains(highLimitInMgDl) {
                RuleMark(y: .value("", highLimitInMgDl))
                    .lineStyle(StrokeStyle(lineWidth: yAxisLineSize, dash: [4 * yAxisLineSize, 3 * yAxisLineSize]))
                    .foregroundStyle(chartType.yAxisLowHighLineColor())
            }
            
            // Phantom la început
            PointMark(
                x: .value("Time", Date().addingTimeInterval(-hoursToShow * 3600)),
                y: .value("BG", (domain.lowerBound + domain.upperBound) / 2)
            )
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)
            
            // Punctele reale
            ForEach(bgReadingValues.indices, id: \.self) { idx in
                PointMark(
                    x: .value("Time", bgReadingDates[idx]),
                    y: .value("BG", bgReadingValues[idx])
                )
                .symbol(Circle())
                .symbolSize(glucoseCircleDiameter)
                .foregroundStyle(bgColor(bgValueInMgDl: bgReadingValues[idx]))
            }
            
            // Phantom la final
            PointMark(
                x: .value("Time", Date().addingTimeInterval(5 * 60)),
                y: .value("BG", (domain.lowerBound + domain.upperBound) / 2)
            )
            .symbol(Circle())
            .symbolSize(glucoseCircleDiameter)
            .foregroundStyle(.clear)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: chartType.xAxisLabelEveryHours())) {
                if let dateValue = $0.as(Date.self) {
                    if chartType.xAxisShowLabels() {
                        AxisValueLabel {
                            let shouldHideLabel =
                                abs(Date().distance(to: dateValue))
                                    < ConstantsGlucoseChartSwiftUI.xAxisLabelFirstClippingInMinutes
                                ||
                                abs(Date().addingTimeInterval(-hoursToShow * 3600).distance(to: dateValue))
                                    < ConstantsGlucoseChartSwiftUI.xAxisLabelLastClippingInMinutes
                            
                            Text(!shouldHideLabel ? dateValue.formatted(.dateTime.hour()) : "")
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
                if let doubleValue = $0.as(Double.self) {
                    AxisValueLabel {
                        Text(doubleValue.mgDlToMmolAndToString(mgDl: isMgDl))
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
                if let doubleValue = $0.as(Double.self) {
                    AxisValueLabel {
                        Text(doubleValue.mgDlToMmolAndToString(mgDl: isMgDl))
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
        .if({ chartType.frame() }()) { view in
            view.frame(width: chartWidth, height: chartHeight)
        }
        .if({ chartType.aspectRatio().enable }()) { view in
            view.aspectRatio(
                chartType.aspectRatio().aspectRatio,
                contentMode: chartType.aspectRatio().contentMode
            )
        }
        .if({ chartType.padding().enable }()) { view in
            view.padding(chartType.padding().padding)
        }
        .chartYAxis(chartType.yAxisShowLabels())
        .chartYScale(domain: domain)
        .background(chartType.backgroundColor())
        .clipShape(RoundedRectangle(cornerRadius: chartType.cornerRadius()))
    }
    
    // MARK: - Helper Functions
    
    /// Afișează BG color based on user's thresholds
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
}

// MARK: - removeOutliersFromPairs

private func removeOutliersFromPairs(
    dates: [Date],
    values: [Double],
    sigma: Double
) -> ([Date], [Double]) {
    guard !dates.isEmpty, dates.count == values.count else {
        return ([], [])
    }
    
    // Calculează media și deviația standard o singură dată
    let mean = values.reduce(0, +) / Double(values.count)
    let squaredDiffs = values.map { pow($0 - mean, 2) }
    let stdev = sqrt(squaredDiffs.reduce(0, +) / Double(values.count))
    
    // Elimină valorile în afara [mean - sigma*stdev, mean + sigma*stdev]
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

// MARK: - fillMissingDatesPreservingFinal
/// Umple la interval fix până la penultimul punct, apoi adaugă ultimele două puncte așa cum sunt
private func fillMissingDatesPreservingFinal(
    dates: [Date],
    values: [Double],
    intervalInMinutes: Int
) -> ([Date], [Double]) {
    guard !dates.isEmpty, dates.count == values.count else {
        return ([], [])
    }
    
    let combined = zip(dates, values).sorted { $0.0 < $1.0 }
    let sortedDates = combined.map { $0.0 }
    let sortedValues = combined.map { $0.1 }
    
    guard sortedDates.count > 1 else {
        return (sortedDates, sortedValues)
    }
    
    let startDate = sortedDates.first!
    let secondLastDate = sortedDates[sortedDates.count - 2]
    let lastDate = sortedDates.last!
    let lastValue = sortedValues.last!
    
    let increment = Double(intervalInMinutes * 60)
    
    var generatedDates: [Date] = []
    var generatedValues: [Double] = []
    
    var currentDate = startDate
    
    // Interpolăm până la penultimul punct
    while currentDate < secondLastDate {
        generatedDates.append(currentDate)
        
        if let val = interpolateValue(
            for: currentDate,
            inDates: sortedDates,
            inValues: sortedValues
        ) {
            generatedValues.append(val)
        } else {
            generatedValues.append(0)
        }
        
        currentDate = currentDate.addingTimeInterval(increment)
    }
    
    // Adaugă penultimul punct exact
    generatedDates.append(secondLastDate)
    if let idx = sortedDates.firstIndex(of: secondLastDate) {
        generatedValues.append(sortedValues[idx])
    } else {
        generatedValues.append(0)
    }
    
    // Adaugă ultimul punct exact, fără interpolare
    generatedDates.append(lastDate)
    generatedValues.append(lastValue)
    
    return (generatedDates, generatedValues)
}

// MARK: - interpolateValue

private func interpolateValue(
    for targetDate: Date,
    inDates dates: [Date],
    inValues values: [Double]
) -> Double? {
    guard let firstIndex = dates.lastIndex(where: { $0 <= targetDate }),
          let secondIndex = dates.firstIndex(where: { $0 >= targetDate }) else {
        return nil
    }
    
    // Exact match
    if dates[firstIndex] == targetDate {
        return values[firstIndex]
    }
    if dates[secondIndex] == targetDate {
        return values[secondIndex]
    }
    
    // Fără interval
    if firstIndex == secondIndex {
        return values[firstIndex]
    }
    
    let dateA = dates[firstIndex]
    let dateB = dates[secondIndex]
    let valA = values[firstIndex]
    let valB = values[secondIndex]
    
    let total = dateB.timeIntervalSince(dateA)
    let partial = targetDate.timeIntervalSince(dateA)
    
    if total == 0.0 {
        return valA
    }
    let ratio = partial / total
    return valA + ratio * (valB - valA)
}

// MARK: - smoothValuesSkippingLastExponential
/// Exponential smoothing simplu, O(n), fără a recalcula ferestre multiple.
/// Ultimul punct (cel mai nou) rămâne neschimbat.
private func smoothValuesSkippingLastExponential(
    _ values: [Double],
    alpha: Double
) -> [Double] {
    guard values.count > 1, alpha > 0, alpha < 1 else {
        return values
    }
    
    var smoothed = Array(repeating: 0.0, count: values.count)
    
    // Inițializare cu prima valoare
    smoothed[0] = values[0]
    
    // Netezim până la penultimul index (values.count - 2)
    for i in 1..<(values.count - 1) {
        smoothed[i] = alpha * values[i] + (1 - alpha) * smoothed[i - 1]
    }
    
    // Ultimul punct rămâne exact
    smoothed[values.count - 1] = values.last!
    
    return smoothed
}
