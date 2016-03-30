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
            
            if numPages > Constants.FlickrClientConstants.FlickrAPI.MinPagesInResultBeforeResubmitting {
                
                print("pages = \(numPages) RUNNING ... AGAIN!!!")
                
                let randomPageNumberFromResults = Int(1 + arc4random_uniform(UInt32(numPages) - 1))  //since arch4random_uniform will already return a value between 0 and the value passed minus 1, subtracting a SECOND 1 will make the page number go between 0 and numPages - 2, and then adding 1 will make that range 1 to (numPages - 1), which prevents us from selecting the zeroth page (which doesnt exist) and the last page, we we want to avoid since the last page may have very few images on it (which means the second last page is the final page that will definitely contain the max per page number of photos)
                
                let highestPossiblePageToSearch = (Constants.FlickrClientConstants.FlickrAPI.MaxNumResultsReturnedByFlickr / Constants.FlickrClientConstants.FlickrAPI.MaxNumResultsPerPage) - 1 //as of release, this equals 4000 / 250 = 16; we can only get images from the first 4000 results and at 250 results per page, this is the first 16 pages; and since we never want the last page (see comment above), we subtract 1
                
                let selectedPageNumber = min(randomPageNumberFromResults, highestPossiblePageToSearch)
                
                self.executeFlickrSearchForPageNumber(latitude, longitude: longitude, optionalPageNumber: selectedPageNumber, completionHandler: completionHandler)
                
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
                print("SUCCESS!!! grabbed from page \(optionalPageNumber)")
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
        
        print(NSURLFromComponents.URL!)
        return NSURLFromComponents.URL!
    }
    
    private init() {}
}
