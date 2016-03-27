//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/13/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit

class PhotoAlbumViewController: UIViewController {

    struct Constants {
        static let SpanDeltaLongitude: CLLocationDegrees = 2
        static let CellVerticalSpacing: CGFloat = 4
    }
    
    var SpanDeltaLatitude: CLLocationDegrees {
        let mapViewRatio = mapView.frame.height / mapView.frame.width
        return Constants.SpanDeltaLongitude * Double(mapViewRatio)
    }
    
    var localityName: String?
    var annotationToShow: PinAnnotation!

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
    
    override func viewDidLayoutSubviews() {
        layoutCells()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
    
        print(annotationToShow.photos?.count)
        if let ann = annotationToShow.photos?.first {
            print(ann.photoID)
            print(ann.flickrURL)
            print(ann.storedURL)
        } else {
            print("empty")
        }
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
        
    }
}

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    //MARK: Collection View DataSource Methods
    
    //required
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return 18
        //UDPATE THIS WITH NSFETCH INFO
    }
    
    //required
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        cell.layer.borderWidth = 1
        cell.layer.borderColor = UIColor.blackColor().CGColor
        cell.layer.cornerRadius = 5
        cell.imageView.clipsToBounds = true
        cell.imageView.contentMode = .ScaleAspectFill
        
        //sets the data of each cell using the shared saved memes array; note that the imageview of the cell is being updated to the memed image as retrieved using the "getImage" method on the meme object using the "Memed" ImageType (this method and type are both defined as part of the MemeObject class), as well as the global "getDateFromMeme" function which is defined in the functions.swift file (and also used by the table view)
       // cell.memeImage.image = memeCollection[indexPath.row].getImage(MemeObject.ImageType.Memed)
       // cell.memeLabel.text = "Shared " + getDateFromMeme(memeCollection[indexPath.row])
        
        return cell
        
    }
    
    //MARK: Collection View Delegate Methods
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("MARK FOR DELETE!")
    }
}

extension PhotoAlbumViewController: MKMapViewDelegate {
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let pin = MKPinAnnotationView()
        pin.pinTintColor = UIColor.redColor()
        return pin
    }
}
