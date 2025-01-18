//
//  LandscapeValueViewController.swift
//  xdrip
//
//  Created by Johan Degraeve on 24/12/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UIKit

class LandscapeValueViewController: UIViewController {
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var allViewsStackView: UIStackView!
    @IBOutlet weak var minutesAndDiffLabelStackView: UIStackView!
    @IBOutlet weak var minutesLabelStackView: UIStackView!
    @IBOutlet weak var minutesLabelOutlet: UILabel!
    @IBOutlet weak var minutesAgoLabelOutlet: UILabel!
    @IBOutlet weak var diffLabelOutlet: UILabel!
    @IBOutlet weak var diffLabelUnitOutlet: UILabel!
    @IBOutlet weak var valueLabelOutlet: UILabel!
    
    // MARK: - Private UI Elements
    
    private let clockLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
       
        label.text = "--:--"
        label.textColor = .red
       
        if let customFont = UIFont(name: "HelveticaNeue-Bold", size: 80) {
            label.font = customFont
        } else {

            label.font = UIFont.systemFont(ofSize: 80, weight: .bold)
        }
        
        label.textAlignment = .center
       
        label.layer.borderColor = UIColor.red.cgColor
        label.layer.borderWidth = 2
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        
        return label
    }()
    
    private let valueAndClockStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fill
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private var timer: Timer?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.modalPresentationStyle = .fullScreen

        setupStackViewConstraints()
        configureLabelsAutoShrink()
        setAllLabelsTextColor(to: .red)

        valueLabelOutlet.font = UIFont.systemFont(ofSize: 124, weight: .bold)
        
        setupValueAndClockStackView()

        self.modalPresentationStyle = .fullScreen
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
        setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        setNeedsStatusBarAppearanceUpdate()
    }
    
    // MARK: - Status Bar & Home Indicator
  
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // MARK: - Public Functions
    
    public func updateLabels(
        minutesLabelText: String? = nil,
        minutesLabelAgoText: String? = nil,
        diffLabelText: String? = nil,
        diffLabelUnitText: String? = nil,
        valueLabelText: String? = nil,
        valueLabelAttributedText: NSAttributedString? = nil
    ) {
        minutesLabelOutlet.text = minutesLabelText
        minutesAgoLabelOutlet.text = " " + (minutesLabelAgoText ?? "")
        diffLabelOutlet.text = diffLabelText
        diffLabelUnitOutlet.text = " " + (diffLabelUnitText ?? "")
        valueLabelOutlet.text = valueLabelText
        valueLabelOutlet.attributedText = valueLabelAttributedText
 
        setAllLabelsTextColor(to: .red)
    }
    
    // MARK: - Private Functions
    private func configureLabelsAutoShrink() {

        let baseFontSize: CGFloat = 30

        let labels = [
            minutesLabelOutlet,
            minutesAgoLabelOutlet,
            diffLabelOutlet,
            diffLabelUnitOutlet,
            valueLabelOutlet
        ]

        for label in labels {
            label?.font = UIFont.systemFont(ofSize: baseFontSize, weight: .bold)

            label?.numberOfLines = 1
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.8
            label?.lineBreakMode = .byClipping
        }

        clockLabel.numberOfLines = 1
        clockLabel.adjustsFontSizeToFitWidth = true
        clockLabel.minimumScaleFactor = 0.8
        clockLabel.lineBreakMode = .byClipping
    }

    private func setupStackViewConstraints() {
        minutesAndDiffLabelStackView.translatesAutoresizingMaskIntoConstraints = false
        minutesLabelStackView.translatesAutoresizingMaskIntoConstraints = false
        
        minutesAndDiffLabelStackView.heightAnchor.constraint(
            equalTo: allViewsStackView.heightAnchor,
            multiplier: 0.2
        ).isActive = true
        
        minutesLabelStackView.widthAnchor.constraint(
            equalTo: minutesAndDiffLabelStackView.widthAnchor,
            multiplier: 0.6
        ).isActive = true
    }
  
    private func setAllLabelsTextColor(to color: UIColor) {
        minutesLabelOutlet.textColor = color
        minutesAgoLabelOutlet.textColor = color
        diffLabelOutlet.textColor = color
        diffLabelUnitOutlet.textColor = color
        valueLabelOutlet.textColor = color
        clockLabel.textColor = color
    }

    private func setupValueAndClockStackView() {
        valueAndClockStackView.addArrangedSubview(valueLabelOutlet)
        valueAndClockStackView.addArrangedSubview(clockLabel)
        allViewsStackView.addArrangedSubview(valueAndClockStackView)
        
        NSLayoutConstraint.activate([
            valueAndClockStackView.heightAnchor.constraint(equalToConstant: 60),
            valueAndClockStackView.leadingAnchor.constraint(equalTo: allViewsStackView.leadingAnchor, constant: 16),
            valueAndClockStackView.trailingAnchor.constraint(equalTo: allViewsStackView.trailingAnchor, constant: -16)
        ])
        
        startClock()
    }
    
    private func startClock() {
        updateClock()
        timer = Timer.scheduledTimer(timeInterval: 1.0,
                                     target: self,
                                     selector: #selector(updateClock),
                                     userInfo: nil,
                                     repeats: true)
    }

    @objc private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        clockLabel.text = formatter.string(from: Date())
    }

    deinit {
        timer?.invalidate()
    }
 
}
