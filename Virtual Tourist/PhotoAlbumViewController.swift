//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/13/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {

    //MARK: -------- TYPES --------
    //this type is used to distinguish between two different states of the toolbar and toolbar button that appears depending on if one or more images are selected
    enum ButtonType {
        case NewCollection
        case DeleteImages
    }
    
    //MARK: -------- PROPERTIES --------
    //computed property that returns the delta latitude for the MKCoordinateSpan of the mini-map located above the photo album; the longitude is a constant and the latitude is computed based on that constant as well as the ratio of the mapview's frame's height to width (thus allowing the region to show a zomm level that is constant for any size device)
    var SpanDeltaLatitude: CLLocationDegrees {
        let mapViewRatio = mapView.frame.height / mapView.frame.width
        return Constants.PhotoAlbumConstants.SpanDeltaLongitude * Double(mapViewRatio)
    }
    
    //properties that are set by the segued-from MapViewController; the annotationToShow holds a reference to the PinAnnotation that was selected on the map, and the isStillLoadingText is either set in the prepareForSegue method, or it not, just initialized as nil (the property observer updates the UILabel's text and unhides it if its string gets updated in response to "no images found" -- the optional unwrapping on the noPhotosLabel is required in order to prevent the initial crash that would otherwise occur when the string is set in the prepareForSegue, which leads to an attempt to update the properties of an implicitly unwrapped "noPhotosLabel" outlet that hasn't been set yet and is still nil!)
    var annotationToShow: PinAnnotation!
    var isStillLoadingText: String? {
        didSet {
            noPhotosLabel?.text = isStillLoadingText
            noPhotosLabel?.hidden = false
        }
    }
    
    //properties used for temporarily storing the indexPaths of selected photos that are marked for deletion; as each photo gets tapped and selected/deselected for deletion, its indexpath gets added/removed from this array; the reason for using an intermediate array to store all photos to delete is to allow the user to tap multiple photos without having to tap the delete key each time (which also takes advantage of the fetch controller's performBatchUpdates method); each time an indexpath of an image gets added/removed from this array, the property observer sets the toolbar accordingly (showing the trashcan button when there is at least one image selected, otherwise showing the "Get New Collection" button)
    var selectedIndexPaths = [NSIndexPath]() {
        didSet {
            if selectedIndexPaths.count > 0 {
                setupToolbar(.DeleteImages)
            } else {
                setupToolbar(.NewCollection)
            }
        }
    }
    
    //properties used for temporarily storing the indexPaths of photos that are about to be deleted or inserted from the collection view (they capture the index paths of incoming new photos that are downloaded and saved to core data and need to be displayed in the collection view, and also the index paths of the photos that have been deleted by the user and need to have that reflected in the collection view); these are used and reset exclusively within the NSFetchedResultsControllerDelegate methods)
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    
    //button properties for the toolbar; these are configured in viewDidLoad and arranged in the setupToolBar method
    var removePicturesButton: UIBarButtonItem!
    var getNewCollectionButton: UIBarButtonItem!
    var spacerButton = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
    
    //set the map view's delegate when the outlet gets set (could alternatively had CTRL dragged from the mapview to the yellow view controller icon using the document outline on the storyboard)
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
        }
    }
    
    //set the collection view's delegate and datasource when the outlet gets set (similar to the map view, could alternatively have used the document outline on the storyboard to set these)
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.delegate = self
            collectionView.dataSource = self
        }
    }
    
    //outlet for the text label the shows/hides/updates depending on if photos are downloading, being displayed, or not found
    @IBOutlet weak var noPhotosLabel: UILabel!
    
    //outlet to collection view's flow layout object which enables more refined customization of the collection view and its cells, which is done exclusively in the layoutCells method (and called from within the viewDidLayoutSubviews controller method)
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    //getting a reference to the singleton core data context
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance.managedObjectContect
    }
    
    //lazily initialized NSFetchedResultsController that is responsible for fetching references to specific items in the persistent store via the managed object context, holding them in its fetchedObjects property in an organized section/indexPath way that makes it easy to work with table and collection views, and allowing the controller to easily remove/insert objects in a familiar table/collection view way; this fetch controller is used to grab ALL photos that are associated with a specific PinAnnotation (via use of the search predicate); the initial fetch is performed in viewDidLoad, and the controller and its fetch results are used to organize the collection view's cell count and section layout (see collection view's datasource methods) as well as handling deletions and insertions from the collection view (see the fetched controller's delegate methods)
    lazy var fetchedResultsContoller: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.annotationToShow)
        
        //without at least something in the sortDescriptors (even an empty array), a crash will result (per the documentation: a fetch request "must contain at least one sort descriptor to order the results.")
        fetchRequest.sortDescriptors = []
        
        //we leave sectionNameKeyPath nil because we aren't organizing the photos in section-specifc ways, although this could be a neat additional feature!
        let contoller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        return contoller
    }()
    
    //getting a reference to the singleton client object in order to download images
    let flickrClient = FlickrClient.sharedInstance

    //MARK: -------- CUSTOM METHODS --------
    
    ///this method determines the cell layout (and does do differently depending on whether the device is in portrait or landscape mode) and is called when "viewDidLayoutSubviews" is called (which happens multiple times throughout the view controller's lifecycle, as well as when the device is phycially rotated); note that much of the code in this method has been resued and tweaked from my MemeMe v2.0 project (yay for reusable code!)
    func layoutCells() {
        var cellWidth: CGFloat
        var numWide: CGFloat
        
        //sets the number of cells to display horizontally in each row based on the device's orientation
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            numWide = 3
        case .PortraitUpsideDown:
            numWide = 3
        case .LandscapeLeft:
            numWide = 4
        case .LandscapeRight:
            numWide = 4
        default:
            numWide = 3
        }
        
        //sets the cell width to be dependent upon the number of cells that will be displayed in each row, as determined directly above
        cellWidth = collectionView.frame.width / numWide
        
        //updates the cell width to account for the desired cell spacing (a predetermined constant, defined in the Constants struct), then updates the itemSize accordingly
        cellWidth -= Constants.PhotoAlbumConstants.CellVerticalSpacing
        flowLayout.itemSize.width = cellWidth
        flowLayout.itemSize.height = cellWidth
        flowLayout.minimumInteritemSpacing = Constants.PhotoAlbumConstants.CellVerticalSpacing
        
        //calculates the actual vertical spacing between cells, accounting for the additional vertical space that was subtracted from the cell width (e.g. if there are 3 cells, there are only 2 vertical spaces, not 3); then by setting the line spacing to be equal to this "actual" value, the vertical and horizontal distances between cells should be exact (or as close to exact as possible)
        let actualCellVerticalSpacing: CGFloat = (collectionView.frame.width - (numWide * cellWidth))/(numWide - 1)
        flowLayout.minimumLineSpacing = actualCellVerticalSpacing
        
        //causes the collection view to invalidate its current layout and relay out the collection view using the new settings in the flow layout (without this call, the cells don't properly resize upon rotation)
        flowLayout.invalidateLayout()
    }

    ///method that removes the selected Photo objects from the persistent store (and, through the prepareForDeletioe method on each Photo that gets deleted, the associated image files are deleted from the cache and documents directory)
    func removeImages() {
        
        //iterate through selectedIndexes and for each, get the associated Photo from the fetched results controller, then delete it from the context and save the changes to the persistent store
        for index in selectedIndexPaths {
            
            //the fetchedResultsController monitors and shares updates (via the delegate) that are made to the managed context (not necessarily to the persistent store), so deletions thare are made to the context via sharedContext.deleteObject will still register with the fetchedcontroller and the collection view will still get updated via the fetched controller's delegte properties, but such deletions are not persisted unless saveContext is performed!  (see comment about the NSFetchedResultsControllerDelegate methods below)
            sharedContext.deleteObject(fetchedResultsContoller.objectAtIndexPath(index) as! Photo)
        }
        
        //resets the selected index paths array
        selectedIndexPaths = []
        
        //note that without saving to the managed context, the collection view controller would still get updated via the delete and subsequent batch update (since the fetch controller gets called when the CONTEXT changes, not necessarily the underlying persistent store), however the pictures would still be associationed with the pin and upon opening the app again, the images would re-download (since they have been removed from the disk via the prepareForDelete method on the Photo object class)
        do {
            if sharedContext.hasChanges {
                try sharedContext.save()
            }
        } catch let error as NSError {
            callAlert("Update error", message: error.localizedDescription, alertHandler: nil, presentationCompletionHandler: nil)
        }
    }
    
    ///method that gets invoked when the user taps the "Get New Collection" button on the toolbar and replaces the current collection of images with a new collection of images; this is accomplished by first deleting all photos currently in the collection view, then calling the flickr search method (same one that is used to initially get images) to get a new collection; as a note, the fetched results controller calls the controllerDidChangeContent on its delegate when all deletes are completed, thus enabling a batch update that clears all cells (and allows the "Retrieving Images..." to show) while awaiting the receipt of new image (when it receives a new collection, the controllerDidChangeContent gets invoked again and all insertions are added again in a batch update)
    func getNewCollection() {
        
        //deletes the current collection of photos from core date (and related image files on disk); the fetched results controller calls the controllerDidChangeContent delegate method after all deletions happen, thus calling a batch update which clears all cells and allows the "Retrieving Images..." label to show
        for photo in fetchedResultsContoller.fetchedObjects as! [Photo] {
            sharedContext.deleteObject(photo)
        }
        
        //updating this value calls the didSet property observer which updates the UILabel
        isStillLoadingText = "Retrieving Images..."
        
        flickrClient.executeGeoBasedFlickrSearch(annotationToShow.latitude, longitude: annotationToShow.longitude) {[unowned self] (success, photoArray, error) in
            
            //dispatch to main queue now since all possible avenues for what happens next involve either the UI or core data updates (which occur within the savePhotosToPin method)
            dispatch_async(dispatch_get_main_queue()) {
                guard error == nil else {
                    self.callAlert("Error", message: error!, alertHandler: nil, presentationCompletionHandler: nil)
                    return
                }
                
                guard let photoArray = photoArray else {
                    self.callAlert("Error", message: "No photos in the photo array", alertHandler: nil, presentationCompletionHandler: nil)
                    return
                }
                
                //sends the photo array to be processed and turned into Photo objects that are associated with the activeAnnotation; the max number to store is also sent here (currently 36)
                CoreDataStack.sharedInstance.savePhotosToPin(photoArray, pinToSaveTo: self.annotationToShow, maxNumberToSave: Constants.MapViewConstants.MaxNumberOfPhotosToSavePerPin)
                
                //updates the message in case there are no results found
                if photoArray.count == 0 {
                    self.isStillLoadingText = "No Images Found at this Location."
                }
            }
        }
    }
    
    ///method that sets up the toolbar to show the appropriate button at the appropriate time; the color of the toolbar is also updated for a given state: light red for delete mode, and default gray color (i.e. barTintColor = nil) when in "get new collection" mode; this method is called once initially in viewDidLoad to show the initial .NewCollection state, but then is called exclusively in response to the user selecting/deselecting photos within the selectedIndexPaths property observers (i.e. if at least one image is selected, then show the .DeleteImages state, otherwise show the .NewCollection state)
    func setupToolbar(buttonToShow: ButtonType) {
        switch buttonToShow {
        case .NewCollection:
            setToolbarItems([spacerButton, getNewCollectionButton, spacerButton], animated: false)
            navigationController?.toolbar.barTintColor = nil
        case .DeleteImages:
            setToolbarItems([spacerButton, removePicturesButton, spacerButton], animated: false)
            navigationController?.toolbar.barTintColor = UIColor(red: 255/255, green: 168/255, blue: 168/255, alpha: 1)
        }
    }
    
    ///method that displays an alert (i have reused this method across various projects!); it takes optional completion handlers for when the button is tapped and also when the display is presented (which in this project are both always nil; i have kept them in simply because it keeps this function generic and reusable, and copyable/pastable from project to project)
    func callAlert(title: String, message: String, alertHandler: ((UIAlertAction) -> Void)?, presentationCompletionHandler: (() -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: alertHandler))
        presentViewController(alertController, animated: true, completion: presentationCompletionHandler)
    }
    
    //MARK: -------- VIEW CONTROLLER METHODS --------
    
    //this method is called multiple times throughout the initial setup of the colleciton view, as well as in response to the device rotating to a different orientation
    override func viewDidLayoutSubviews() {
        layoutCells()
    }
    
    //MARK: -------- VIEW CONTROLLER LIFECYCLE --------
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        //initially hides the UILabel, but if the isStillLoadingText property was set to a value (i.e. non-nil) during the prepareForSegue from the MapViewController, then unhide the label and show the passed string value
        noPhotosLabel.hidden = true
        if isStillLoadingText != nil {
            noPhotosLabel.text = isStillLoadingText
        }
        
        //set up the two custom buttons for the toolbar
        removePicturesButton = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: #selector(PhotoAlbumViewController.removeImages))
        getNewCollectionButton = UIBarButtonItem(title: "Get New Collection", style: .Plain, target: self, action: #selector(PhotoAlbumViewController.getNewCollection))

        //initially show the .NewCollection state of the toolbar (which presents the getNewCollectionButton)
        setupToolbar(.NewCollection)
        
        //set the delegate of the fetched results controller and perform the initial fetch that will be used to set up the collection view's initial state; if the fetch returns no results (i.e. the first set of images is still being loade from the previous view controller), then the collection view should set its initial number of sections and number of items in section to a default value (see collection view datasource methods); this is the only time a performFetch occurs, since all other updates from this point forward are monitored and reported via the fetch controller's delegate methods
        fetchedResultsContoller.delegate = self
        do {
            try fetchedResultsContoller.performFetch()
        } catch {}
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        //toolbarHidden was used rather than .setToolbarHidden with animation, since the animation up and back (on view close) caused the collection view to shift in an unecessarily distracting way)
        navigationController?.toolbarHidden = false
        
        //update the map view to show the region around the selected pin, and add that annotation to the map; the use of a constant and computed value for the MKCoordinate span supports a consistent latitude/longitude span ratio from device to device
        mapView.region = MKCoordinateRegion(center: annotationToShow.coordinate, span: MKCoordinateSpan(latitudeDelta: SpanDeltaLatitude, longitudeDelta: Constants.PhotoAlbumConstants.SpanDeltaLongitude))
        mapView.addAnnotation(annotationToShow)
        
         //if there is a title currently associated with the PinAnnotation (i.e. the locality ["city"], if any, was returned from the MapViewController's lookupLocation method and saved as the pin's title property), then display the city's name in the navigtion bar; otherwise, show a generic "Photos" label (if this is the first time the user is accessing the pin, it is possible that the title is still being retrieved, and if a locality is ultimately found and returned, it will be saved and the next time the user accesses the pin, the city will show)
        if let localityName = annotationToShow.title {
            title = localityName
        } else {
            title = "Photos"
        }

        /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
        subscribeToNotifications()
        --- */
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        //hide the toolbar before exiting back to the map view
        navigationController?.toolbarHidden = true
        
        /* --- line below UNUSED (i want to retain this line as a comment for personal future review)
         unsubscribeFromNotifications()
         --- */
    }
    
    /* --- lines below UNUSED in final project (i want to retain them as a comment for personal future review)
    func subscribeToNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(notify), name: NSManagedObjectContextObjectsDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(notify), name: NSManagedObjectContextDidSaveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(notify), name: NSManagedObjectContextWillSaveNotification, object: nil)
    }
    
    func unsubscribeFromNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextObjectsDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextDidSaveNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextWillSaveNotification, object: nil)
    }
    
    func notify(notification: NSNotification) {
        print(notification.name)
    }
    --- */
}

//MARK: -------- COLLECTION VIEW DATASOURCE & DELEGATE METHODS --------

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    //-------- Collection View DataSource Methods
    
    //required datasource method
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        //unwraps the section info returned by the fetched results controller and checks to see how many objects have been returned for the given section; note, for this app, there will always be exactly 1 section returned (even a pin without any photos has 1 section with 0 items - determined via testing)
        if let section = fetchedResultsContoller.sections?[section] {
            
            //ensures that the UILabel is displayed to the user (it may already be unhidden if the images are retrieving)
            if section.numberOfObjects == 0 {
                noPhotosLabel.hidden = false
            }
            
            //tell the collection view to set up numberOfObjects cells
            return section.numberOfObjects
        } else {
            
            //this should never be called becuse the unwrapping of section above should always be successful; however, just in case!
            return 1
        }
    }
    
    //required datasource method
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        //sets the image to nil, which is needed to prevent a reused cell from having a cell already present in it when it is used to show a new image (most important for getting a new collection)
        cell.imageView.image = nil
        
        //sets the background of the cell to red (which will only show thru then the cell is selected and alpha is adjusted to a value other than 1); could alternatively have set this to light gray and then toggle the background color between light gray and red within the didSelectItemAtIndexPath method)
        cell.backgroundColor = UIColor.redColor()
        
        //sets the background of the imageView to light gray, which will show when the imageView.image property is nil (i.e. the photo is in the process of being downloaded), along with a spinning spinner (and since the imageView's background color appears in front of the cell's background color, the red color will not be revealed)
        cell.imageView.backgroundColor = UIColor.lightGrayColor()
        
        //set up the border of the cell
        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor.blackColor().CGColor
        cell.layer.cornerRadius = 5
        
        //set up the image view of the cell to ensure it fills the cell (without going out of bounds) and has proper ration
        cell.imageView.clipsToBounds = true
        cell.imageView.contentMode = .ScaleAspectFill
        
        //the if-else block of code below checks to see if the indexPath of the cell that is being configured corresponds to a cell that is currently selected for delete; this is required to prevent the red selected color from "bouncing around" to a different cell when the user selects a cell, scrolls it off the screen, then scrolls it back
        if let _ = selectedIndexPaths.indexOf(indexPath) {
            
            //if the cell is currently selected, then make sure it still shows red when a cell is pulled from the queue and reused (i.e. when a user scrolls the image off the view then back again); note that this doens't alter the array of selected indices anyway, just manages proper coloring of the cell when necessary
            cell.imageView.alpha = Constants.PhotoAlbumConstants.CellAlphaWhenSelectedForDelete
        } else {
            
            //otherwise, make sure it doesn't show red!
            cell.imageView.alpha = 1.0
        }
        
        //pull out the corresponding Photo item from the fetched results controller at the specified indexPath
        let photoObjectToDisplay = fetchedResultsContoller.objectAtIndexPath(indexPath) as! Photo
       
        //if there is currently an image assocated with the returned Photo object (i.e. it has finished downloading), retrieve the saved image (pulling first from the cache, if the cached image is still available, and if not, pulling from the persistent store), and display the image in the cell...
        if let photoImage = photoObjectToDisplay.photoImage {
            cell.imageView.image = photoImage
        
        //...otherwise, activate the spinner and execute the getImageForUrl method to download the specific image from flickr stored at the Photo's flickr URL (which is determined and saved as part of the initial flickr search)
        } else {
            cell.spinner.startAnimating()
            
            //since this method occurs asynchronously, then photos will be returned at various times, and cells will be updated in real time as the image data for each cell gets returned
            FlickrClient.sharedInstance.getImageForUrl(photoObjectToDisplay.flickrURL, completionHandler: { (data, error) in
                guard error == nil else {
                    return
                }
                
                //since the URL being accessed contains an image file (a "medium" version of the flickr image, as dictated by the "url_m" parameter), then we know that the NSData being returned should be able to made into a UIImage
                if let photoData = data {
                    
                    //if the conversion of the NSData successfully returns a UIImage, then dispatch to main queue, update the cell's image with the downloaded image, save the image to the Photo object in core data, and stop the spinner (which hides it)
                    if let photo = UIImage(data: photoData) {
                        dispatch_async(dispatch_get_main_queue()) {
                            cell.imageView.image = photo
                            
                            //note that when we set the photoImage property on a Photo object, there are no changes to the core data model (and no need to save the context) since everything related to the image file itself involves the cache and documents directory on the file system but not the persistent store (one of the project's requirements was to store the file external to the core data persistent store, and as such, the UIImage photoImage property is not an NSManaged property and does not lead to context changes, nor does the URL to the file on the disk because it is a computed property)
                            photoObjectToDisplay.photoImage = photo
                            cell.spinner.stopAnimating()
                        }
                    }
                }
            })
        }
        return cell
    }
    
    //optional datasource method, which if not implemented, returns 1 be default
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        
        //returns the number of sections in the fetched results, which for this app should always be exactly 1 (even a pin without any photos has 1 section with 0 items, which was determined via testing); the use of the nil coalescing operator is for safety
        return fetchedResultsContoller.sections?.count ?? 1
    }
    
    //-------- Collection View Delegate Methods
    
    //optional delegate method that determines the response to a cell being selected; this methos adds/removes the selected cell from the selectedIndexPaths array and updates its selected state (via its alpha)
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        //cast the selected cell as a PhotoCollectionViewCell so that we can get ahold of its imageView property
        let selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        
        //if the image tapped was already selected (i.e. the indexPath is already in the selectedIndexPaths), then it was being tapped to deselect it, so update its state to "not selected" by setting its alpha to 1.0 (which prevents the red background from showing through)...
        if let index = selectedIndexPaths.indexOf(indexPath) {
            selectedCell.imageView.alpha = 1.0
            selectedIndexPaths.removeAtIndex(index)
        
        //...otherwise, it is being tapped to select it for deletion, so show it as selected by reducing its alpha (constant initially set to 0.35) this allowing the red cell background to show through, and then adding its indexpath to the array of selectedIndexPaths
        } else {
            selectedCell.imageView.alpha = Constants.PhotoAlbumConstants.CellAlphaWhenSelectedForDelete
            selectedIndexPaths.append(indexPath)
        }
    }
}

//MARK: -------- FETCHEDCONTROLLER DELEGATE METHODS --------

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    //just before any images are added (via the "get new collection" button) or deleted from the context, this method is invoked which resets the temporary arrays that store the indexPaths at which to insert or delete cells
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        noPhotosLabel.hidden = true
    }
    
    //depending on which type of change is being registered with the context, either add the indexPath to the insertedIndexPaths array or to the deletedIndexPaths array; the purpose of this is to store all the objects that should be inserted or deleted in one place, without actually deleting or adding them one by one to the collection view, so that the performBatchUpdates on the collection view can be invoked ONCE after all insertions/deletions have been made to the context (although it would have been possible to simply insert or remove each cell one by one, it would have been messy and inefficient, and given the potential volume of insertions or deletions that could take place, using the batch update method is the best choice here)
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
        case .Delete:
            deletedIndexPaths.append(indexPath!)
        
        //case not used, but included for completeness
        case .Update:
            break
        default:
            break
        }
    }
    
    //through testing with the NSManagedObjectContext notifcations, it seems that the invocation of the controllerDidChangeContent method on the fetch controller's delegate is related to the NSManagedObjectContextObjectsDidChangeNotification being posted by the context, which occurs after all deletions are finished (either as part of the removeImages or getNewCollection methods) AND after any new images are retrieved and saved (as part of the getNewCollection method); the deletions that occur within getNewCollection invoke this method once after all are completed - despite there being no explicit save of the context in between the photos being deleted and the new images being retrieved; within the removeImages, this method is SEEMS to invoked BEFORE the save actually occurs, although it is hard to know for sure; interestingly, if the context.save() method is performend after EACH individual deletion, i.e. within the iteration loop, then this delegate method gets invoked in EACH iteration through the loop; similary for the new images, this method gets invoked ONCE after ALL images have been added (but seemingly before the actual save happens, although again it's hard to tell), but if the save() occurs within the save iteration loop (which occurs within the CoreDataStack.savePhotosToPin method), then this method is being invoked with each interation of the loop.  despite it being still unclear EXACTLY what causes the invocation of this method, one thing is clear:  we want to ensure that this method ONLY gets invoked at the right time (thus enabling the efficient batch update), and to ensure this happens, we should only save the context ONCE after ALL deletions and/or insertions to the context have been made (i.e. don't save the context after EACH deletion or insertion) - which makes sense anyways!!!
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        //the performBatchUpdates is invoked on the collection view itself in response to the fetched results controller telling its delegate (the collection view controller) that all new additions/deletions have been added to the context (and saved to core data, although that isn't necessary to invoke this method), and that its time to update the collection view to reflect these changes all at once, rather than one by one
        collectionView.performBatchUpdates({ [unowned self] in
                for indexPath in self.insertedIndexPaths {
                    self.collectionView.insertItemsAtIndexPaths([indexPath])
                }
                for indexPath in self.deletedIndexPaths {
                    self.collectionView.deleteItemsAtIndexPaths([indexPath])
                }
            }, completion: nil)
    }
}

//MARK: -------- MAPVIEW DELEGATE METHODS --------

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    //there is no purpose or interactivity with the small map at the top other than to display the pin that was selected by the user; hence, this delegate method is the only map-based method being implemented in this view controller
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let pin = MKPinAnnotationView()
        pin.pinTintColor = UIColor.redColor()
        return pin
    }
}