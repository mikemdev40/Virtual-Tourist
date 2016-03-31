//
//  Constants.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/28/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import MapKit

class Constants {
    struct MapViewConstants {
        static let LongPressDuration = 0.5
        static let ShowPhotoAlbumSegue = "ShowPhotoAlbum"
        static let MaxNumberOfPhotosToSavePerPin = 30
    }
    
    struct PhotoAlbumConstants {
        static let SpanDeltaLongitude: CLLocationDegrees = 2
        static let CellVerticalSpacing: CGFloat = 4
        static let CellAlphaWhenSelectedForDelete: CGFloat = 0.35
    }
    
    struct FlickrClientConstants {
        struct FlickrAPI {
            static let APIScheme = "https"
            static let APIHost = "api.flickr.com"
            static let APIPath = "/services/rest"
            static let MinPagesInResultBeforeResubmitting = 2
            static let MaxNumberPagesThatReturnResults = 4 //this was determined via experimentation with Flickr API; for large sets of images, only the first 4 pages actually return photo data (even though the documentation says 4000 photos, it's actually 4 pages of 250 each); page 5 and on return none.
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
            static let PageNumber = "page"
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
            static let Radius = "10"
            static let RadiusUnits = "mi"
            static let MinDateOfPhoto = "2010-01-01"  //returns photos since january 1, 2010 (arbitrarily chosen)
        }
    }
}

//shuffle technique used to shuffle the array of returned photos; this code is sourced from: https://www.hackingwithswift.com/example-code/arrays/how-to-shuffle-an-array-in-ios-8-and-below and http://stackoverflow.com/questions/32689753/fatal-error-swapping-a-location-with-itself-is-not-supported-with-swift-2-0
extension Array {
    mutating func shuffle() {
        for i in 0 ..< (count - 1) {
            let j = Int(arc4random_uniform(UInt32(count - i))) + i
            if j != i {
                swap(&self[i], &self[j])
            }
        }
    }
}