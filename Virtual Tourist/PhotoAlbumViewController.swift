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

    struct Constants {
        static let SpanDeltaLongitude: CLLocationDegrees = 2
        static let CellVerticalSpacing: CGFloat = 4
        static let CellAlphaWhenSelectedForDelete: CGFloat = 0.35
    }
    
    enum ButtonType {
        case NewCollection
        case DeleteImages
    }
    
    var SpanDeltaLatitude: CLLocationDegrees {
        let mapViewRatio = mapView.frame.height / mapView.frame.width
        return Constants.SpanDeltaLongitude * Double(mapViewRatio)
    }
    
    var localityName: String?
    var annotationToShow: PinAnnotation!

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
    
    var removePicturesButton: UIBarButtonItem!
    var getNewCollectionButton: UIBarButtonItem!
    var spacerButton = UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil)
    
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
    
    //connecting to the collection view's flow layout object enables its customization
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
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
            numWide = 4
        }
        
        //sets the cell width to be dependent upon the number of cells that will be displayed in each row, as determined directly above
        cellWidth = collectionView.frame.width / numWide
        
        //updates the cell width to account for the desired cell spacing (a predetermined constant, defined in the Constants struct), then updates the itemSize accordingly
        cellWidth -= Constants.CellVerticalSpacing
        flowLayout.itemSize.width = cellWidth
        flowLayout.itemSize.height = cellWidth
        flowLayout.minimumInteritemSpacing = Constants.CellVerticalSpacing
        
        //calculates the actual vertical spacing between cells, accounting for the additional vertical space that was subtracted from the cell width (e.g. if there are 3 cells, there are only 2 vertical spaces, not 3); then by setting the line spacing to be equal to this "actual" value, the vertical and horizontal distances between cells should be exact (or as close to exact as possible)
        let actualCellVerticalSpacing: CGFloat = (collectionView.frame.width - (numWide * cellWidth))/(numWide - 1)
        flowLayout.minimumLineSpacing = actualCellVerticalSpacing
        
        //causes the collection view to invalidate its current layout and relay out the collection view using the new settings in the flow layout (without this call, the cells don't properly resize upon rotation)
        flowLayout.invalidateLayout()
    }

    func removeImages() {
        
    }
    
    func setupToolbar(buttonToShow: ButtonType) {
        switch buttonToShow {
        case .NewCollection:
            setToolbarItems([spacerButton, getNewCollectionButton, spacerButton], animated: true)
        case .DeleteImages:
            setToolbarItems([spacerButton, removePicturesButton, spacerButton], animated: true)
        }
    }
    
    func getNewCollection() {
        
    }
    
    func callAlert(title: String, message: String, alertHandler: ((UIAlertAction) -> Void)?, presentationCompletionHandler: (() -> Void)?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: alertHandler))
        presentViewController(alertController, animated: true, completion: presentationCompletionHandler)
    }
    
    //MARK: VIEW CONTROLLER METHODS
    
    override func viewDidLayoutSubviews() {
        layoutCells()
    }
    
    //MARK: VIEW CONTROLLER LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        removePicturesButton = UIBarButtonItem(barButtonSystemItem: .Trash, target: self, action: #selector(PhotoAlbumViewController.removeImages))
        getNewCollectionButton = UIBarButtonItem(title: "Get New Collection", style: .Plain, target: self, action: #selector(PhotoAlbumViewController.getNewCollection))

        // DELETE FUNCTIONALITY!!!  dont forget to delete the image files! and delete object from core data using sharedContext.deleteObject
        setupToolbar(.NewCollection)
        
        fetchedResultsContoller.delegate = self
        
        do {
            try fetchedResultsContoller.performFetch()
        } catch {}
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        mapView.region = MKCoordinateRegion(center: annotationToShow.coordinate, span: MKCoordinateSpan(latitudeDelta: SpanDeltaLatitude, longitudeDelta: Constants.SpanDeltaLongitude))
        mapView.addAnnotation(annotationToShow)
        
        if localityName != nil {
            title = localityName
        } else {
            title = "Photos"
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
    }
}

//MARK: COLLECTION VIEW DELEGATE & DATASOURCE METHODS

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    //Collection View DataSource Methods
    
    //required
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let section = fetchedResultsContoller.sections?[section] {
            print("objects: \(section.numberOfObjects)")
            return section.numberOfObjects
        } else {
            return 0
        }
    }
    
    //required
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
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
            cell.spinner.stopAnimating()
        } else {
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
        let selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        
        
        if let index = selectedIndexPaths.indexOf(indexPath) {
            selectedCell.imageView.alpha = 1.0
            selectedIndexPaths.removeAtIndex(index)
        } else {
            selectedCell.backgroundColor = UIColor.redColor()
            selectedCell.imageView.alpha = Constants.CellAlphaWhenSelectedForDelete
            selectedIndexPaths.append(indexPath)
        }
    }
}

//MARK: FETCHEDCONTROLLER DELEGATE METHODS

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
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

//MARK: MAPVIEW DELEGATE METHODS

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let pin = MKPinAnnotationView()
        pin.pinTintColor = UIColor.redColor()
        return pin
    }
}
