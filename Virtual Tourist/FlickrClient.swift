//
//  Client.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/25/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation

class FlickrClient {
    
    struct FlickrConstants {
        struct FlickrAPIConstants {
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
            static let Radius = "0.25"
            static let RadiusUnits = "mi"
            static let MinDateOfPhoto = "2014-01-01 00:00:00"  //returns photos since january 1, 2014 (arbitrarily chosen)
        }
    }
    
    
}
