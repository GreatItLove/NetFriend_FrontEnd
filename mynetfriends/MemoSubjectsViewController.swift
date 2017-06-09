//
//  EmailViewController.swift
//  mynetfriends
//
//  Created by Admin User on 5/29/17.
//  Copyright © 2017 Farid. All rights reserved.
//

import UIKit
import QuartzCore
import SwiftyJSON
import Alamofire
import MBProgressHUD


extension UITextField{
    func setBorder(color : UIColor){
        self.layer.borderColor = color.cgColor
        self.layer.borderWidth=1.0
        self.layer.cornerRadius = 5.0
        self.layer.masksToBounds = true
    }
}

extension NSLayoutConstraint {
    /**
     Change multiplier constraint
     
     - parameter multiplier: CGFloat
     - returns: NSLayoutConstraint
     */
    func setMultiplier(multiplier:CGFloat) -> NSLayoutConstraint {
        
        NSLayoutConstraint.deactivate([self])
        
        let newConstraint = NSLayoutConstraint(
            item: firstItem,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant)
        
        newConstraint.priority = priority
        newConstraint.shouldBeArchived = self.shouldBeArchived
        newConstraint.identifier = self.identifier
        
        NSLayoutConstraint.activate([newConstraint])
        return newConstraint
    }
}


class EmailViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    @IBOutlet weak var usernameField: UILabel!
    @IBOutlet weak var subjectField: UITextField!
    @IBOutlet weak var memoField: UITextField!
    
    @IBOutlet weak var subjectListView: UITableView!
    
    ////Message Send View Layout and Controllers/////////
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var msgViewHeight: NSLayoutConstraint!
    @IBOutlet weak var timeStandardLabel: UIStackView!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var sendingTimeLabel: UILabel!
    @IBOutlet weak var messageSendView: UIView!
    
    var activeMessageView : MessageViewController!
    
    
    var slider_time : Float = 0
    
    var subjects : [SubjectModel] = []
    var badge : Int = 0
    
    var hud : MBProgressHUD!
    var imagePicker = UIImagePickerController()
    
    @IBOutlet weak var avatar: UIImageView!
    
    @IBAction func onTimeChanged(_ sender: UISlider!) {
       // sender.value
        let int_val = Int(sender.value)
        let delta = sender.value - Float(int_val)
        
        let min = Float(Constants.timeit[int_val]) + Float(Constants.timeit[int_val + 1] - Constants.timeit[int_val]) * delta
        slider_time = min
        if min > 1{
            sendingTimeLabel.text = "\(Int(min)) mins"
        } else {
            sendingTimeLabel.text = "\(Int(min * 60)) secs"
        }
    }
    
    @IBAction func onTimeSliderShow(_ sender: Any) {
        if timeSlider.isHidden {
            timeSlider.isHidden = false; timeStandardLabel.isHidden = false; sendingTimeLabel.isHidden = false
            msgViewHeight = msgViewHeight.setMultiplier(multiplier: 180 / 1334 )
        } else {
            timeSlider.isHidden = true;  timeStandardLabel.isHidden = true;  sendingTimeLabel.isHidden = true
            msgViewHeight = msgViewHeight.setMultiplier(multiplier: 140 / 1334 )
        }
        
        
        view.layoutIfNeeded()
    }
    
    @IBAction func onTimeItSend(_ sender: Any) {
        if subjectField.text! == "" || memoField.text! == "" {
            return
        }
        
        Api.addSubject(name: subjectField.text!, user_id: test_user_id, channel_id: 0, completion: { (response) in
            if response == nil || response["success"] == 0 {
                return
            }
            Api.newMessage(subject_id: response["data"]["id"].int!, memo: self.memoField.text!, user_id: test_user_id, timeit : self.slider_time, completion: { (resp) in
                if response == nil || resp["success"] == 0 {
                    return
                }
                let subject = SubjectModel( data: response["data"] )
                
                subject.lastMessage = resp["data"][0]["memo"].string!
                subject.lastMessageReceivedTime = resp["data"][0]["arriving_time"].string!
                
                self.subjects.insert(subject, at: 0)
                
                DispatchQueue.main.async{
                    self.subjectListView.reloadData()
                }
                
                var parameter : [String:Any] = [:]
                parameter["time"] = resp["data"][0]["arriving_time"].string
                SocketIOManager.sharedInstance.sendTimeItMessage(parameters: parameter)
                
                self.subjectField.text = ""
                self.memoField.text = ""
            })
                
        })
        
    }
    
    @IBAction func phoneCall(_ sender: Any) {
        print(messageSendView.frame.origin.y)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        usernameField.text = usernames[test_user_id]
        subjectField.setBorder(color: Constants.textFieldBorderColor)
        memoField.setBorder(color: Constants.textFieldBorderColor)
        subjectField.delegate = self
        memoField.delegate = self
        
        timeSlider.setThumbImage(UIImage(named: "thumb_icon"), for:UIControlState.normal)
      
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(EmailViewController.onReceiveMessage(_:)), name: NSNotification.Name(rawValue: "newChatMessage"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(EmailViewController.onSubjectStatus(_:)), name: NSNotification.Name(rawValue: "newSubjectStatus"), object: nil)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(EmailViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        tap.cancelsTouchesInView = false
        
        let avatarTap : UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(EmailViewController.changeAvatar(tapGestureRecognizer:)))
        avatar.addGestureRecognizer(avatarTap)
        
        
        subjectListView.delegate = self
        subjectListView.dataSource = self
        
        imagePicker.delegate = self
        
        getSubjectList()
        // Do any additional setup after loading the view.
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //////////JUST TEST FOR AVATAR//////////////
        if let imageData = UserDefaults.standard.value(forKey: "avatar") {
            avatar.image = UIImage(data: imageData as! Data)!
        }
    }
    
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.messageSendView.frame.origin.y + self.messageSendView.frame.size.height + Constants.tabbarHeight + 1.0 > self.view.frame.height {
                UIView.animate(withDuration: 0.1,
                               delay: 0.0,
                               options: UIViewAnimationOptions.curveEaseIn,
                               animations: { () -> Void in
                                self.bottomLayoutConstraint.constant += (keyboardSize.height - Constants.tabbarHeight)
                                self.view.layoutIfNeeded()
                }, completion: nil)
                
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.messageSendView.frame.origin.y + self.messageSendView.frame.size.height + Constants.tabbarHeight - 1.0 < self.view.frame.height{
                UIView.animate(withDuration: 0.1,
                               delay: 0.0,
                               options: UIViewAnimationOptions.curveEaseIn,
                               animations: { () -> Void in
                                self.bottomLayoutConstraint.constant -= (keyboardSize.height - Constants.tabbarHeight)
                                self.view.layoutIfNeeded()
                }, completion: nil)
            }
        }
    }
        
    func changeAvatar(tapGestureRecognizer: UITapGestureRecognizer){
        imagePicker.allowsEditing = true
        imagePicker.sourceType = .photoLibrary
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]){
        if let editedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.avatar.contentMode = .scaleAspectFit
            self.avatar.image = editedImage
        } else if let orginalImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            self.avatar.contentMode = .scaleAspectFit
            self.avatar.image = orginalImage
        } 
        else{
            print ("error")
        }
        
        UserDefaults.standard.set(UIImageJPEGRepresentation(self.avatar.image!, 100), forKey: "avatar")
        
        self.dismiss(animated: true, completion: nil)
    }
    
    
    func getSubjectList(){
        Api.getSubjectList(channel_id: 0, completion: { (response) -> Void in
            if response == nil || response["success"] == 0 {
                return
            }
            let cnt = response["data"].count
            self.subjects = Array<Any>(repeating: SubjectModel(), count: cnt) as! [SubjectModel]
            
            var count = 0
            
            for i in 0..<cnt {
                let subject = SubjectModel( data: response["data"][i] )
                
                Api.getLastMessageWithSubject(subject_id: response["data"][i]["id"].int!, user_id: test_user_id, completion: { (resp) in
                    subject.lastMessage = resp["data"].count > 0 ? resp["data"][0]["memo"].string! : ""
                    subject.lastMessageReceivedTime = resp["data"].count > 0 ? resp["data"][0]["arriving_time"].string! : ""
                    
                    self.subjects[i] = subject
                    count = count + 1
                    if count == cnt {
                        DispatchQueue.main.async{
                            var i = 0
                            while i < self.subjects.count {
                                if self.subjects[i].lastMessage == "" {
                                    self.subjects.remove(at: i)
                                } else {
                                    i = i + 1
                                }
                            }
                            self.subjectListView.reloadData()
                        }
                    }
                })
                
            }
        })
    }
    
    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    func onReceiveMessage(_ notification: NSNotification) {
        
        let response = JSON(notification.userInfo!)
        
        // Now set the badge of the third tab
        
        var j = 0, i = 0
        while i < response["data"].count {
            let id = response["data"][i]["subject_id"].int!
            if response["data"][i]["isLock"].bool! {
                i = i + 1
                continue
            }
            while ((j < subjects.count) && (id != subjects[j].id)){
                j = j + 1
            }
            if j == subjects.count {
                while (i < response["data"].count){
                    let subject = SubjectModel( data: response["data"][i] )
                    subject.lastMessage = response["data"][i]["memo"].string!
                    subject.lastMessageReceivedTime = response["data"][i]["arriving_time"].string!
                    if subjects.count > 0 && subject.id == subjects[0].id {
                        let tmp = subjects[0].nNewMessage
                        subjects[0] = subject
                        subjects[0].nNewMessage = tmp + 1
                    } else {
                        subject.nNewMessage = 1
                        subjects.insert(subject, at: 0)
                    }
                    
                    i = i + 1
                }
                
                break
            }
            subjects[j].lastMessage = response["data"][i]["memo"].string!
            subjects[j].nNewMessage = subjects[j].nNewMessage + 1
            
            i = i + 1
        }
        
        subjectListView.reloadData()
        
        badge += response["data"].count
        self.tabBarItem.badgeValue = String(badge)
        
        if activeMessageView != nil{
            activeMessageView.getMessages()
        }
        
        
    }
    
    func onSubjectStatus(_ notification: NSNotification) {
        print("subjectStatus changed")
        let response = JSON(notification.userInfo!)
        let id = response["subject_id"].int!
        for subject in subjects{
            if subject.id == id {
                subject.isLock = response["isLock"].bool!
            }
        }
        subjectListView.reloadData()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subjects.count
    }
    
    func numberOfSectionsInTableView(tableView: UITableView!) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "subjectCell", for: indexPath) as! SubjectListTableViewCell

        if subjects[indexPath.row].createdTime == "" {
            return cell
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        let date = dateFormatter.date(from: subjects[indexPath.row].createdTime)
        
        
        if subjects[indexPath.row].isLock {
            cell.lockBtn.setImage(UIImage(named: "redCircleWithArrow"), for: UIControlState.normal)
        } else {
            cell.lockBtn.setImage(UIImage(named: "greenCircleWithArrow"), for: UIControlState.normal)
        }
        
        if subjects[indexPath.row].nNewMessage > 0{
            cell.lastMessageLabel.font = UIFont.boldSystemFont(ofSize: 18.0)
        } else {
            cell.lastMessageLabel.font = UIFont.systemFont(ofSize: 17.0)
        }
        cell.lastMessageLabel.text = subjects[indexPath.row].lastMessage
        
        let arriving_date = dateFormatter.date(from: subjects[indexPath.row].lastMessageReceivedTime)
        
        if arriving_date! < Date() {
            cell.lastMessageStatus.image = UIImage(named: "greenarrow")
        } else {
            cell.lastMessageStatus.image = UIImage(named: "redarrow")
        }
        
        dateFormatter.dateFormat = "dd/MM/yy"
        cell.createdTime.text = dateFormatter.string(from: date!)
        cell.nameLabel.text = "(" + subjects[indexPath.row].name + ")"
        
        return cell
    }
        
    func tableView(_  tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if subjects[indexPath.row].createdTime == "" {
            return
        }
        
        performSegue(withIdentifier: "subjecttomessage", sender: self)
    }
    
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        if segue.identifier == "subjecttomessage" {
            let controller = segue.destination as! MessageViewController
            activeMessageView = controller
            let id = subjectListView.indexPathForSelectedRow?.row
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            let date = dateFormatter.date(from: subjects[id!].createdTime)
            dateFormatter.dateFormat = "dd/MM/yy h:mm a"
            
            controller.subject = subjects[id!]
            controller.createdText = "Subject Created on " + dateFormatter.string(from: date!)
            controller.pntController = self
            controller.subject_id = id!

            ////////Remove Badge When you open incoming message and also make it all read.....////////
            badge = badge - subjects[id!].nNewMessage
            subjects[id!].nNewMessage = 0
            if badge == 0 {
                self.tabBarItem.badgeValue = nil
            } else {
                self.tabBarItem.badgeValue = String(badge)
            }
            
            subjectListView.reloadData()
        }
    }
 

}
