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
    
    func savePhotosToPin(photoDataToSave: [[String : AnyObject]], pinToSaveTo: PinAnnotation) {
        
        for photo in photoDataToSave {
            if let imgURL = photo["url_m"] as? String, let photoID = photo["id"] as? String {
                let newPhoto = Photo(photoID: photoID, flickrURL: imgURL, context: managedObjectContect)
                newPhoto.pin = pinToSaveTo
                print(newPhoto.photoID)
            }
        }
        do {
            try managedObjectContect.save()
            print("\(photoDataToSave.count) photos saved")
        } catch {
            print("error saving photos")
        }
    }
    
    func savePhotoToDisk() {
        
    }
    
    private init() {}
}