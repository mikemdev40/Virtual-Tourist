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
    enum ButtonType {
        case NewCollection
        case DeleteImages
    }
    
    //MARK: -------- PROPERTIES --------
    var SpanDeltaLatitude: CLLocationDegrees {
        let mapViewRatio = mapView.frame.height / mapView.frame.width
        return Constants.PhotoAlbumConstants.SpanDeltaLongitude * Double(mapViewRatio)
    }
    
    //properties that are set by the segued-from view controller
    var localityName: String?
    var annotationToShow: PinAnnotation!
    var isStillLoadingText: String? {
        didSet {
            noPhotosLabel?.text = isStillLoadingText
            noPhotosLabel?.hidden = false
        }
    }
    
    //properties used for temporarily storing the indexPaths of selected, inserted, and deleted photos
    var selectedIndexPaths = [NSIndexPath]() {
        didSet {
            if selectedIndexPaths.count > 0 {
                setupToolbar(.DeleteImages)
            } else {
                setupToolbar(.NewCollection)
            }
        }
    }
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    
    //button properties for the toolbar
    var removePicturesButton: UIBarButtonItem!
    var getNewCollectionButton: UIBarButtonItem!
    var spacerButton = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
    
    //outlets
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.delegate = self
            collectionView.dataSource = self
        }
    }
    
    @IBOutlet weak var noPhotosLabel: UILabel!
    
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout! //connecting to the collection view's flow layout object enables its customization
    
    //properties for working with core data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStack.sharedInstance.managedObjectContect
    }
    
    lazy var fetchedResultsContoller: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.annotationToShow)
        fetchRequest.sortDescriptors = []  //without at least something in the sortDescriptors, a crash will result (per the documentation: a fetch request "must contain at least one sort descriptor to order the results."
        
        let contoller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        return contoller
    }()
    
    //property for working with the flickr clent to download images
    let flickrClient = FlickrClient.sharedInstance

    
    //MARK: -------- CUSTOM METHODS --------
    
    ///this method determines the cell layout (and does do differently depending on whether the device is in portrait or landscape mode) and is called when "viewDidLayoutSubviews" is called (which happens multiple times throughout the view controller's lifecycle, as well as when the device is phycially rotated)
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

    //the fetchedResultsController monitors and shares updates (via the delegate) that are made to the managed context (not necessarily to the persistent store), so deletions thare are made to the context via sharedContext.deleteObject will still register with the fetchedcontroller and the collection view will still get updated via the fetched controller's delegte properties, but such deletions are not persisted unless saveContext is performed!
    func removeImages() {
        //iterate through selectedIndexes and for each, delete it from core data; SAVE context
        
        for index in selectedIndexPaths {
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
    
    func getNewCollection() {
        
        //delete current collection
        for photo in fetchedResultsContoller.fetchedObjects as! [Photo] {
            sharedContext.deleteObject(photo)
        }
        
        isStillLoadingText = "Retrieving Images..."
        
        flickrClient.executeGeoBasedFlickrSearch(annotationToShow.latitude, longitude: annotationToShow.longitude) {[unowned self] (success, photoArray, error) in
            guard error == nil else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.callAlert("Error", message: error!, alertHandler: nil, presentationCompletionHandler: nil)
                }
                return
            }
            
            guard let photoArray = photoArray else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.callAlert("Error", message: "No photos in the photo array", alertHandler: nil, presentationCompletionHandler: nil)
                }
                return
            }
            
            CoreDataStack.sharedInstance.savePhotosToPin(photoArray, pinToSaveTo: self.annotationToShow, maxNumberToSave: Constants.MapViewConstants.MaxNumberOfPhotosToSavePerPin)
            dispatch_async(dispatch_get_main_queue()) {
                do {
                    try self.sharedContext.save()
                    print("SUCCESSFUL RE-SAVE")
                } catch let error as NSError {
                    self.callAlert("Error", message: error.localizedDescription, alertHandler: nil, presentationCompletionHandler: nil)
                }
                if photoArray.count == 0 {
                    self.isStillLoadingText = "No Images Found at this Location."
                }
            }
        }
    }
    
    func setupToolbar(buttonToShow: ButtonType) {
        switch buttonToShow {
        case .NewCollection:
            setToolbarItems([spacerButton, getNewCollectionButton, spacerButton], animated: true)
        case .DeleteImages:
            setToolbarItems([spacerButton, removePicturesButton, spacerButton], animated: true)
        }
    }
    
    func callAlert(title: String, message: String, alertHandler: ((UIAlertAction) -> Void)?, presentationCompletionHandler: (() -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: alertHandler))
        presentViewController(alertController, animated: true, completion: presentationCompletionHandler)
    }
    
    //MARK: -------- VIEW CONTROLLER METHODS --------
    
    override func viewDidLayoutSubviews() {
        layoutCells()
    }
    
    //MARK: -------- VIEW CONTROLLER LIFECYCLE --------
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        noPhotosLabel.hidden = true
        if isStillLoadingText != nil {
            noPhotosLabel.text = isStillLoadingText
        }
        
        removePicturesButton = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: #selector(PhotoAlbumViewController.removeImages))
        getNewCollectionButton = UIBarButtonItem(title: "Get New Collection", style: .Plain, target: self, action: #selector(PhotoAlbumViewController.getNewCollection))

        setupToolbar(.NewCollection)
        
        fetchedResultsContoller.delegate = self
        
        do {
            try fetchedResultsContoller.performFetch()
        } catch {}
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.toolbarHidden = false
            
        mapView.region = MKCoordinateRegion(center: annotationToShow.coordinate, span: MKCoordinateSpan(latitudeDelta: SpanDeltaLatitude, longitudeDelta: Constants.PhotoAlbumConstants.SpanDeltaLongitude))
        mapView.addAnnotation(annotationToShow)
        
        if localityName != nil {
            title = localityName
        } else {
            title = "Photos"
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.toolbarHidden = true
    }
}

//MARK: -------- COLLECTION VIEW DELEGATE & DATASOURCE METHODS --------

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    //Collection View DataSource Methods
    
    //required
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let section = fetchedResultsContoller.sections?[section] {
            if section.numberOfObjects == 0 {
                noPhotosLabel.hidden = false
            }
            return section.numberOfObjects
        } else {
            return 0
        }
    }
    
    //required
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        //this code checks to see if the indexPath of the cell that is being configured corresponds to a cell that is currently selected for delete; this is required to prevent the red selected color from "bouncing around" to a different cell when the user selects a cell, scrolls it off the screen, then scrolls it back
        if let _ = selectedIndexPaths.indexOf(indexPath) {
            cell.imageView.alpha = Constants.PhotoAlbumConstants.CellAlphaWhenSelectedForDelete //if the cell is currently selected, then make sure it still shows red when a cell is pulled from the queue and reused (i.e. when a user scrolls the image off the view then back again); note that this doens't alter the array of selected indices anyway, just manages proper coloring of the cell when necessary
        } else {
            cell.backgroundColor = UIColor.redColor()  //otherwise, make sure it doesn't show red!
            cell.imageView.alpha = 1.0
        }
        
        cell.imageView.image = nil
        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor.blackColor().CGColor
        cell.layer.cornerRadius = 5
        cell.imageView.backgroundColor = UIColor.lightGrayColor()
        cell.imageView.clipsToBounds = true
        cell.imageView.contentMode = .ScaleAspectFill
        
        let photoObjectToDisplay = fetchedResultsContoller.objectAtIndexPath(indexPath) as! Photo
       
        if let photoImage = photoObjectToDisplay.photoImage {
            cell.imageView.image = photoImage
            print("photo loaded")
        } else {
            cell.spinner.startAnimating()
            FlickrClient.sharedInstance.getImageForUrl(photoObjectToDisplay.flickrURL, completionHandler: { (data, error) in
                guard error == nil else {
                    return
                }
                
                if let photoData = data {
                    let photo = UIImage(data: photoData)
                    dispatch_async(dispatch_get_main_queue()) {
                        print("photo DOWNLOADED")
                        cell.imageView.image = photo
                        photoObjectToDisplay.photoImage = photo
                        cell.spinner.stopAnimating()
                    }
                }
            })
        }
        return cell
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return fetchedResultsContoller.sections?.count ?? 1
    }
    
    //Collection View Delegate Methods
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        print("did select item")
        let selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        
        if let index = selectedIndexPaths.indexOf(indexPath) {
            selectedCell.imageView.alpha = 1.0
            selectedIndexPaths.removeAtIndex(index)
        } else {
            selectedCell.backgroundColor = UIColor.redColor()
            selectedCell.imageView.alpha = Constants.PhotoAlbumConstants.CellAlphaWhenSelectedForDelete
            selectedIndexPaths.append(indexPath)
        }
    }
}

//MARK: -------- FETCHEDCONTROLLER DELEGATE METHODS --------

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        noPhotosLabel.hidden = true
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            
        case .Insert:
            print("insert")
            insertedIndexPaths.append(newIndexPath!)
        case .Delete:
            print("delete")
            deletedIndexPaths.append(indexPath!)
        case .Update:
            print("update")
        default:
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({ [unowned self] in
                for indexPath in self.insertedIndexPaths {
                    self.collectionView.insertItemsAtIndexPaths([indexPath])
                }
                for indexPath in self.deletedIndexPaths {
                    self.collectionView.deleteItemsAtIndexPaths([indexPath])
                }
            }) { (bool) in
                print("COMPLETE")
        }
    }
    
}

//MARK: -------- MAPVIEW DELEGATE METHODS --------

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let pin = MKPinAnnotationView()
        pin.pinTintColor = UIColor.redColor()
        return pin
    }
}
