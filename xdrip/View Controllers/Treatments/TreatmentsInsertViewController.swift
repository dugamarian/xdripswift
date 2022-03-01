//
//  TreatmentsInsertViewController.swift
//  xdrip
//
//  Created by Eduardo Pietre on 23/12/21.
//  Copyright © 2021 Johan Degraeve. All rights reserved.
//

import Foundation


class TreatmentsInsertViewController : UIViewController {
	
	@IBOutlet weak var titleNavigation: UINavigationItem!
	@IBOutlet weak var carbsLabel: UILabel!
	@IBOutlet weak var insulinLabel: UILabel!
	@IBOutlet weak var exerciseLabel: UILabel!
	@IBOutlet weak var doneButton: UIBarButtonItem!
	@IBOutlet weak var datePicker: UIDatePicker!
	@IBOutlet weak var carbsTextField: UITextField!
	@IBOutlet weak var insulinTextField: UITextField!
	@IBOutlet weak var exerciseTextField: UITextField!
    @IBOutlet weak var carbsStackView: UIStackView!
    @IBOutlet weak var insulinStackView: UIStackView!
    @IBOutlet weak var exerciseStackView: UIStackView!
    
    // MARK: - private properties
    
	/// reference to coreDataManager
	private var coreDataManager:CoreDataManager!
	
	/// handler to be executed when user clicks okButton
	private var completionHandler:(() -> Void)?
    
    /// used if this viewcontroller is used to update an existing entry
    /// - if nil then viewcontroller is used to add a (or mote) new entry (or entries)
    private var treatMentEntryToUpdate: TreatmentEntry?
	
    // MARK: - View Life Cycle
    
	// set the status bar content colour to light to match new darker theme
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}
	
    // will assign datePicker.date to treatMentEntryToUpdate.date
    override func viewDidLoad() {
    
        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            
            datePicker.date = treatMentEntryToUpdate.date
            
        }
        
    }
    
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		// Fixes dark mode issues
		if let navigationBar = navigationController?.navigationBar {
			navigationBar.barStyle = UIBarStyle.blackTranslucent
			navigationBar.barTintColor  = UIColor.black
			navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
		}
		
		// Title
		self.titleNavigation.title = Texts_TreatmentsView.newEntryTitle
        
		// Labels for each TextField
		self.carbsLabel.text = Texts_TreatmentsView.carbsWithUnit
		self.insulinLabel.text = Texts_TreatmentsView.insulinWithUnit
		self.exerciseLabel.text = Texts_TreatmentsView.exerciseWithUnit
		
		// Done button
		self.addDoneButtonOnNumpad(textField: self.carbsTextField)
		self.addDoneButtonOnNumpad(textField: self.insulinTextField)
		self.addDoneButtonOnNumpad(textField: self.exerciseTextField)
        
		self.setDismissKeyboard()

        if let treatMentEntryToUpdate = treatMentEntryToUpdate {
            
            switch treatMentEntryToUpdate.treatmentType {
                
            case .Carbs:
                // set text to value of treatMentEntryToUpdate
                carbsTextField.text = treatMentEntryToUpdate.value.stringWithoutTrailingZeroes
                
                // hide the other fields
                insulinTextField.isHidden = true
                insulinLabel.isHidden = true
                insulinStackView.isHidden = true
                exerciseTextField.isHidden = true
                exerciseLabel.isHidden = true
                exerciseStackView.isHidden = true

            case .Exercise:
                // set text to value of treatMentEntryToUpdate
                exerciseTextField.text = treatMentEntryToUpdate.value.stringWithoutTrailingZeroes
                
                // hide the other fields
                carbsTextField.isHidden = true
                carbsLabel.isHidden = true
                carbsStackView.isHidden = true
                insulinTextField.isHidden = true
                insulinLabel.isHidden = true
                insulinStackView.isHidden = true

            case .Insulin:
                // set text to value of treatMentEntryToUpdate
                insulinTextField.text = treatMentEntryToUpdate.value.stringWithoutTrailingZeroes
                
                // hide the other fields
                carbsTextField.isHidden = true
                carbsLabel.isHidden = true
                carbsStackView.isHidden = true
                exerciseTextField.isHidden = true
                exerciseLabel.isHidden = true
                exerciseStackView.isHidden = true

            }
            
        }
	}

	// MARK: - buttons actions
	
	@IBAction func doneButtonTapped(_ sender: UIBarButtonItem) {
        
        // if treatMentEntryToUpdate not nil, then assign new value or delete it
        // it's either type carbs, insulin or exercise
        if let treatMentEntryToUpdate = treatMentEntryToUpdate {

            // code reused three times
            // checks if text in textfield exists, has value > 0.
            // if yes, assigns value to treatMentEntryToUpdate.value
            // if no deletes treatMentEntryToUpdate
            let updateFunction = { (textField: UITextField) in
                
                if let text = textField.text, let value = Double(text), value > 0 {
                    
                    // keep track if changed or not
                    var treatMentEntryToUpdateChanged = false
                    
                    if treatMentEntryToUpdate.value != value {
                        
                        treatMentEntryToUpdate.value = value

                        // sets text in textField to "0" to avoid that new treatmentEntry is created
                        textField.text = "0"

                        treatMentEntryToUpdateChanged = true
                                                
                    }
                    
                    if treatMentEntryToUpdate.date != self.datePicker.date {
                        
                        treatMentEntryToUpdate.date = self.datePicker.date
                        
                        treatMentEntryToUpdateChanged = true
                        
                    }
                    
                    if treatMentEntryToUpdateChanged {
                        
                        // permenant save in coredata
                        self.coreDataManager.saveChanges()
                        
                        // set uploaded to false so that the entry is synced with NightScout
                        treatMentEntryToUpdate.uploaded = false

                        // trigger nightscoutsync
                        UserDefaults.standard.nightScoutSyncTreatmentsRequired = true

                    }

                } else {
                    
                    // text is nil or "0", set treatmentdeleted to true
                    treatMentEntryToUpdate.treatmentdeleted = true
                    
                    // set uploaded to false so that the entry is synced with NightScout
                    treatMentEntryToUpdate.uploaded = false

                    // trigger nightscoutsync
                    UserDefaults.standard.nightScoutSyncTreatmentsRequired = true
                    
                    self.treatMentEntryToUpdate = nil

                }
                
            }

            switch treatMentEntryToUpdate.treatmentType {
               
            case .Carbs:
                updateFunction(carbsTextField)
                    
            case .Insulin:
                updateFunction(insulinTextField)
                
            case .Exercise:
                updateFunction(exerciseTextField)
                
            }
            
        } else {
            
            // viewcontroller is opened to create a new treatmenEntry
            
            // if there's more than one new treatmentEntry being created here, then each will be created with a small difference in timestamp, ie 1 millisecond
            // because, after uploading to NightScout, the timestamp is is used to recognize/find back the actualy event, and so to find the id assigned by NightScout
            // (probably it's better that xdrip4ioS would assign the id)
            // dateOffset is used to keep track of the offset to use
            var dateOffset = TimeInterval(0.0)
            
            // code reused three times
            // checks if text is not nil, has value > 0.
            // if yes, creates a new TreatmentEntry
            let createFunction = { [self] (text: String?, treatmentType: TreatmentType) in
                
                if let text = text, let value = Double(text), value > 0 {

                    // create the treatment and append to treatments
                    _ = TreatmentEntry(date: Date(timeInterval: dateOffset, since: datePicker.date), value: value, treatmentType: treatmentType, nightscoutEventType: nil, nsManagedObjectContext: self.coreDataManager.mainManagedObjectContext)
                    
                    // trigger nightscoutsync
                    UserDefaults.standard.nightScoutSyncTreatmentsRequired = true
                    
                    // save to coredata
                    coreDataManager.saveChanges()

                    // increase dateOffset in case a next/new treatment will be be created
                    dateOffset = dateOffset + TimeInterval(0.001)
                    
                }

            }
            
            // call createFunction for each TextField
            createFunction(carbsTextField.text, .Carbs)
            createFunction(insulinTextField.text, .Insulin)
            createFunction(exerciseTextField.text, .Exercise)

        }
        
        // call completionHandler
        if let completionHandler = completionHandler {
            completionHandler()
        }
		
		
		// Pops the current view (this)
		self.navigationController?.popViewController(animated: true)
        
	}
	
	
	// MARK: - public functions
	
    /// - parameters:
    ///     - treatMentEntryToUpdate
    public func configure(treatMentEntryToUpdate: TreatmentEntry?, coreDataManager: CoreDataManager, completionHandler: @escaping (() -> Void)) {
        
		// initalize private properties
		self.coreDataManager = coreDataManager
		self.completionHandler = completionHandler
        
        self.treatMentEntryToUpdate = treatMentEntryToUpdate
        
	}
	
	// MARK: - private functions
	
	private func addDoneButtonOnNumpad(textField: UITextField) {
		
		let keypadToolbar: UIToolbar = UIToolbar()
		
		// add a done button to the numberpad
		keypadToolbar.items = [
			UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil),
			UIBarButtonItem(title: Texts_Common.Ok, style: UIBarButtonItem.Style.done, target: textField, action: #selector(UITextField.resignFirstResponder))
		]
		keypadToolbar.sizeToFit()
		// add a toolbar with a done button above the number pad
		textField.inputAccessoryView = keypadToolbar
        
	}
	
	func setDismissKeyboard() {
	   let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action:    #selector(self.dismissKeyboardTouchOutside))
	   tap.cancelsTouchesInView = false
	   view.addGestureRecognizer(tap)
	}
	
	@objc private func dismissKeyboardTouchOutside() {
	   view.endEditing(true)
	}
	
}
