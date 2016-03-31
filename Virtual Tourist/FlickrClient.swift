//
//  Client.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/25/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation

class FlickrClient {
    
    static let sharedInstance = FlickrClient()
    
    func executeGeoBasedFlickrSearch(latitude: Double, longitude: Double, completionHandler: (success: Bool, photoArray: [[String: AnyObject]]?, error: String?) -> Void) {
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: getFlickrURLForLocation(latitude, longitude: longitude, optionalPageNumber: nil))
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            guard error == nil else {
                completionHandler(success: false, photoArray: nil, error: error?.localizedDescription)
                return
            }
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                completionHandler(success: false, photoArray: nil, error: "Unsuccessful status code.")
                return
            }
            guard let data = data else {
                completionHandler(success: false, photoArray: nil, error: "There was an error getting the data.")
                return
            }
            guard let parsedData = FlickrClient.parseData(data) else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing the data.")
                return
            }
            guard let photos = parsedData["photos"] as? NSDictionary else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing out the photos.")
                return
            }
            guard let numPages = photos["pages"] as? Int else {
                completionHandler(success: false, photoArray: nil, error: "There was an error retrieving number of pages.")
                return
            }
            
            if numPages > Constants.FlickrClientConstants.FlickrAPI.MaxNumberPagesThatReturnResults {  //checks to see if the number of pages returned is more than 4 (see constants for why), and if so, finds a random page number between 1 and 4 and re-executes the image request with that specific page number
                let randomPageNumberFromResults = Int(1 + arc4random_uniform(UInt32(Constants.FlickrClientConstants.FlickrAPI.MaxNumberPagesThatReturnResults)))
                self.executeFlickrSearchForPageNumber(latitude, longitude: longitude, optionalPageNumber: randomPageNumberFromResults, completionHandler: completionHandler)
                
            } else if numPages > Constants.FlickrClientConstants.FlickrAPI.MinPagesInResultBeforeResubmitting {  //checks to see if the number of pages returned is more than 2, and if so, finds a random page number between 1 and that number and re-executes the image request with that specific page number - 1; the reason for minus 1 is because there is a chance that the last page of results (which is known at this point to be either 1, 2, 3, or 4, but not greater than 4) contains only a handful of results (e.g. a photo return of 760 would be spread out across 4 pages like 250, 250, 250, 10; if page 4 got selected and run, there wouldnt be enough to make up the min number of images for the colletcion view, which is undesirable!  the reason that numPages is being compared to the "MinPagesInResultBeforeResubmitting" constant (set to 2) is for that exact same reason -- if the number of pages in the result IS exaclty 2, then there is a chance that the second page only has a handful, so in this case, we will always be getting images from the first page
                
                let randomPageNumberFromResults = Int(1 + arc4random_uniform(UInt32(numPages - 1))) //example: if there are four pages (numPages = 4), then this would return a random number out of 1, 2, and 3, since arc4random returns a random number from 0 up to (argument minus 1), which would be 0, 1, or 2, and then plus 1 makes that 1, 2, and 3.
                
                self.executeFlickrSearchForPageNumber(latitude, longitude: longitude, optionalPageNumber: randomPageNumberFromResults, completionHandler: completionHandler)
                
            } else {
            
                guard let photo = photos["photo"] as? [NSDictionary] else {
                    completionHandler(success: false, photoArray: nil, error: "There was an error parsing out the array.")
                    return
                }
                
                //if data retrieval is successful, the results are passed back to the original caller through the passed in completion handler
                if let photoArray = photo as? [[String: AnyObject]] {
                    completionHandler(success: true, photoArray: photoArray, error: nil)
                } else {
                    completionHandler(success: false, photoArray: nil, error: "There was an error casting to array.")
                }
            }
        }
        task.resume()
    }
    
    func executeFlickrSearchForPageNumber(latitude: Double, longitude: Double, optionalPageNumber: Int, completionHandler: (success: Bool, photoArray: [[String: AnyObject]]?, error: String?) -> Void) {
        
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: getFlickrURLForLocation(latitude, longitude: longitude, optionalPageNumber: optionalPageNumber))
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            guard error == nil else {
                completionHandler(success: false, photoArray: nil, error: error?.localizedDescription)
                return
            }
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                completionHandler(success: false, photoArray: nil, error: "Unsuccessful status code.")
                return
            }
            guard let data = data else {
                completionHandler(success: false, photoArray: nil, error: "There was an error getting the data.")
                return
            }
            guard let parsedData = FlickrClient.parseData(data) else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing the data.")
                return
            }
            guard let photos = parsedData["photos"] as? NSDictionary else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing out the photos.")
                return
            }
            
            guard let photo = photos["photo"] as? [NSDictionary] else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing out the array.")
                return
            }
            
            //if data retrieval is successful, the results are passed back to the original caller through the passed in completion handler
            if let photoArray = photo as? [[String: AnyObject]] {
                completionHandler(success: true, photoArray: photoArray, error: nil)
            } else {
                completionHandler(success: false, photoArray: nil, error: "There was an error casting to array.")
            }
        }
        task.resume()
    }
    
    func getImageForUrl(url: String, completionHandler: (data: NSData?, error: String?) -> Void) {
        
        guard let imageNSURL = NSURL(string: url) else {
            return
        }
        
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: imageNSURL)
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            guard error == nil else {
                completionHandler(data: nil, error: error?.localizedDescription)
                return
            }
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                completionHandler(data: nil, error: "Unsuccessful status code")
                return
            }
            guard let data = data else {
                completionHandler(data: nil, error: "There was an error getting the data.")
                return
            }
            
            completionHandler(data: data, error: nil)
        }
        task.resume()
    }
    
    ///class helper method that takes JSON NSData and returns an optional NSDictionary (nil if there was an error converting it from JSON to a dictionary); the method utilizes NSJSONSerialization and related methods; this method is used many times throughout this class to convert JSON data to a readable format
    private class func parseData(dataToParse: NSData) -> NSDictionary? {
        let JSONData: AnyObject?
        do {
            JSONData = try NSJSONSerialization.JSONObjectWithData(dataToParse, options: .AllowFragments)
        } catch {
            return nil
        }
        guard let parsedData = JSONData as? NSDictionary else {
            return nil
        }
        return parsedData
    }
    
    private func getFlickrURLForLocation(latitude: Double, longitude: Double, optionalPageNumber: Int?) -> NSURL {
        var parameters: [String: String] = [Constants.FlickrClientConstants.FlickrParameterKeys.APIKey: Constants.FlickrClientConstants.FlickrParameterValues.APIKey,
                          Constants.FlickrClientConstants.FlickrParameterKeys.Extras: Constants.FlickrClientConstants.FlickrParameterValues.Extras,
                          Constants.FlickrClientConstants.FlickrParameterKeys.Format: Constants.FlickrClientConstants.FlickrParameterValues.Format,
                          Constants.FlickrClientConstants.FlickrParameterKeys.Method: Constants.FlickrClientConstants.FlickrParameterValues.Method,
                          Constants.FlickrClientConstants.FlickrParameterKeys.MinDateOfPhoto: Constants.FlickrClientConstants.FlickrParameterValues.MinDateOfPhoto,
                          Constants.FlickrClientConstants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrClientConstants.FlickrParameterValues.NoJSONCallback,
                          Constants.FlickrClientConstants.FlickrParameterKeys.Radius: Constants.FlickrClientConstants.FlickrParameterValues.Radius,
                          Constants.FlickrClientConstants.FlickrParameterKeys.RadiusUnits: Constants.FlickrClientConstants.FlickrParameterValues.RadiusUnits,
                          Constants.FlickrClientConstants.FlickrParameterKeys.SafeSearch: Constants.FlickrClientConstants.FlickrParameterValues.SafeSearch,
                          Constants.FlickrClientConstants.FlickrParameterKeys.Latitude: "\(latitude)",
                          Constants.FlickrClientConstants.FlickrParameterKeys.Longitude: "\(longitude)"]
        
        if let optionalPageNumber = optionalPageNumber {  //almost forgot to unwrap this!  doing so sends "Optional(8)" as part of the URL string!
            parameters[Constants.FlickrClientConstants.FlickrParameterKeys.PageNumber] = "\(optionalPageNumber)"
        }
        
        let NSURLFromComponents = NSURLComponents()
        NSURLFromComponents.scheme = Constants.FlickrClientConstants.FlickrAPI.APIScheme
        NSURLFromComponents.host = Constants.FlickrClientConstants.FlickrAPI.APIHost
        NSURLFromComponents.path = Constants.FlickrClientConstants.FlickrAPI.APIPath
        
        var queryItems = [NSURLQueryItem]()
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: value)
            queryItems.append(queryItem)
        }
        
        NSURLFromComponents.queryItems = queryItems
        
        return NSURLFromComponents.URL!
    }
    
    private init() {}
}
