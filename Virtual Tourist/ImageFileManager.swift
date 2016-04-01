//
//  ImageFileManager.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/27/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import Foundation
import UIKit

//class that manages the saving and reading of photo images from the file system and image cache (which is implemented via the NSURLCache.sharedURLCache object)
class ImageFileManager {
    
    static let sharedInstance = ImageFileManager()  //singleton object for instantiating only a single client
    
    /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
      private var imageCache = NSCache()
       --- */
    
    private let fileManager = NSFileManager.defaultManager()
    
    ///this helper method creates and returns the URL for the image file for the Photo with the specific [unique] objectID, as located on the disk within the document directory; this method is called explicitly from within the NSManaged Photo class as part of the photoURLonDisk computed property (which is relied upon for the getter and setter of the photoImage property of the Photo class, as well as the prepareForDeletion method)
    func getURLforFileOnDisk(photoID: String) -> String? {
        if let documentsPath = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first {
            let URL = documentsPath.URLByAppendingPathComponent("\(photoID).jpg")
            return URL.path
        }
        return nil
    }
    
    ///this method saves a UIImage to disk as an NSData object as created from a JPEG representation of the UIImage; this method is used exclusively by the Photo class, as part of the photoImage property's setter
    func saveImageToDisk(photoToSave: UIImage?, photoURLonDisk: String?) {
        guard let photo = photoToSave, let photoURL = photoURLonDisk else {
            return
        }

        /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
        imageCache.setObject(photo, forKey: photoURL)
        --- */
        
        //the decision between JPEG and PNG was based on http://stackoverflow.com/questions/3929281/when-to-use-png-or-jpg-in-iphone-development
        let photoData = UIImageJPEGRepresentation(photo, 1.0)
        photoData?.writeToFile(photoURL, atomically: true)
    }
    
    ///this method retrives and returns a UIImage from the disk; it takes as arguments the URL of the photo disk, as well as the URL of the image located on the web (which, i discovered, is how the NSURLCache stores and locates cached data from NSURL requests); it FIRST checks to see if the image exists in the cache, and if so, returns the image from the cache; if the image is NOT located in the cache (i.e. the cached item expired and/or is otherwise purged by the system -- or the item hasn't yet been downloaded), THEN it checks to see if it is located on the disk, and if so, reads and loads it from the document directory. i decided to use caching for this app because it is very likely that a user will scroll rapidly up and down the collection view looking and relooking at images, so to make this process as smooth as possible for the user, a memory-based cached image is accessed first (if possible) before loading from the disk; although i tested on a fast device and there was no noticable difference either way, there may be performance implications for older or slower devices; i decided to utilize the built-in NSURLCache class because it is built-in and automatic, and i presume is built specifically to optimize the caching of data from NSURL requests (as opposed to manually creating and working with an NSCache object). this method is called exlusively within the getter of the Photo class' photoImage property, which is accessed within the collection view's cellForItemAtIndexPath datasource method as it sets up its cells (a return of nil from this method prompts the initial download of the image)
    func retrieveImageFromDisk(photoURLonDisk: String?, checkCacheForURL: String?) -> UIImage? {
        guard let photoURLonDisk = photoURLonDisk else {
            return nil
        }
        
        //this utilizes the cachedResponseForRequest method to return an NSCachedURLResponse cached data object from the passed in URL, then creates a UIImage using the data property (type NSData) on that cached data object
        if let checkCacheForURL = checkCacheForURL {
            if let nsURL = NSURL(string: checkCacheForURL)  {
                if let cachedData = NSURLCache.sharedURLCache().cachedResponseForRequest(NSURLRequest(URL: nsURL)) {
                    if let photoFromCachedData = UIImage(data: cachedData.data) {
                        return photoFromCachedData
                    }
                }
            }
        }
        
        /* --- lines below UNUSED (i want to retain these lines as comments for personal future review)
        if let photoImage = imageCache.objectForKey(photoURLonDisk) as? UIImage {
            return photoImage
        }
        --- */
        
        if let photoData = NSData(contentsOfFile: photoURLonDisk) {
            if let photo = UIImage(data: photoData) {
                /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
                imageCache.setObject(photo, forKey: photoURLonDisk)  //saves it to cache once it is loaded from the hard drive the first time
                --- */
                return photo
            }
        }
        
        return nil
    }
    
    ///this method removes the photo file from the cache as well as from disk; this method is called exclusively by the Photo class in its prepareForDeletion method call (i.e. just as the object gets deleted, its associated image files are also deleted)
    func deleteImageFromDisk(photoURL: String?, checkCacheForURL: String?) {
        guard let photoURL = photoURL else {
            return
        }

        //removes the image from the cache (if it currently exists in the cache)
        if let checkCacheForURL = checkCacheForURL {
            if let nsURL = NSURL(string: checkCacheForURL)  {
                NSURLCache.sharedURLCache().removeCachedResponseForRequest(NSURLRequest(URL: nsURL))  //note that, per the documentation, if there is no data at the requested URL, no action is taken (i.e. no need to unwrap or check for nils before making this call)
            }
        }
        /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
        imageCache.removeObjectForKey(photoURL)
        --- */
        
        //removes the image from the disk; occurs without error if the file is present (and removed) or if there was no object found at the given path
        do {
            try fileManager.removeItemAtPath(photoURL)
        } catch { }
    }
    
    private init() {}
    
}