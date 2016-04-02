//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/26/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import CoreData
import UIKit

//in setting up this class in the data model, it was necessary to have the "ordered" box checked, so that it was possible to reference specific photos within the array (without "ordered" checked, calling something like "annotation.photos.first" causes a crash!  with ordering, it was possible to call .first)

class Photo: NSManagedObject {
    
    @NSManaged var photoID: String //this property is the Flickr objectID, a unique identifier that is returned by Flickr as part of the image data response
    @NSManaged var flickrURL: String //this property is the URL for the image located on the web (as opposed to the URL to the image saved on disk)
    
    //the pin property implements the inverse one-to-one relationship that is defined in the core data model between a Photo and Pin; the property is marked as optional here since i decided that i wanted to make the class potentially initializable without a known associated pin at the time (although i ended up not implementing it this way; rather, the in the core data stack, the pin property gets set immediately after initializing an instance of this class, so it would have been just as practicel - if not more so - to make this a non-optional property and have it a part of the argument list of the init method below). in the core data model, however, this relationship is NOT marked as optional in the core data model, because under no circumstance do we want a photo persisting in the database (or saved on the disk) without a pin attached to it (otherwise there would be no way to access that photo!).  side note - i was curious what would happen if context.save() was called on an object of this class withOUT the pin property set, and it resulted in "Cocoa Error 1560" via an on screen device alert rather than a crash!
    @NSManaged var pin: PinAnnotation?

    //computed property that returns the URL of the photo image file on disk (and in the cache); the URL is comprised of the documents directory and a unique file name which is based upoon the unique photoID
    var photoURLonDisk: String? {
        return ImageFileManager.sharedInstance.getURLforFileOnDisk(photoID)
    }
    
    //computed property that, when accessed during collection view cell configuration, returns the saved value from the disk or returns nil; if this property returns nil when the cell calls for it, the cell congifuration then starts the downloading of the image which is then followed by setting this property equal to the freshly downladed image, thus invoking the setter observer below and the saving of the image to disk (and cache), which then leads to subsequent "get" calls to this property to return a non-nil image
    var photoImage: UIImage? {
        get {
            //the "checkCacheForURL" argument is simply the web URL of the image, since the cache used in this project is the built-in caching mechanism that comes with the NSURL class, which utilizes the NSURLCache.sharedURLCache() instance and saves cache data based on the URL from which the object was downloaded
            return ImageFileManager.sharedInstance.retrieveImageFromDisk(photoURLonDisk, checkCacheForURL: flickrURL)
        }
        set {
            //the photo being save (newvalue) is being passed along wih the computed URL for the image on the disk, and the image is then saved to files directory; the photos are set explicitly within the PhotoAlbumViewController class
            ImageFileManager.sharedInstance.saveImageToDisk(newValue, photoURLonDisk: photoURLonDisk)
        }
    }
    
    //standard init that is required for loading data from core data on startup (without this, there will be a crash)
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    //custom initializer that takes a NSManagedContext as part its pargument and calls the superclass initializer; see commment above for the pin property about why i decided to make the pin not part of the initiailization (after viewing how the implementation turned out, it would perhaps have made sense to just make it part of the initialization, since when each Photo instance gets created, the next line assigns the pin property, but that's not how i decided to implement it and since it doesn't affect the user experience either way, i just kept it this way
    init(photoID: String, flickrURL: String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.photoID = photoID
        self.flickrURL = flickrURL
    }
    
    //inherited NSManaged method that causes the related image files that are saved on the disk and in the cache
    override func prepareForDeletion() {
        ImageFileManager.sharedInstance.deleteImageFromDisk(photoURLonDisk, checkCacheForURL: flickrURL)
    }
}
