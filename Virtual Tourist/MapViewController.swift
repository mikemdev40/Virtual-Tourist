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
        case .Changed, .Ended:  //need to include .Changed so that the pin will move along with the finger drag
            updatePinLocatin(gesture)
            activeAnnotion.coordinate = coordinate
            print("moved to \(activeAnnotion.coordinate)")
        default:
            break
        }
    }
    
    //method that was created to reduce redundant code; the convertPoint doesn't actally convert a location (since the convertPoint is occurring on the same view that it is converting to! however, it is still needed because it performs the role of converting the pointPressed, which is a CGpoint, to a CLLocationCoordinate2D, which is the type required in order to add it to the map view.
    func updatePinLocatin(gesture: UIGestureRecognizer) {
        pointPressed = gesture.locationInView(mapView)
        coordinate = mapView.convertPoint(pointPressed, toCoordinateFromView: mapView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
    }
}

//MAPVIEW DELEGATE METHODS

extension MapViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("location") as? MKPinAnnotationView
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "location")
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
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        print(mapView.region)
    }
}
