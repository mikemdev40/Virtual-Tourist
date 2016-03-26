//
//  DroppedAnnotation.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/25/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit

class PinAnnotation: NSObject, MKAnnotation {
    var latitude: Double
    var longitude: Double
    var title: String?
    var subtitle: String?
    var photos: [Photo]?
    
    //coordinate is required for the MKAnnotation protocol
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, title: String?, subtitle: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.subtitle = subtitle
    }
}
