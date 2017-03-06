//
//  QuadTree.swift
//  MapClustering
//
//  Created by Shóna Nunez on 27/11/2015.
//  Copyright © 2015-2017. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

class QuadTree: NSObject
{
    //MARK: - Variable Declarations
    
    //Max number of objects stored by the quadrant
    let nodeCapacity = 25
    
    //The objects contained in the quadrant
    var objects: [MapMarker] = []
    
    //Child QuadTrees
    var northWest: QuadTree? = nil
    var northEast: QuadTree? = nil
    var southWest: QuadTree? = nil
    var southEast: QuadTree? = nil
    
    //The boundary of the tree
    var boundingBox: BoundingBox? = nil
    
    //Min/Max Latitude and Longitude
    var minLatitude: Double = 0.0
    var maxLatitude: Double = 0.0
    var minLongitude: Double = 0.0
    var maxLongitude: Double = 0.0
    
    //MARK: - Class Functions
    /**
     Initializer for the QuadTree class
     :param: box Boundary frame for the QuadTree
     :returns: QuadTree class
     */
    
    override init() {
        super.init()
    }
    
    init(boundingBox box: BoundingBox) {
        self.boundingBox = box
        self.objects = [MapMarker]()
    }
    
    /**
     Inserts a marker into the quad tree, dividing the tree if necessary
     :param: object Any object
     :param: atPoint location of the object
     :returns: true if object was added, false if not
     */
    
    @discardableResult func insertObject(_ object: MapMarker, atPoint point: CLLocationCoordinate2D, checkMinMax: Bool) -> Bool
    {
        if checkMinMax == true {
            if object.markerCoordinate.latitude > maxLatitude {
                maxLatitude = object.markerCoordinate.latitude
            }
            else if object.markerCoordinate.latitude < minLatitude {
                minLatitude = object.markerCoordinate.latitude
            }
            
            if object.markerCoordinate.longitude > maxLongitude {
                maxLongitude = object.markerCoordinate.longitude
            }
            else if object.markerCoordinate.longitude < minLongitude {
                minLongitude = object.markerCoordinate.longitude
            }
        }
        
        //Check to see if the region contains the marker
        if containsCoordinate(boundingBox!, checkCoordinate: point) == false {
            return false
        }
        
        //If there is enough space add the marker
        if objects.count < nodeCapacity {
            objects.append(object)
            return true
        }
        
        //Otherwise, subdivide and add the marker to whichever child will accept it
        if northWest == nil {
            subdivide()
        }
        
        if northWest != nil && northWest!.insertObject(object, atPoint: point, checkMinMax: checkMinMax) {
            return true
        }
        else if northEast != nil && northEast!.insertObject(object, atPoint: point, checkMinMax: checkMinMax) {
            return true
        }
        else if southWest != nil && southWest!.insertObject(object, atPoint: point, checkMinMax: checkMinMax) {
            return true
        }
        else if southEast != nil && southEast!.insertObject(object, atPoint: point, checkMinMax: checkMinMax) {
            return true
        }
        
        //If all else fails...
        return false
    }
    
    /**
     Querys all objects within a region of the QuadTree
     
     :param: box The visible area to search
     :param: region The region (within the box) of interest
     :returns: Array of objects that lie within the region of interest
     */
    
    func queryRegion(_ box: BoundingBox, region: BoundingBox) -> [MapMarker]
    {
        var objectsInRegion = [MapMarker]()
        
        if !(intersectsBoxBounds(box, box2: region)) {
            return objectsInRegion
        }
        
        for object in objects {
            if containsCoordinate(region, checkCoordinate:object.markerCoordinate) {
                objectsInRegion.append(object)
            }
        }
        
        //If there are no children stop here
        if northWest == nil {
            return objectsInRegion
        }
        
        //Otherwise add the points from the children
        if northWest != nil {
            objectsInRegion += northWest!.queryRegion(box, region: region)
        }
        if northEast != nil {
            objectsInRegion += northEast!.queryRegion(box, region: region)
        }
        if southWest != nil {
            objectsInRegion += southWest!.queryRegion(box, region: region)
        }
        if southEast != nil {
            objectsInRegion += southEast!.queryRegion(box, region: region)
        }
        
        return objectsInRegion
    }
    
    func boundingBoxForCoordinates(_ northEastCoord: CLLocationCoordinate2D, southWestCoord: CLLocationCoordinate2D) -> BoundingBox
    {
        let minLat: CLLocationDegrees = southWestCoord.latitude
        let maxLat: CLLocationDegrees = northEastCoord.latitude
        
        let minLong: CLLocationDegrees = southWestCoord.longitude
        let maxLong: CLLocationDegrees = northEastCoord.longitude
        
        return boundingBoxMake(CGFloat(minLong), y0: CGFloat(minLat), xf: CGFloat(maxLong), yf: CGFloat(maxLat))
    }
    
    //MARK: - Private Functions
    private func subdivide() //Will subdivide a QuadTree into 4 smaller QuadTrees
    {
        northEast = QuadTree()
        northWest = QuadTree()
        southEast = QuadTree()
        southWest = QuadTree()
        
        let box = boundingBox!
        
        let midX: CGFloat = (box.xf + box.x0) / 2.0
        let midY: CGFloat = (box.yf + box.y0) / 2.0
        
        northWest!.boundingBox = boundingBoxMake(box.x0, y0: midY, xf: midX, yf: box.yf)
        northEast!.boundingBox = boundingBoxMake(midX, y0: midY, xf: box.xf, yf: box.yf)
        southWest!.boundingBox = boundingBoxMake(box.x0, y0: box.y0, xf: midX, yf: midY)
        southEast!.boundingBox = boundingBoxMake(midX, y0: box.y0, xf: box.xf, yf: midY)
    }
    
    private func boundingBoxMake(_ x0: CGFloat, y0: CGFloat, xf: CGFloat, yf: CGFloat) -> BoundingBox
    {
        let box = BoundingBox(x0: x0, y0: y0, xf: xf, yf: yf)
        return box;
    }
    
    private func containsCoordinate(_ box: BoundingBox, checkCoordinate: CLLocationCoordinate2D) -> Bool
    {
        let containsX: Bool = (box.x0 <= CGFloat(checkCoordinate.longitude)) && (CGFloat(checkCoordinate.longitude) <= box.xf)
        let containsY: Bool = (box.y0 <= CGFloat(checkCoordinate.latitude)) && (CGFloat(checkCoordinate.latitude) <= box.yf)
        return (containsX && containsY)
    }
    
    private func intersectsBoxBounds(_ box1: BoundingBox, box2: BoundingBox) -> Bool
    {
        return (box1.x0 <= box2.xf && box1.xf >= box2.x0 && box1.y0 <= box2.yf && box1.yf >= box2.y0);
    }
}
