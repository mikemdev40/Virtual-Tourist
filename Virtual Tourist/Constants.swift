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
}