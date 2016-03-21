//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/11/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

    struct Constants {
        static let LongPressDuration = 0.5
        static let ShowPhotoAlbumSegue = "ShowPhotoAlbum"
    }
    
    var activeAnnotion = MKPointAnnotation()
    var pointPressed = CGPoint()
    var coordinate = CLLocationCoordinate2D()
    
    //Set up the longpress gesture recognizer when the map view outlet gets set
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            let longPress = UILongPressGestureRecognizer(target: self, action: "dropPin:")
            longPress.minimumPressDuration = Constants.LongPressDuration
            mapView.addGestureRecognizer(longPress)
        }
    }
    
    //method that gets called when the long press gesture recognizer registers a long press; this function places an annotation view as soon as the long press begins, but immediately moves to the .changed state in which the location gets updated with the finger scroll (allowing the pin to move with the finger).
    func dropPin(gesture: UIGestureRecognizer) {
        
        switch gesture.state {
        case .Began:
            let newAnnotation = MKPointAnnotation()
            activeAnnotion = newAnnotation
            updatePinLocatin(gesture)
            newAnnotation.coordinate = coordinate
            newAnnotation.title = "Test"
            mapView.addAnnotation(newAnnotation)
        case .Changed: //need to include .Changed so that the pin will move along with the finger drag
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
            print("moved to \(activeAnnotion.coordinate)")
        case .Ended:
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
            lookUpLocation(activeAnnotion)
        default:
            break
        }
    }
    
    //method that was created to reduce redundant code; the convertPoint doesn't actally convert a location (since the convertPoint is occurring on the same view that it is converting to! however, it is still needed because it performs the role of converting the pointPressed, which is a CGpoint, to a CLLocationCoordinate2D, which is the type required in order to add it to the map view.
    func updatePinLocatin(gesture: UIGestureRecognizer) {
        pointPressed = gesture.locationInView(mapView)
        coordinate = mapView.convertPoint(pointPressed, toCoordinateFromView: mapView)
    }
    
    func lookUpLocation(annotation: MKAnnotation) {  //i put the argument here as MKAnnotation rather than MKPointAnnotation just to keep the function more resusable! it just as easily have been MKPointAnnoation, in which case the downcast that happens in the completion closure below would not have been necessary
        let geocoder = CLGeocoder()
        
        let location = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { (placemarksArray, error) in
            if let error = error {
            //TODO: Add a display alert method and print error to display alert
                print(error.localizedDescription)
            } else if let placemarks = placemarksArray {
                let place = placemarks[0].locality
                if let pointAnnotation = annotation as? MKPointAnnotation {  //note that is necessary to first downcast the annotation as an MKPointAnnotation since the title property would otherwise not be settable
                    dispatch_async(dispatch_get_main_queue()) {
                        pointAnnotation.title = place
                    }
                }
            }
        }
    }
    
    func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.mapView.subviews[0]
        //  Look through gesture recognizers to determine whether this region change is from user interaction
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if (recognizer.state == UIGestureRecognizerState.Began || recognizer.state == UIGestureRecognizerState.Ended) {
                    print("user interaction")
                    return true
                }
            }
        }
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if let savedRegion = NSUserDefaults.standardUserDefaults().objectForKey("savedMapRegion") as? [String: Double] {
            let center = CLLocationCoordinate2D(latitude: savedRegion["mapRegionCenterLat"]!, longitude: savedRegion["mapRegionCenterLon"]!)
            let span = MKCoordinateSpan(latitudeDelta: savedRegion["mapRegionSpanLatDelta"]!, longitudeDelta: savedRegion["mapRegionSpanLonDelta"]!)
            print("loaded: \(center) \(span)")
            mapView.region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

//MAPVIEW DELEGATE METHODS

extension MapViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("location") as? MKPinAnnotationView
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "location")
            annotationView?.canShowCallout = true
            annotationView?.pinTintColor = MKPinAnnotationView.redPinColor()
        } else {
            annotationView?.annotation = annotation
        }
        
        annotationView?.draggable = true
        return annotationView
    }

//TODO: Issue to resolve; first tap on annotation registers the "didSelectAnnotationView" method, but only after the second tap does the grab and hold functionality take place
    
//    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
//        performSegueWithIdentifier(Constants.ShowPhotoAlbumSegue, sender: view)
//    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == .Ending {
            print("grabbed and moved to \(view.annotation?.coordinate)")
        }
    }

//TODO: fix the slight shifting when loading as a result of the two invocations of this delegate method (WHY IS THIS GETTING CALLED MORE THAN ONCE?  see http://stackoverflow.com/questions/33131213/regiondidchange-called-several-times-on-app-load-swift
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        print(mapView.region)
        
        if mapViewRegionDidChangeFromUserInteraction() {
            let regionToSave = [
                "mapRegionCenterLat": mapView.region.center.latitude,
                "mapRegionCenterLon": mapView.region.center.longitude,
                "mapRegionSpanLatDelta": mapView.region.span.latitudeDelta,
                "mapRegionSpanLonDelta": mapView.region.span.longitudeDelta
            ]
            NSUserDefaults.standardUserDefaults().setObject(regionToSave, forKey: "savedMapRegion")
        }
    }
}
