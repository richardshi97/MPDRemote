// ServerVC.swift
// Copyright (c) 2016 Nyx0uf
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import UIKit


final class ServerVC : MenuTVC
{
	// MARK: - Private properties
	// MPD Server name
	@IBOutlet fileprivate var tfMPDName: UITextField!
	// MPD Server hostname
	@IBOutlet fileprivate var tfMPDHostname: UITextField!
	// MPD Server port
	@IBOutlet fileprivate var tfMPDPort: UITextField!
	// MPD Server password
	@IBOutlet fileprivate var tfMPDPassword: UITextField!
	// WEB Server hostname
	@IBOutlet fileprivate var tfWEBHostname: UITextField!
	// WEB Server port
	@IBOutlet fileprivate var tfWEBPort: UITextField!
	// Cover name
	@IBOutlet fileprivate var tfWEBCoverName: UITextField!
	// MPD Server
	private var mpdServer: AudioServer?
	// WEB Server for covers
	private var webServer: CoverWebServer?
	// Indicate that the keyboard is visible, flag
	private var _keyboardVisible = false

	// MARK: - UIViewController
	override func viewDidLoad()
	{
		super.viewDidLoad()

		// Navigation bar title
		let titleView = UILabel(frame:CGRect(0.0, 0.0, 100.0, 44.0))
		titleView.font = UIFont(name:"HelveticaNeue-Medium", size:14.0)
		titleView.numberOfLines = 2
		titleView.textAlignment = .center
		titleView.isAccessibilityElement = false
		titleView.textColor = navigationController?.navigationBar.tintColor
		titleView.text = NYXLocalizedString("lbl_header_server_cfg")
		titleView.backgroundColor = navigationController?.navigationBar.barTintColor
		navigationItem.titleView = titleView

		if let buttons = self.navigationItem.rightBarButtonItems
		{
			if let search = buttons.filter({$0.tag == 10}).first
			{
				search.accessibilityLabel = NYXLocalizedString("lbl_search_zeroconf")
			}
		}

		// Keyboard appearance notifications
		NotificationCenter.default.addObserver(self, selector:#selector(keyboardDidShowNotification(_:)), name:NSNotification.Name.UIKeyboardDidShow, object:nil)
		NotificationCenter.default.addObserver(self, selector:#selector(keyboardDidHideNotification(_:)), name:NSNotification.Name.UIKeyboardDidHide, object:nil)
	}

	override func viewWillAppear(_ animated: Bool)
	{
		super.viewWillAppear(animated)

		if let mpdServerAsData = UserDefaults.standard.data(forKey: kNYXPrefMPDServer)
		{
			if let server = NSKeyedUnarchiver.unarchiveObject(with: mpdServerAsData) as! AudioServer?
			{
				mpdServer = server
			}
		}
		else
		{
			Logger.alog("[+] No audio server registered yet.")
		}

		if let webServerAsData = UserDefaults.standard.data(forKey: kNYXPrefWEBServer)
		{
			if let server = NSKeyedUnarchiver.unarchiveObject(with: webServerAsData) as! CoverWebServer?
			{
				webServer = server
			}
		}
		else
		{
			Logger.alog("[+] No web server registered yet.")
		}

		_updateFields()
	}

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask
	{
		return .portrait
	}

	override var preferredStatusBarStyle: UIStatusBarStyle
	{
		return .lightContent
	}

	// MARK: - Buttons actions
	@IBAction func validateSettingsAction(_ sender: AnyObject?)
	{
		view.endEditing(true)

		// Check MPD server name (optional)
		var serverName = NYXLocalizedString("lbl_server_defaultname")
		if let strName = tfMPDName.text , strName.length > 0
		{
			serverName = strName
		}

		// Check MPD hostname / ip
		guard let ip = tfMPDHostname.text , ip.length > 0 else
		{
			let alertController = UIAlertController(title:NYXLocalizedString("lbl_alert_servercfg_error"), message:NYXLocalizedString("lbl_alert_servercfg_error_host"), preferredStyle:.alert)
			let cancelAction = UIAlertAction(title:NYXLocalizedString("lbl_ok"), style:.cancel) { (action) in
			}
			alertController.addAction(cancelAction)
			present(alertController, animated:true, completion:nil)
			return
		}

		// Check MPD port
		var port = UInt16(6600)
		if let strPort = tfMPDPort.text, let p = UInt16(strPort)
		{
			port = p
		}

		// Check MPD password (optional)
		var password = ""
		if let strPassword = tfMPDPassword.text , strPassword.length > 0
		{
			password = strPassword
		}

		//let mpdServer = password.length > 0 ? AudioServer(name:serverName, hostname:ip, port:port, password:password, type:.mpd) : AudioServer(type:.mpd, name:serverName, hostname:ip, port:port)
		let mpdServer = AudioServer(name:serverName, hostname:ip, port:port, password:password, type:.mpd)
		let cnn = MPDConnection(server:mpdServer)
		if cnn.connect()
		{
			self.mpdServer = mpdServer
			let serverAsData = NSKeyedArchiver.archivedData(withRootObject: mpdServer)
			UserDefaults.standard.set(serverAsData, forKey:kNYXPrefMPDServer)

			NotificationCenter.default.post(name: .audioServerConfigurationDidChange, object: mpdServer)
		}
		else
		{
			UserDefaults.standard.removeObject(forKey: kNYXPrefMPDServer)
			let alertController = UIAlertController(title:NYXLocalizedString("lbl_alert_servercfg_error"), message:NYXLocalizedString("lbl_alert_servercfg_error_msg"), preferredStyle:.alert)
			let cancelAction = UIAlertAction(title:NYXLocalizedString("lbl_ok"), style:.cancel) { (action) in
			}
			alertController.addAction(cancelAction)
			present(alertController, animated:true, completion:nil)
		}
		cnn.disconnect()

		// Check web URL (optional)
		if let strURL = tfWEBHostname.text , strURL.length > 0
		{
			var port = UInt16(80)
			if let strPort = tfWEBPort.text, let p = UInt16(strPort)
			{
				port = p
			}

			var coverName = "cover.jpg"
			if let cn = tfWEBCoverName.text , cn.length > 0
			{
				coverName = cn
			}
			let webServer = CoverWebServer(name:"CoverServer", hostname:strURL, port:port, coverName: coverName)
			webServer.coverName = coverName
			self.webServer = webServer
			let serverAsData = NSKeyedArchiver.archivedData(withRootObject: webServer)
			UserDefaults.standard.set(serverAsData, forKey:kNYXPrefWEBServer)
		}
		else
		{
			UserDefaults.standard.removeObject(forKey: kNYXPrefWEBServer)
		}

		UserDefaults.standard.synchronize()
	}

	@IBAction func browserZeroConfServers(_ sender: AnyObject?)
	{
		let sb = UIStoryboard(name: "main", bundle: nil)
		let nvc = sb.instantiateViewController(withIdentifier: "ZeroConfBrowserNVC") as! NYXNavigationController
		let vc = nvc.topViewController as! ZeroConfBrowserTVC
		vc.delegate = self
		self.navigationController?.present(nvc, animated: true, completion: nil)
	}

	// MARK: - Notifications
	func keyboardDidShowNotification(_ aNotification: Notification)
	{
		if _keyboardVisible
		{
			return
		}

		let info = (aNotification as NSNotification).userInfo!
		let value = info[UIKeyboardFrameEndUserInfoKey]!
		let rawFrame = (value as AnyObject).cgRectValue
		let keyboardFrame = view.convert(rawFrame!, from:nil)
		tableView.frame = CGRect(tableView.frame.origin, tableView.frame.width, tableView.frame.height - keyboardFrame.height)
		_keyboardVisible = true
	}

	func keyboardDidHideNotification(_ aNotification: Notification)
	{
		if !_keyboardVisible
		{
			return
		}

		let info = (aNotification as NSNotification).userInfo!
		let value = info[UIKeyboardFrameEndUserInfoKey]!
		let rawFrame = (value as AnyObject).cgRectValue
		let keyboardFrame = view.convert(rawFrame!, from:nil)
		tableView.frame = CGRect(tableView.frame.origin, tableView.frame.width, tableView.frame.height + keyboardFrame.height)
		_keyboardVisible = false
	}

	// MARK: - Private
	func _updateFields()
	{
		if let server = mpdServer
		{
			tfMPDName.text = server.name
			tfMPDHostname.text = server.hostname
			tfMPDPort.text = String(server.port)
			tfMPDPassword.text = server.password
		}
		else
		{
			tfMPDName.text = ""
			tfMPDHostname.text = ""
			tfMPDPort.text = "6600"
			tfMPDPassword.text = ""
		}

		if let server = webServer
		{
			tfWEBHostname.text = server.hostname
			tfWEBPort.text = String(server.port)
			tfWEBCoverName.text = server.coverName
		}
		else
		{
			tfWEBHostname.text = ""
			tfWEBPort.text = "80"
			tfWEBCoverName.text = "cover.jpg"
		}
	}

	func _clearCache(confirm: Bool)
	{
		let clearBlock = { () -> Void in
			let fileManager = FileManager()
			let cachesDirectoryURL = fileManager.urls(for:.cachesDirectory, in:.userDomainMask).last!
			let coversDirectoryName = UserDefaults.standard.string(forKey: kNYXPrefDirectoryCovers)!
			let coversDirectoryURL = cachesDirectoryURL.appendingPathComponent(coversDirectoryName)

			do
			{
				try fileManager.removeItem(at: coversDirectoryURL)
				try fileManager.createDirectory(at: coversDirectoryURL, withIntermediateDirectories:true, attributes:nil)
			}
			catch _
			{
				Logger.alog("[!] Can't delete cover cache :<")
			}
		}

		if confirm
		{
			let alertController = UIAlertController(title:NYXLocalizedString("lbl_alert_purge_cache_title"), message:NYXLocalizedString("lbl_alert_purge_cache_msg"), preferredStyle:.alert)
			let cancelAction = UIAlertAction(title:NYXLocalizedString("lbl_cancel"), style:.cancel) { (action) in
			}
			alertController.addAction(cancelAction)
			let okAction = UIAlertAction(title:NYXLocalizedString("lbl_ok"), style:.destructive) { (action) in
				clearBlock()
			}
			alertController.addAction(okAction)
			present(alertController, animated:true, completion:nil)
		}
		else
		{
			clearBlock()
		}
	}
}

// MARK: - 
extension ServerVC : ZeroConfBrowserTVCDelegate
{
	func audioServerDidChange()
	{
		_clearCache(confirm: false)
	}
}

// MARK: - UITableViewDelegate
extension ServerVC
{
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
	{
		if indexPath.section == 1 && indexPath.row == 3
		{
			_clearCache(confirm: true)
		}
		tableView.deselectRow(at: indexPath, animated:true)
	}
}

// MARK: - UITextFieldDelegate
extension ServerVC : UITextFieldDelegate
{
	func textFieldShouldReturn(_ textField: UITextField) -> Bool
	{
		if textField === tfMPDName
		{
			tfMPDHostname.becomeFirstResponder()
		}
		else if textField === tfMPDHostname
		{
			tfMPDPort.becomeFirstResponder()
		}
		else if textField === tfMPDPort
		{
			tfMPDPassword.becomeFirstResponder()
		}
		else if textField === tfMPDPassword
		{
			textField.resignFirstResponder()
		}
		else if textField === tfWEBHostname
		{
			tfWEBPort.becomeFirstResponder()
		}
		else if textField === tfWEBPort
		{
			tfWEBCoverName.becomeFirstResponder()
		}
		else
		{
			textField.resignFirstResponder()
		}
		return true
	}
}
