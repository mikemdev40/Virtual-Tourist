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
    
    private struct Constants {
        struct FlickrAPI {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
        }
        
        // Flickr Parameter Keys
        struct FlickrParameterKeys {
            static let Method = "method"
            static let APIKey = "api_key"
            static let Extras = "extras"
            static let Format = "format"
            static let NoJSONCallback = "nojsoncallback" //From Flickr docs: If you just want the raw JSON, with no function wrapper, add the parameter nojsoncallback with a value of 1 to your request.
            static let SafeSearch = "safe_search"
            static let Radius = "radius"
            static let RadiusUnits = "radius_units"
            static let PhotosPerPage = "per_page"
            static let MinDateOfPhoto = "min_taken_date" //From Flickr docs: If no limiting factor is passed we return only photos added in the last 12 hours; this parameter serves as a limiting factor to ensure photos older than 12 hours are included
            
            //the associated values for the two keys below are determined by user and don't have pre-defined constant values
            static let Latitude = "lat"
            static let Longitude = "lon"
        }
        
        // MARK: Flickr Parameter Values
        struct FlickrParameterValues {
            static let Method = "flickr.photos.search"
            static let APIKey = "7c8a8afbc65c8a980d926cd402337580"
            static let Extras = "url_m"  //URLs to medium-sized images
            static let Format = "json"
            static let NoJSONCallback = "1"
            static let SafeSearch = "1"
            static let Radius = "5"
            static let RadiusUnits = "mi"
            static let PhotosPerPage = "500"  //the maximum allowed by Flickr
            static let MinDateOfPhoto = "2010-01-01"  //returns photos since january 1, 2010 (arbitrarily chosen)
        }
    }
    
    func executeGeoBasedFlickrSearch(latitude: Double, longitude: Double) {
        let session = NSURLSession.sharedSession()
        let request = NSURLRequest(URL: getFlickrURLForLocation(latitude, longitude: longitude))
    
    }
    
    private func getFlickrURLForLocation(latitude: Double, longitude: Double) -> NSURL {
        let parameters: [String: String] = [Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                          Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.Extras,
                          Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.Format,
                          Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.Method,
                          Constants.FlickrParameterKeys.MinDateOfPhoto: Constants.FlickrParameterValues.MinDateOfPhoto,
                          Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.NoJSONCallback,
                          Constants.FlickrParameterKeys.Radius: Constants.FlickrParameterValues.Radius,
                          Constants.FlickrParameterKeys.RadiusUnits: Constants.FlickrParameterValues.RadiusUnits,
                          Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.SafeSearch,
                          Constants.FlickrParameterKeys.Latitude: "\(latitude)",
                          Constants.FlickrParameterKeys.Longitude: "\(longitude)"]
        
        let NSURLFromComponents = NSURLComponents()
        NSURLFromComponents.scheme = Constants.FlickrAPI.APIScheme
        NSURLFromComponents.host = Constants.FlickrAPI.APIHost
        NSURLFromComponents.path = Constants.FlickrAPI.APIPath
        
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
