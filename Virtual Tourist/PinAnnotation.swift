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

//when "upgrading" this class to an NSManaged class (i started with a non-Core Data MKAnnotation-conforming object and converted it to Core Data later in development), it was neccessary to remove the inheritance from NSObject (which was initially added to allow for MKAnnotation protocol conformance); i wanted to have this class conform to the MKAnnotation protocol so that these objects, when returned from core data, could be used immediately as annotations on the map (rather than having to create an intermediate set of annotations from objects of a non-MKannotation conforming class).
class PinAnnotation: NSManagedObject, MKAnnotation {
    
    //see comment below for the computed "coordinate" property for the rationale on why latitude and longitude were saved separately, rather than a single CLLocationCoordinate2D property
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    
    //the title and subtitle properties below were included in the PinAnnotation class as part of the MKAnnotation protocol, more for completeness than anything (as neither are not required properties for the protocol); neither property was used in this project, but instead of deleting these from the class, i kept them for the purpose of possible expansion at a later time; for the time being, each PinAnnoation object is initialized with title and subtitle as nil
    @NSManaged var title: String?
    @NSManaged var subtitle: String?
    
    //the photos property implements the one-to-many relationship that is defined in the core data model between a Pin and Photos; the property is marked as optional here since the pin object gets initialized with no initial photos (they are added later); this could alternatively been made non-optional with 0 being the default value (and value when no photos are returned from the flickr search); in the core data model, this relationship is also marked as optional in the core data model, because it is possible to persist the object with this relationship being nil (i.e. having no photos) (again, could alternatively have made it non optional with default 0)
    @NSManaged var photos: [Photo]?
    
    //coordinate is required for the MKAnnotation protocol so it was included, but it needed to be a computed property because CLLocationCoordinate2D was not a storable type in core data (being a struct, it does not form to NSCoding, which is required for use of a Core Data "transformable" type); however, Double is, so it was possible to store latitude and longitude and then compute the required CLLocationCoordinate2D coordinate from those values!  it should be noted that it would have, alternatively, been possible to utilize a transformable "location" property that is of type "CLLocation" in this class, since CLLocation DOES conform to NSCoding, and then just pull out the CLLocationCoordinate2D coordiate property from that CLLocation!  (in essence, this would be using a CLLocation object as a wrapper for the desired CLLocationCoordinate2D in the Core Data persistent store)
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    //standard init that is required for loading data from core data on startup (without this, there will be a crash)
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    //custom initializer that takes a NSManagedContext as part its pargument and calls the superclass initializer
    init(latitude: Double, longitude: Double, title: String?, subtitle: String?, context: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.subtitle = subtitle
    }
}
