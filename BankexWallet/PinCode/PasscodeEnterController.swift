//
//  PasscodeEnterController.swift
//  BankexWallet
//
//  Created by Антон Григорьев on 25.07.2018.
//  Copyright © 2018 Alexander Vlasov. All rights reserved.
//

import UIKit
import LocalAuthentication

class PasscodeEnterController: UIViewController {
    
    static var isLocked = false
    var isEntering = false
    
    enum passcodeStatus: String {
        case enter = "Touch ID or Enter Passcode"
        case wrong = "Wrong passcode"
        case ready = "Ready"
    }
    
    @IBOutlet weak var messageLabel: UILabel!
    var passcode: String = ""
    var status: passcodeStatus = .enter
    
    @IBOutlet weak var firstNum: UIImageView!
    @IBOutlet weak var secondNum: UIImageView!
    @IBOutlet weak var thirdNum: UIImageView!
    @IBOutlet weak var fourthNum: UIImageView!
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var biometricsButton: UIButton!
    
    var turnOnTouchID:Bool {
        return UserDefaults.standard.bool(forKey: Keys.openSwitch.rawValue)
    }
    var fromBackground:Bool {
        guard let vc = currentPasscodeViewController, vc.navigationController == nil else { return false }
        return true
    }
    var numsIcons: [UIImageView]?
    var instanciatedFromSend = false
    var isAvailableTouchID:Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        changePasscodeStatus(.enter)
        numsIcons = [firstNum, secondNum, thirdNum, fourthNum]
        if turnOnTouchID {
            enterWithBiometrics()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: Notification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    @objc func didEnterForeground() {
        if turnOnTouchID {
            enterWithBiometrics()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        PasscodeEnterController.isLocked = true
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        configureBackground()
        if UserDefaults.standard.value(forKey: Keys.openSwitch.rawValue) == nil {
            UserDefaults.standard.set(true, forKey: Keys.openSwitch.rawValue)
        }
        if !isAvailableTouchID || !turnOnTouchID {
            hideBiometricButton()
        }
        
    }
    
    func hideBiometricButton() {
        biometricsButton.alpha = 0.0
        biometricsButton.isUserInteractionEnabled = false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func changePasscodeStatus(_ newStatus: passcodeStatus) {
        status = newStatus
        messageLabel.text = NSLocalizedString(status.rawValue, comment: "")
        if status == .wrong {
            passcode = ""
            updateUI(0)
        } else if status == .ready {
            enterWallet()
        }
    }
    
    private func configureBackground() {
        UIApplication.shared.statusBarView?.backgroundColor = nil
        if instanciatedFromSend {
            backgroundImageView.image = UIImage(named: "pin-greybackground")
        }
    }
    func checkPin(_ passcode: String) -> Bool {
        do {
            let passcodeItem = KeychainPasswordItem(service: KeychainConfiguration.serviceName,
                                                    account: "BANKEXFOUNDATION",
                                                    accessGroup: KeychainConfiguration.accessGroup)
            let keychainPasscode = try passcodeItem.readPassword()
            return passcode == keychainPasscode
        } catch {
            fatalError("Error reading password from keychain - \(error)")
        }
    }
    
    func enterWallet() {
        PasscodeEnterController.isLocked = false
        if self.instanciatedFromSend {
            self.performSegue(withIdentifier: "backToSend", sender: nil)
        } else {
            if self.fromBackground {
                self.dismiss(animated: true, completion: nil)
                currentPasscodeViewController = nil
            } else {
                self.performSegue(withIdentifier: "showProcessFromPin", sender: self)
            }
        }
    }
    
    func updateUI(_ nums: Int) {
        switch nums {
        case 0:
            numsIcons?.forEach { icon in
                icon.image = UIImage(named: "white_line")
            }
        case 4:
            numsIcons?.forEach { icon in
                icon.image = UIImage(named: "White_dot")
            }
        default:
            for i in 0...nums-1 {
                self.numsIcons![i].image = UIImage(named: "White_dot")
            }
            for i in nums...(numsIcons?.count)!-1 {
                self.numsIcons![i].image = UIImage(named: "white_line")
            }
        }
    }
    
    
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    @IBAction func numberTouchedDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05,
                       animations: {
                        sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)},
                       completion: nil)
    }
    
    
    
    @IBAction func numberPressed(_ sender: enterPinCodeNumberButton) {
        let number = sender.currentTitle!
        sender.initialAnimation()
        if status == .enter {
            passcode += number
            updateUI(passcode.count)
            if passcode.count == 4 {
                let newStatus: passcodeStatus = checkPin(passcode) ? .ready : .wrong
                changePasscodeStatus(newStatus)
            }
        } else if status == .wrong {
            changePasscodeStatus(.enter)
            passcode += number
            updateUI(passcode.count)
        }
        
    }
    
    @IBAction func touchAborted(_ sender: UIButton) {
        sender.initialAnimation()
    }
    
    @IBAction func touchDragInside(_ sender: UIButton) {
        UIView.animate(withDuration: 0.05,
                       animations: {
                        sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)},
                       completion: nil)
    }
    
    
    @IBAction func deletePressed(_ sender: UIButton) {
        sender.initialAnimation()
        if passcode != "" {
            passcode.removeLast()
            updateUI(passcode.count)
        }
    }
    
    @IBAction func biometricsPressed(_ sender: UIButton) {
        sender.initialAnimation()
        enterWithBiometrics()
    }
    
    func enterWithBiometrics() {
        guard !isEntering else { return }
        isEntering = true
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            var type = "Touch ID"
            if #available(iOS 11, *) {
                switch(context.biometryType) {
                case .touchID:
                    type = "Touch ID"
                case .faceID:
                    type = "Face ID"
                case .none:
                    type = "Error"
                }
            }
            let reason = NSLocalizedString("Authenticate with", comment: "") + type
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                   localizedReason: reason,
                                   reply:
                {(success, error) in
                    self.isEntering = false
                    if success {
                        DispatchQueue.main.async(execute: self.enterWallet)
                    }
                    
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? SendingInProcessViewController {
            vc.fromEnterScreen = true
        } else if let vc = segue.destination as? ConfirmViewController {
            vc.isPinAccepted = true
        }
    }
    
}

class enterPinCodeNumberButton: UIButton {
    override func awakeFromNib() {
        super.awakeFromNib()
        self.layer.cornerRadius = self.bounds.size.width/2
    }
}
