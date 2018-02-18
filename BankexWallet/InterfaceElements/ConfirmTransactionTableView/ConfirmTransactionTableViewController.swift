//
//  SingleAddressTableViewController.swift
//  BankexWallet
//
//  Created by Alexander Vlasov on 29.01.2018.
//  Copyright © 2018 Alexander Vlasov. All rights reserved.
//

import Foundation
import web3swift
import BigInt

class ConfirmTransactionTableViewController: UITableViewController {
    
    @IBOutlet weak var destinationAddressTextField: UITextField!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var extraDataTextView: UITextView!
    @IBOutlet weak var gasLimitTextField: UITextField!
    @IBOutlet weak var gasPriceTextField: UITextField!
    
    var address: EthereumAddress? = nil
    var keystore: AbstractKeystore? = nil
    var intermediate: TransactionIntermediate? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.destinationAddressTextField.text = self.intermediate?.transaction.to.address
        self.amountTextField.text = Web3.Utils.formatToEthereumUnits((self.intermediate?.options?.value)!)
        self.extraDataTextView.text = self.intermediate?.transaction.data.toHexString()
        self.gasLimitTextField.text = Web3.Utils.formatToEthereumUnits((self.intermediate?.options?.gas)!, toUnits: .wei, decimals: 0)
        self.gasPriceTextField.text = Web3.Utils.formatToEthereumUnits((self.intermediate?.options?.gasPrice)!, toUnits: .wei, decimals: 0)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        switch indexPath.section {
        case 5:
            let result = self.intermediate?.send(password: "BANKEXFOUNDATION")
            let alert = UIAlertController.init(title: "Sent successfully", message: "TX hash is " + (result!["txhash"] as! String), preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { action in
                switch action.style{
                case .default:
                    self.navigationController?.popViewController(animated: true)
                    print("default")

                case .cancel:
                    print("cancel")
                    
                case .destructive:
                    print("destructive")
                    
                    
                }}))
            self.present(alert, animated: true, completion: nil)
            return
        default:
            return
//            fatalError("Invalid number of cells")
        }
    }
    
}

