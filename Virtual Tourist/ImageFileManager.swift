//
//  ImageFileManager.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/27/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import UIKit

//class that manages the saving and reading of photo images from the file system and cimage cache
class ImageFileManager {
    
    static let sharedInstance = ImageFileManager()
    
    private var imageCache = NSCache()
    private let fileManager = NSFileManager.defaultManager()
    
    func getURLforFileOnDisk(photoID: String) -> String? {
        if let documentsPath = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first {
            let URL = documentsPath.URLByAppendingPathComponent("\(photoID).jpg")
            return URL.path
        }
        return nil
    }
    
    func saveImageToDisk(photoToSave: UIImage?, photoURLonDisk: String?) {
        guard let photo = photoToSave, let photoURL = photoURLonDisk else {
            return
        }
        print("save photo to disk")
        
        imageCache.setObject(photo, forKey: photoURL)
        
        //the decision between JPEG and PNG was based on http://stackoverflow.com/questions/3929281/when-to-use-png-or-jpg-in-iphone-development
        let photoData = UIImageJPEGRepresentation(photo, 1.0)
        photoData?.writeToFile(photoURL, atomically: true)
    }
    
    func retrieveImageFromDisk(photoURL: String?) -> UIImage? {
        guard let photoURL = photoURL else {
            print("photourl nil")
            return nil
        }
        
        if let photoImage = imageCache.objectForKey(photoURL) as? UIImage {
            print("cache")
            return photoImage
        }
        
        if let photoData = NSData(contentsOfFile: photoURL) {
            print("nsdata")
            if let photo = UIImage(data: photoData) {
                imageCache.setObject(photo, forKey: photoURL)  //saves it to cache once it is loaded from the hard drive the first time
                return photo
            }
        }
        
        print("none")
        return nil
    }
    
    func deleteImageFromDisk(photoURL: String?) -> Bool {
        guard let photoURL = photoURL else {
            return false
        }
        
        imageCache.removeObjectForKey(photoURL)
        
        do {
            try fileManager.removeItemAtPath(photoURL)
            return true
        } catch {
            return false
        }
    }
    
    private init() {}
    
}