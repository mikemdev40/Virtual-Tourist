//
//  PhotoCollectionViewCell.swift
//  Virtual Tourist
//
//  Created by Michael Miller on 3/25/16.
//  Copyright © 2016 MikeMiller. All rights reserved.
//

import UIKit

//custom class for use in the collection view's cells; the design of this cell is laid out in the storyboard
class PhotoCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView! {
        didSet {
            //this property observer sets the hidesWhenStopped property to true when the outlet is created (this could alternatively have been set using the storyboard checkbox for the activity spinner)
            spinner.hidesWhenStopped = true
        }
    }
}
