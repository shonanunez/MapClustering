//
//  MapUtils.swift
//  MapClustering
//
//  Created by Shóna Nunez on 01/03/2017.
//  Copyright © 2017 Shona Nunez. All rights reserved.
//

import UIKit
import CoreLocation
import GoogleMaps

class MapUtils
{
    private var quadTree = QuadTree()
    private var minLatitude = 0.0
    private var maxLatitude = 0.0
    private var minLongitude = 0.0
    private var maxLongitude = 0.0
    private var shouldCheck = true
    private var mapMarkers: [GMSMarker] = []
    
    var backgroundQueue = OperationQueue()
    var mainQueue = OperationQueue.main
    
    func randomLocations(withCount count: Int) -> [MapMarker]
    {
        var array: [MapMarker] = []
        
        for _ in 0...count {
            let item = Annotation()
            item.markerCoordinate = CLLocationCoordinate2D(latitude: drand48() * 40 - 20, longitude: drand48() * 80 - 40 )
            item.markerTitle = "Lat: \(String(format: "%.4f", item.markerCoordinate.latitude)), Long: \(String(format: "%.4f", item.markerCoordinate.longitude))"
            array.append(item)
        }
        
        return array
    }
    
    func generateQuadTreeWithMarkers(_ array: [MapMarker], forVisibleArea visibleMap: GMSMapView) //Creates QuadTree
    {
        let boundary: GMSCoordinateBounds = GMSCoordinateBounds(region: visibleMap.projection.visibleRegion())
        let box = quadTree.boundingBoxForCoordinates(boundary.northEast, southWestCoord: boundary.southWest)
        
        quadTree = QuadTree(boundingBox: box)
        
        let currentZoom: Double = Double(visibleMap.camera.zoom)
        
        var objectArray = [MapMarker]()
        let clusterManager = ClusterManager()
        
        backgroundQueue.maxConcurrentOperationCount = 1
        
        let operationBlock = BlockOperation { () in
            
            for item in array {
                self.quadTree.insertObject(item, atPoint: item.markerCoordinate, checkMinMax: self.shouldCheck)
            }
            
            if self.shouldCheck == true {
                self.minLatitude = self.quadTree.minLatitude
                self.maxLatitude = self.quadTree.maxLatitude
                self.minLongitude = self.quadTree.minLongitude
                self.maxLongitude = self.quadTree.maxLongitude
                self.shouldCheck = false
            }
            
            let coordinateNE = CLLocationCoordinate2DMake(self.maxLatitude, self.maxLongitude)
            let coordinateSW = CLLocationCoordinate2DMake(self.minLatitude, self.minLongitude)
            
            objectArray = clusterManager.clusteredAnnotationsWithinMapRect(self.quadTree, zoomLevel: currentZoom, boundaryNE: coordinateNE, boundarySW: coordinateSW, boundingBox: box)

        }
        
        let mainOperationBlock = BlockOperation { () in
            var tempMarkers: [GMSMarker] = []
            
            for item in objectArray
            {
                let marker = GMSMarker()
                marker.position = item.markerCoordinate
                marker.userData = item
                
                if item.markerClusterCount > 0 && item.markerClusterCount < 99 {
                    marker.snippet = item.markerClusterTitle
                    marker.icon = self.textToImage(String(item.markerClusterCount), inImage: UIImage(named: "clusterMedium")!, atPoint: CGPoint(x: 8, y: 8))
                }
                else if item.markerClusterCount > 100 {
                    marker.snippet = item.markerClusterTitle
                    marker.icon = self.textToImage(String(item.markerClusterCount), inImage: UIImage(named: "clusterLarge")!, atPoint: CGPoint(x: 10, y: 10))
                }
                else {
                    marker.snippet = item.markerTitle
                    marker.icon = self.textToImage("1", inImage: UIImage(named: "clusterSmall")!, atPoint: CGPoint(x: 10, y: 5))
                }
                
                tempMarkers.append(marker)
            }
            
            self.updateMapWithAnnotations(&tempMarkers, map: visibleMap, quadTree:self.quadTree, box: box)
        }
        
        mainOperationBlock.addDependency(operationBlock)
        backgroundQueue.addOperation(operationBlock)
        mainQueue.addOperation(mainOperationBlock)
    }
    
    private func updateMapWithAnnotations(_ newMarkers: inout [GMSMarker], map: GMSMapView, quadTree: QuadTree, box: BoundingBox)
    {
        var toKeep: [GMSMarker] = []
        var toAdd: [GMSMarker] = []
        var toRemove: [GMSMarker] = []
        
        if mapMarkers.count == 0 { //First time
            mapMarkers += newMarkers //Add all newMarkers to mapMarkers
            
            for aMarker in mapMarkers {
                aMarker.map = map
            }
        }
        else {
            for mapMarker in mapMarkers //mapMarkers are the old selection
            {
                for newMarker in newMarkers //newMarkers are the new selection
                {
                    let aMarker = mapMarker.userData as! MapMarker
                    let bMarker = newMarker.userData as! MapMarker
                    
                    if aMarker.isEqualToMarker(bMarker) { //If the markers are the same the old marker is still visible so keep it
                        toKeep.append(mapMarker)
                        
                        if let index = newMarkers.index( where: { ($0.userData as! MapMarker).markerHashValue == bMarker.markerHashValue } ){
                            newMarkers.remove(at: index) //Remove keep marker - logically what's left should be new markers to be added
                        }
                        
                        if let indexMap = mapMarkers.index( where: { ($0.userData as! MapMarker).markerHashValue == bMarker.markerHashValue } ) {
                            mapMarkers.remove(at: indexMap) //Remove keep marker - logically what's left should be old markers to be removed
                        }
                        
                        break
                    }
                }
            }
            
            toAdd += newMarkers
            toRemove += mapMarkers
            
            mapMarkers.removeAll()
            
            for addMarker in toAdd {
                mapMarkers.append(addMarker)
                addMarker.map = map
            }
            
            for keepMarker in toKeep {
                mapMarkers.append(keepMarker)
            }
            
            for removeMarker in toRemove {
                removeMarker.map = nil
            }
        }
    }
    
    //MARK: - Private
    private func textToImage(_ drawText: String, inImage: UIImage, atPoint:CGPoint) -> UIImage?
    {
        let textColor = UIColor.white
        let textFont = UIFont(name: "HelveticaNeue", size: 16)!
        
        let textFontAttributes = [
            NSFontAttributeName: textFont,
            NSForegroundColorAttributeName: textColor,
        ]
        
        UIGraphicsBeginImageContext(inImage.size) //Setup the image context using the passed image
        
        //Put the image into a rectangle as large as the original image
        inImage.draw(in: CGRect(x: 0, y: 0, width: inImage.size.width, height: inImage.size.height))
        
        //Creating a point within the space that is as big as the image
        let rect: CGRect = CGRect(x: atPoint.x, y: atPoint.y, width: inImage.size.width, height: inImage.size.height)
        
        //Draw the text into an image
        drawText.draw(in: rect, withAttributes: textFontAttributes)
        
        //Create a new image out of the images created
        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext() //End the context now that we have the image we need
        
        return newImage
    }
}
