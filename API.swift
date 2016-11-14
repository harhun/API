//
//  API.swift
//
//  Created by Harhun on 01.09.16.
//  Copyright © 2016 Harhun. All rights reserved.
//

import Foundation
import Alamofire
import SVProgressHUD
import ObjectMapper

typealias AlamofireRequest = Alamofire.Request

final class API {

    private static let baseURL: String = "http://url.com/"
    
    var headers: [String: String] {
        get {
            return [
                "access_token": DataManager.sharedInstance.token,
            ]
        }
    }
    
    private enum Methods: String {
        case IdenitificationUser = "identifyuser"
        case SendSms = "sendsms"

        case GetFamilies = "families"
        case GetProductsByFamily = "familyproducts"
        case GetProductByPartname = "product"
        
        case GetUserDetails = "userdetails"
        case UpdateUserDetails = "updateuser"
        
        case GetDrinkTypes = "drinktypes"
        case GetCpasuleTypes = "cpasuletypes"
        case GetMachineTypes = "machines"
        case GetGiftByCapsuleType = "gift"
        
        case GetOpenOrder = "openorder"
        case GetOrderHistory = "orders"
        case GetOrderDetails = "orderinfo"

        case GetPacks = "packs"
        case GetPackInfo = "pack"
        
        case GetBanners = "banners"
        case GetCitiesBySubstring = "cities"
        case GetStreetsBySubstringAndCity = "street"
    }
    
    private func path(method: Methods) -> String {
        return API.baseURL + method.rawValue
    }
}

// MARK: - API Methods
extension API {
    
    /**
     Send sms
     */
    func sendSms(phone: String) -> API.Request {
        var currentHeaders = headers
        currentHeaders["phone_num"] = phone
        return API.Request(url: path(.SendSms), headers: currentHeaders)
    }
}

// MARK: - API Request Object

private typealias CompletionHandlers = [((result: AnyObject) -> ())?]
extension _ArrayType where Generator.Element == ((result: AnyObject) -> ())? {
    
    private func executeHandlers(result: AnyObject) {
        for clouser in self {
            clouser?(result: result)
        }
    }
}

private typealias FailureHandlers = [((error: API.Error) -> ())?]
extension _ArrayType where Generator.Element == ((error: API.Error) -> ())? {
    
    private func executeHandlers(error: API.Error) {
        for clouser in self {
            clouser?(error: error)
        }
    }
}

private typealias FinisheHandlers = [(() -> ())?]
extension _ArrayType where Generator.Element == (() -> ())? {
    
    private func executeHandlers() {
        for clouser in self {
            clouser?()
        }
    }
}

extension API {
    
    class Request {
        
        private var activityIndicatorView: UIView?
        private var errorClosure: ((error: API.Error) -> ())?
        
        // request params
        private let params: [String: AnyObject]?
        private let url: String
        private let method: Alamofire.Method
        private let headers: [String: String]?
        private let encoding: Alamofire.ParameterEncoding
        
        // handlers
        private var completionHandlers: CompletionHandlers = []
        private var failureHandlers: FailureHandlers = []
        private var finisheHandlers: FinisheHandlers = []
        
        // request
        private var request: AlamofireRequest?
        
        init(url: String, params: [String: AnyObject]? = nil, method: Alamofire.Method = .GET, headers: [String: String]? = nil, encoding: Alamofire.ParameterEncoding = .JSON) {
            
            self.params = params
            self.url = url
            self.method = method
            self.headers = headers
            self.encoding = encoding
        }
        
        // MARK: - Handlers
        /**
         Adds failure handler to be called once the request has finished.
         
         - parameter closure: failure clouser
         
         - returns: self
         */
        func addHandler(failure closure: (error: API.Error) -> ()) -> API.Request {
            self.failureHandlers.append(closure)
            return self
        }
        
        /**
         Adds completion handler to be called once the request has finished.
         
         - parameter closure: completion clouser
         
         - returns: self
         */
        
        func addHandler(completion closure: (result: AnyObject) -> ()) -> API.Request {
            self.completionHandlers.append(closure)
            return self
        }
        
        /**
         Adds finish handler to be called once the request has finished.
         
         - parameter closure: finish clouser
         
         - returns: self
         */
        func addHandler(finish closure: () -> ()) -> API.Request {
            self.finisheHandlers.append(closure)
            return self
        }
        
        // MARK: - Request control
        
        /**
         Execute the request
         */
        func execute() {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            request = Alamofire.request(method, url, parameters: params, encoding: encoding, headers: headers)
                .validate()
                .responseJSON { response in

                    var requestError: API.Error?
                    defer {
                        //
                        if let error = requestError {
                            self.failureHandlers.executeHandlers(error)
                            self.errorClosure?(error: error)
                        }
                        // network indicator off
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                        // call finish handler
                        self.finisheHandlers.executeHandlers()
                        // hide activity view if need
                        self.hideActivityView()
                        // enable user interaction if need
                        self.enableUserInteraction()
                        
                    }
                    
                    if let error = response.result.error {
                        requestError = API.Error(error: error)
                    }
                    
                    if let result = response.result.value {
                        if let code = (result["errorCode"] as? Int), let description = (result["errorDescription"] as? String) {
                            if let error = API.Error(code: API.Error.ErrorCodes(rawValue: code) ?? .UnknowError, errorDescription: description) {
                                requestError = error
                            } else {
                                self.completionHandlers.executeHandlers(result)
                            }
                        } else {
                            requestError = API.Error(code: .ServerResultCodeParseError, errorDescription: "ServerResultCodeParseError")!
                        }
                    }
                    
            }
        }
        
        /**
         Cancels the request.
         */
        func cancel() {
            request?.cancel()
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
        
        // MARK: - Alert
        func showAlertIfError(actions: UIAlertAction...) -> API.Request {
            errorClosure = { error in
                if var topController = UIApplication.sharedApplication().keyWindow?.rootViewController {
                    while let presentedViewController = topController.presentedViewController {
                        topController = presentedViewController
                        topController.showAlert("Error", message: error.localizedDescription ?? "", tapOk: nil)
                    }
                    
                    // topController should now be your topmost view controller
                }
                self.errorClosure = nil
            }
            return self
        }
        
        // MARK: - UserInteraction control
        func disableUserInteraction() -> API.Request {
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            appDelegate.window?.userInteractionEnabled = false
            return self
        }
        
        private func enableUserInteraction() {
            let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
            appDelegate.window?.userInteractionEnabled = true
        }
        
        // MARK: - Activity Indicator
        func addActivityIndicatorView() -> API.Request {
            SVProgressHUD.show()
            return self
        }
        
        private func hideActivityView() {
            SVProgressHUD.dismiss()
        }
        
    }
    
}


// MARK: - API Error Object
extension API {
    
    class Error: NSError {
        
        private static var domain = ".error"
        
        init(error: NSError) {
            super.init(domain: error.domain, code: error.code, userInfo: error.userInfo)
        }
        
        // errorCode
        // errorDescription
        init?(code: ErrorCodes, errorDescription: String) {
            if code == .Success { return nil }
            super.init(domain: API.Error.domain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: errorDescription])
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        enum ErrorCodes: Int, RawRepresentable {
            
            case Success = 0
            case InvalidAccessToken = 2
            case ErrorData = 3
            // unknow
            case UnknowError = -99
            // parse error
            case ServerResultCodeParseError = -999
        }
        
    }
    
}



