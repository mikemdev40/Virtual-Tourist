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

class PinAnnotation: NSManagedObject, MKAnnotation {  //when "upgrading" this class to an NSManaged class, it was neccessary to remove the inheritance from NSObject (which was initially added to allow for MKAnnotation protocol conformance); i wanted to have this class conform to the MKAnnotation protocol so that these objects, when returned from core data, could be used immediately as annotations on the map (rather than having to create an intermediate set of annotations from objects of a non-MKannotation conforming class).
    
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    
    //the title and subtitle properties were included in the PinAnnotation class as part of the MKAnnotation protocol, more for completeness than anything (as neither are not required properties for the protocol); neither property was used in this project, but instead of deleting these from the class, i kept them for the purpose of possible expansion at a later time; for the time being, each PinAnnoation object is initialized with title and subtitle as nil
    @NSManaged var title: String?
    @NSManaged var subtitle: String?
    @NSManaged var photos: [Photo]?
    
    //coordinate is required for the MKAnnotation protocol so it was included, but it needed to be a computer property because CLLocationCoordinate2D was not a storable type in core data; however, Double is, so it was possible to store latitude and longitude and then computer the coordinate from those values
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
