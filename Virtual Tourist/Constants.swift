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
        static let MaxNumberOfPhotosToSavePerPin = 9
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
            static let MaxNumResultsReturnedByFlickr = 4000 //defined by flickr
            static let MaxNumResultsPerPage = 250 //defined by flickr, for geo-based searches
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