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

//in setting up this class in the data model:
// - necessary to have the "ordered" box checked, so that it was possible to reference specific photos within the array (without "ordered" checked, calling something like "annotation.photos.first" causes a crash!  with ordering, it was possible to call .first)

class Photo: NSManagedObject {
    
    @NSManaged var photoID: String
    @NSManaged var flickrURL: String
    @NSManaged var pin: PinAnnotation?

    //computed property that returns the URL of the photo image file on disk (and in the cache); the URL is comprised of the documents directory and a unique file name which is based upoon the photoID (which is a unique identifier returned from Flickr)
    var photoURLonDisk: String? {
        return ImageFileManager.sharedInstance.getURLforFileOnDisk(photoID)
    }
    
    //computed property that, when accessed during collection view cell configuration, returns the saved value from the disk or returns nil; if this property returns nil when the cell calls for it, the cell congifuration then starts the downloading of the image which is then followed by setting this property equal to the freshly downladed image, thus invoking the setter observer below and the saving of the image to disk (and cache), which then leads to subsequent "get" calls to this property to return a non-nil image
    var photoImage: UIImage? {
        get {
            print("photoImage accessed")
            return ImageFileManager.sharedInstance.retrieveImageFromDisk(photoURLonDisk, checkCacheForURL: flickrURL)
        }
        set {
            ImageFileManager.sharedInstance.saveImageToDisk(newValue, photoURLonDisk: photoURLonDisk)
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(photoID: String, flickrURL: String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.photoID = photoID
        self.flickrURL = flickrURL
    }
    
    override func prepareForDeletion() {
        if ImageFileManager.sharedInstance.deleteImageFromDisk(photoURLonDisk, checkCacheForURL: flickrURL) {
            print("deleted successfully")
        } else {
            print("PROBLEM deleting")
        }
    }
}
