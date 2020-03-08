//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices
import MessageUI

extension SettingsViewController
{
    fileprivate enum Section: Int, CaseIterable
    {
        case signIn
        case account
        case patreon
        case backgroundRefresh
        case instructions
        case credits
        case debug
    }
    
    fileprivate enum CreditsRow: Int, CaseIterable
    {
        case developer
        case designer
        case softwareLicenses
    }
    
    fileprivate enum DebugRow: Int, CaseIterable
    {
        case sendFeedback
        case refreshAttempts
    }
}

class SettingsViewController: UITableViewController
{
    private var activeTeam: Team?
    
    private var prototypeHeaderFooterView: SettingsHeaderFooterView!
    
    private var debugGestureCounter = 0
    private weak var debugGestureTimer: Timer?
    
    @IBOutlet private var accountNameLabel: UILabel!
    @IBOutlet private var accountEmailLabel: UILabel!
    @IBOutlet private var accountTypeLabel: UILabel!
    
    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    
    @IBOutlet private var versionLabel: UILabel!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openPatreonSettings(_:)), name: AppDelegate.openPatreonSettingsDeepLinkNotification, object: nil)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let nib = UINib(nibName: "SettingsHeaderFooterView", bundle: nil)
        self.prototypeHeaderFooterView = nib.instantiate(withOwner: nil, options: nil)[0] as? SettingsHeaderFooterView
        
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderFooterView")
        
        let debugModeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(SettingsViewController.handleDebugModeGesture(_:)))
        debugModeGestureRecognizer.delegate = self
        debugModeGestureRecognizer.direction = .up
        debugModeGestureRecognizer.numberOfTouchesRequired = 3
        self.tableView.addGestureRecognizer(debugModeGestureRecognizer)
        
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        {
            self.versionLabel.text = NSLocalizedString(String(format: "AltStore %@", version), comment: "AltStore Version")
        }
        else
        {
            self.versionLabel.text = NSLocalizedString("AltStore", comment: "")
        }
        
        self.tableView.contentInset.bottom = 20
        
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.update()
    }
}

private extension SettingsViewController
{
    func update()
    {
        if let team = DatabaseManager.shared.activeTeam()
        {
            self.accountNameLabel.text = team.name
            self.accountEmailLabel.text = team.account.appleID
            self.accountTypeLabel.text = team.type.localizedDescription
            
            self.activeTeam = team
        }
        else
        {
            self.activeTeam = nil
        }
        
        self.backgroundRefreshSwitch.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        
        if self.isViewLoaded
        {
            self.tableView.reloadData()
        }
    }
    
    func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = isHeader
        settingsHeaderFooterView.button.isHidden = true
        
        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 0 : 8
        
        switch section
        {
        case .signIn:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("账号", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("用你的Apple ID登录以从AltStore下载应用.", comment: "")
            }
            
        case .patreon:
            if isHeader
            {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("PATREON", comment: "")
            }
            else
            {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("成为赞助者，即可访问AltStore，Delta等Beta版.", comment: "")
            }
            
        case .account:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("账号", comment: "")
            
            settingsHeaderFooterView.button.setTitle(NSLocalizedString("注销", comment: ""), for: .normal)
            settingsHeaderFooterView.button.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
            settingsHeaderFooterView.button.isHidden = false
            
        case .backgroundRefresh:
            settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString(" 当连接到和AltServer相同的WiFi时自动重签名应用.", comment: "")
            
        case .instructions:
            break
            
        case .credits:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("鸣谢", comment: "")
            
        case .debug:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("调试", comment: "")
        }
    }
    
    func preferredHeight(for settingsHeaderFooterView: SettingsHeaderFooterView, in section: Section, isHeader: Bool) -> CGFloat
    {
        let widthConstraint = settingsHeaderFooterView.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        NSLayoutConstraint.activate([widthConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint]) }
        
        self.prepare(settingsHeaderFooterView, for: section, isHeader: isHeader)
        
        let size = settingsHeaderFooterView.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size.height
    }
}

private extension SettingsViewController
{
    func signIn()
    {
        AppManager.shared.authenticate(presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(OperationError.cancelled):
                    // Ignore
                    break
                    
                case .failure(let error):
                    let toastView = ToastView(text: error.localizedDescription, detailText: nil)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    
                case .success: break
                }
                
                self.update()
            }
        }
    }
    
    @objc func signOut(_ sender: UIBarButtonItem)
    {
        func signOut()
        {
            DatabaseManager.shared.signOut { (error) in
                DispatchQueue.main.async {
                    if let error = error
                    {
                        let toastView = ToastView(text: error.localizedDescription, detailText: nil)
                        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    }
                    
                    self.update()
                }
            }
        }
        
        let alertController = UIAlertController(title: NSLocalizedString("你确定要退出账号?", comment: ""), message: NSLocalizedString("当退出账号后你将无法安装或者重签应用.", comment: ""), preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("退出账号", comment: ""), style: .destructive) { _ in signOut() })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func toggleIsBackgroundRefreshEnabled(_ sender: UISwitch)
    {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn
    }
    
    @IBAction func handleDebugModeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
    {
        self.debugGestureCounter += 1
        self.debugGestureTimer?.invalidate()
        
        if self.debugGestureCounter >= 3
        {
            self.debugGestureCounter = 0
            
            UserDefaults.standard.isDebugModeEnabled.toggle()
            self.tableView.reloadData()
        }
        else
        {
            self.debugGestureTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] (timer) in
                self?.debugGestureCounter = 0
            }
        }
    }
    
    func openTwitter(username: String)
    {
        let twitterAppURL = URL(string: "twitter://user?screen_name=" + username)!
        UIApplication.shared.open(twitterAppURL, options: [:]) { (success) in
            if success
            {
                if let selectedIndexPath = self.tableView.indexPathForSelectedRow
                {
                    self.tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
            }
            else
            {
                let safariURL = URL(string: "https://twitter.com/" + username)!
                
                let safariViewController = SFSafariViewController(url: safariURL)
                safariViewController.preferredControlTintColor = .altPrimary
                self.present(safariViewController, animated: true, completion: nil)
            }
        }
    }
}

private extension SettingsViewController
{
    @objc func openPatreonSettings(_ notification: Notification)
    {
        guard self.presentedViewController == nil else { return }
                
        UIView.performWithoutAnimation {
            self.navigationController?.popViewController(animated: false)
            self.performSegue(withIdentifier: "showPatreon", sender: nil)
        }
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        var numberOfSections = super.numberOfSections(in: tableView)
        
        if !UserDefaults.standard.isDebugModeEnabled
        {
            numberOfSections -= 1
        }
        
        return numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn: return (self.activeTeam == nil) ? 1 : 0
        case .account: return (self.activeTeam == nil) ? 0 : 3
        default: return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.activeTeam != nil: return nil
        case .account where self.activeTeam == nil: return nil
            
        case .signIn, .account, .patreon, .credits, .debug:
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(headerView, for: section, isHeader: true)
            return headerView
            
        case .backgroundRefresh, .instructions: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.activeTeam != nil: return nil
            
        case .signIn, .patreon, .backgroundRefresh:
            let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(footerView, for: section, isHeader: false)
            return footerView
            
        case .account, .credits, .debug, .instructions: return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.activeTeam != nil: return 1.0
        case .account where self.activeTeam == nil: return 1.0
            
        case .signIn, .account, .patreon, .credits, .debug:
            let height = self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: true)
            return height
            
        case .backgroundRefresh, .instructions: return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.activeTeam != nil: return 1.0
        case .account where self.activeTeam == nil: return 1.0
            
        case .signIn, .patreon, .backgroundRefresh:
            let height = self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: false)
            return height
            
        case .account, .credits, .debug, .instructions: return 0.0
        }
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .signIn: self.signIn()
        case .instructions: break
        case .credits:
            let row = CreditsRow.allCases[indexPath.row]
            switch row
            {
            case .developer: self.openTwitter(username: "rileytestut")
            case .designer: self.openTwitter(username: "1carolinemoore")
            case .softwareLicenses: break
            }
            
        case .debug:
            let row = DebugRow.allCases[indexPath.row]
            switch row
            {
            case .sendFeedback:
                if MFMailComposeViewController.canSendMail()
                {
                    let mailViewController = MFMailComposeViewController()
                    mailViewController.mailComposeDelegate = self
                    mailViewController.setToRecipients(["support@altstore.io"])
                    
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                    {
                        mailViewController.setSubject("AltStore Beta \(version) Feedback")
                    }
                    else
                    {
                        mailViewController.setSubject("AltStore Beta Feedback")
                    }
                    
                    self.present(mailViewController, animated: true, completion: nil)
                }
                else
                {
                    let toastView = ToastView(text: NSLocalizedString("Cannot Send Mail", comment: ""), detailText: nil)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                }
                
            case .refreshAttempts: break
            }
            
        default: break
        }
    }
}

extension SettingsViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        if let error = error
        {
            let toastView = ToastView(text: error.localizedDescription, detailText: "")
            toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
}
