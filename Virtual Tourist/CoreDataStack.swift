//
//  CoreDataStack.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/26/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import CoreData

class CoreDataStack {
    
    static let sharedInstance = CoreDataStack()
    
    lazy var managedObjectContect: NSManagedObjectContext = {
        
        //part of this coding block inspired by the Core Data Programming Guide: https://developer.apple.com/library/tvos/documentation/Cocoa/Conceptual/CoreData/InitializingtheCoreDataStack.html#//apple_ref/doc/uid/TP40001075-CH4-SW1
        
        guard let modelURL = NSBundle.mainBundle().URLForResource("Model", withExtension: "momd") else {
            fatalError("Error loading the model from the bundle")
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL) else {
            fatalError("Error initializing the managed object model")
        }
        
        let persistentCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        
        let context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentCoordinator
        
        let urlForDocDirectory = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
        let urlForSQLDB = urlForDocDirectory?.URLByAppendingPathComponent("DataModel.sqlite")
        
        do {
            try persistentCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: urlForSQLDB, options: nil)
        } catch {
            fatalError("Error adding persistent store")
        }
        
        print("Core Data Stack loaded successfully")
        return context
    }()
    
    func savePhotosToPin(photoDataToSave: [[String : AnyObject]], pinToSaveTo: PinAnnotation, maxNumberToSave: Int) {

        var photoDataToSaveMutable = photoDataToSave

        if photoDataToSave.count > Constants.MapViewConstants.MaxNumberOfPhotosToSavePerPin {
            
            photoDataToSaveMutable.shuffle() //see Array extension in the Constants file for this method; this is used to shuffle the array of photos (since it contains many more than needed), so that the user is getting a random set of photos from whatever page of image results gets returned from flickr; this is more important for locations that return fewer results (because locations with lots of pages of image results will already be somewhat randomized when a random page number is used to extract the images from)
            print("Shuffled!!")
        }
        
        if photoDataToSaveMutable.count > maxNumberToSave {
            for photoNum in 0...(maxNumberToSave - 1) {
                if let imgURL = photoDataToSaveMutable[photoNum]["url_m"] as? String, let photoID = photoDataToSaveMutable[photoNum]["id"] as? String {
                    let newPhoto = Photo(photoID: photoID, flickrURL: imgURL, context: managedObjectContect)
                    newPhoto.pin = pinToSaveTo
                }
            }
        } else {
            for photo in photoDataToSaveMutable {
                if let imgURL = photo["url_m"] as? String, let photoID = photo["id"] as? String {
                    let newPhoto = Photo(photoID: photoID, flickrURL: imgURL, context: managedObjectContect)
                    newPhoto.pin = pinToSaveTo
                }
            }
        }

        do {
            try managedObjectContect.save()
        } catch {
            print("error saving photos")
        }
    }
    
    private init() {}
}