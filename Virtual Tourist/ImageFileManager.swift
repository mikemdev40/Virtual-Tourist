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
    
//    private var imageCache = NSCache()
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
        
//        imageCache.setObject(photo, forKey: photoURL)
        
        //the decision between JPEG and PNG was based on http://stackoverflow.com/questions/3929281/when-to-use-png-or-jpg-in-iphone-development
        let photoData = UIImageJPEGRepresentation(photo, 1.0)
        photoData?.writeToFile(photoURL, atomically: true)
    }
    
    func retrieveImageFromDisk(photoURLonDisk: String?, checkCacheForURL: String?) -> UIImage? {
        guard let photoURLonDisk = photoURLonDisk else {
            return nil
        }
        
        //ADDED to take advantage of automatic caching that happens with URL requests! (rather than using a custom NSCache
        if let checkCacheForURL = checkCacheForURL {
            if let nsURL = NSURL(string: checkCacheForURL)  {
                if let cachedData = NSURLCache.sharedURLCache().cachedResponseForRequest(NSURLRequest(URL: nsURL)) {
                    if let photoFromCachedData = UIImage(data: cachedData.data) {
                        return photoFromCachedData
                    }
                }
            }
        }
        
//        if let photoImage = imageCache.objectForKey(photoURLonDisk) as? UIImage {
//            return photoImage
//        }
        
        if let photoData = NSData(contentsOfFile: photoURLonDisk) {
            if let photo = UIImage(data: photoData) {
//                imageCache.setObject(photo, forKey: photoURLonDisk)  //saves it to cache once it is loaded from the hard drive the first time
                return photo
            }
        }
        
        return nil
    }
    
    func deleteImageFromDisk(photoURL: String?, checkCacheForURL: String?) {
        guard let photoURL = photoURL else {
            return
        }

        //ADDED to take advantage of automatic caching that happens with URL requests!
        if let checkCacheForURL = checkCacheForURL {
            if let nsURL = NSURL(string: checkCacheForURL)  {
                NSURLCache.sharedURLCache().removeCachedResponseForRequest(NSURLRequest(URL: nsURL))
            }
        }
//        imageCache.removeObjectForKey(photoURL)
        
        do {
            try fileManager.removeItemAtPath(photoURL)
        } catch { }
    }
    
    private init() {}
    
}