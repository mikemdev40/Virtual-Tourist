//
//  Client.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/25/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation

//client class that is responsible for performing all Flickr-related data tasks, including constructing URLs for interacting with FLickr's API, executing Flickr searches for images, retrieving the specific image file associated with each search result, and parsing all JSON data
class FlickrClient {
    
    //singleton object for instantiating only a single client
    static let sharedInstance = FlickrClient()
    
    ///this method executes a geo-based Flickr search using the latitude and longitude of the pin dropped by the user and returns the photo data via a passed completion handler as an array of dictionaries; this method is invoked in two places in the app: when the user first drops a pin (the request gets fired off immediately as soon as the pin is placed and returned asynchronously) and when the user taps the "get new collection" button within the photo album view controller
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
            
            //returned JSON data is parsed using a helper method, "parseData," defined below
            guard let parsedData = FlickrClient.parseData(data) else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing the data.")
                return
            }
            
            //what keys to look and how the data is strutured was determined by analyzing sample results using PostMan
            guard let photos = parsedData["photos"] as? NSDictionary else {
                completionHandler(success: false, photoArray: nil, error: "There was an error parsing out the photos.")
                return
            }
            guard let numPages = photos["pages"] as? Int else {
                completionHandler(success: false, photoArray: nil, error: "There was an error retrieving number of pages.")
                return
            }
            
            //the if statment below checks to see if the number of pages returned is more than 4 (see the related "MaxNumberPagesThatReturnResults" constant in the Constants class for the reason this value was used), and if so, finds a random page number between 1 and 4, then re-executes the Flickr serarch request with that specific page number as a parameter (by calling the very similar executeFlickrSearchForPageNumber method below)
            if numPages > Constants.FlickrClientConstants.FlickrAPI.MaxNumberPagesThatReturnResults {
                let randomPageNumberFromResults = Int(1 + arc4random_uniform(UInt32(Constants.FlickrClientConstants.FlickrAPI.MaxNumberPagesThatReturnResults)))
                self.executeFlickrSearchForPageNumber(latitude, longitude: longitude, optionalPageNumber: randomPageNumberFromResults, completionHandler: completionHandler)
                
                
            //else, we check to see if the number of pages returned is more than 2 (explained shortly), and if so, finds a random page number between 1 and that number and re-executes the image request with that specific page number minus 1; the reason for minus 1 is because there is a chance that the last page of results (which is known at this point to be either 1, 2, 3, or 4, but not greater than 4) contains only a handful of results (e.g. a photo return of 760 would be spread out across 4 pages like 250, 250, 250, 10; if page 4 got selected and results returned, there wouldnt be enough to make up the min number of images for the colletcion view, which is undesirable!).  the reason that numPages is being compared to the "MinPagesInResultBeforeResubmitting" constant (set to 2) is for that exact same reason -- if the number of pages in the result IS 2 (exactly), then there is a chance that the second page only has a handful, so in this case, we will always be getting images from the first page; there may be other ways to optimize this, but i also don't want to make more than two chained, successive API calls unless absolutely necessary!
            } else if numPages > Constants.FlickrClientConstants.FlickrAPI.MinPagesInResultBeforeResubmitting {
                
                //picks a random page number from the number of pages; example: if there are four pages (numPages = 4), then this would return a random number out of 1, 2, and 3, since arc4random returns a random number from 0 up to (argument minus 1), which would be 0, 1, or 2, and then plus 1 makes that 1, 2, and 3.
                let randomPageNumberFromResults = Int(1 + arc4random_uniform(UInt32(numPages - 1)))
                
                //note the addition of the optionalPageNumber parameter
                self.executeFlickrSearchForPageNumber(latitude, longitude: longitude, optionalPageNumber: randomPageNumberFromResults, completionHandler: completionHandler)
                
            //lastly, if there are either one or two pages of results, the data is cast to an array of NSDictionaries then finally cast to an array of Dictionaries which is passed back to the caller via the completion handler; note there is NO additional call (re-execution) of the Flickr search for this case, since we will always be using the first page of results (which is the default page returned by Flickr when no page number is specified)
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
    
    ///this method executes a geo-based Flickr search using the latitude and longitude of the pin, as well as a specific page number of results to return; this method is only called in certain cases within the method above, in particular, when the number of pages in the originally returned results is more than two
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
    
    ///this method retrieves and returns the image data associated with a single photo located on the web at a specific URL; this method is called from the PhotoAlbumViewController ; although this method does not does not directly interface with Flickr's API (and could also been appropriately placed within the PhotoAlbumViewController class), i decided to place it within the FlickrClient class because it is related to the process of obtaining Flickr photos
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
    
    ///private class helper method that takes JSON NSData and returns an optional NSDictionary (nil if there was an error converting it from JSON to a dictionary); the method utilizes NSJSONSerialization and related methods to convert JSON data to a readable format (i copied/pasted this helper method from my On the Map project! starting to really feel the helpfulness of helper methods -- no pun intended)
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
    
    ///private class helper method that creates the actual NSURL to be used with the NSURL request, utilizing the NSURLFromComponents class to safely construct an escaped/encoded URL; note the optional "optionalPageNumber" parameter (which is passed in with a value of nil when called from the original executeGeoBasedFlickrSearch method above and an actual page number when called from the executeGeoBasedFlickrSearchForageNumber method); this method utilizes many of the constants defined in the Contants class
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
        
        //almost forgot to unwrap this!  doing so would send "Optional(8)" as part of the URL string!
        if let optionalPageNumber = optionalPageNumber {
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
