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
    
    @IBOutlet weak var mapView: MKMapView! {
        didSet {
            mapView.delegate = self
            let longPress = UILongPressGestureRecognizer(target: self, action: "dropPin:")
            longPress.minimumPressDuration = Constants.LongPressDuration
            mapView.addGestureRecognizer(longPress)
        }
    }
    
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
            print("moved to  \(activeAnnotion.coordinate)")
        default:
            break
        }
    }
    
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
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        performSegueWithIdentifier(Constants.ShowPhotoAlbumSegue, sender: view)
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == .Ending {
            print("dropped at  \(view.annotation?.coordinate)")
        }
    }
}
