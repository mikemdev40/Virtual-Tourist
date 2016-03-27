//
//  DroppedAnnotation.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/25/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import MapKit
import CoreData

class PinAnnotation: NSManagedObject, MKAnnotation {  //when "upgrading" this class to an NSManaged class, it was neccessary to remove the inheritance from NSObject (which was initially added to allow for MKAnnotation protocol conformance)
    
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var title: String?
    @NSManaged var subtitle: String?
    @NSManaged var photos: [Photo]?
    
    //coordinate is required for the MKAnnotation protocol
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(latitude: Double, longitude: Double, title: String?, subtitle: String?, context: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.subtitle = subtitle
    }
}
