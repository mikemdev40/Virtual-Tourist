//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/26/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import CoreData

//in setting up this class in the data model:
// - necessary to have the "ordered" box checked, so that it was possible to reference specific photos within the array (without "ordered" checked, calling something like "annotation.photos.first" causes a crash!  with ordering, it was possible to call .first)
// - photoID and flickrURL are required, storedURL is optional and initially set to nil (gets set later); these properties in the data model also reflect this


class Photo: NSManagedObject {
    
    @NSManaged var photoID: String
    @NSManaged var flickrURL: String
    @NSManaged var storedURL: String?
    @NSManaged var pin: PinAnnotation?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(photoID: String, flickrURL: String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.photoID = photoID
        self.flickrURL = flickrURL
    }
}
