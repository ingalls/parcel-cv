#!/usr/bin/env python

import numpy as np
from osgeo import gdal
from osgeo import osr
from osgeo import ogr
from tifffile import imread #Needed for bigtiff files
from tifffile import imsave
import cv2
import json

def main(): 

    hDataset = gdal.Open('../trans.tif', gdal.GA_ReadOnly)
    projection = hDataset.GetProjectionRef()

    #Ensure projection is EPSG:3857
    hSRS = osr.SpatialReference()
    hSRS.ImportFromWkt(projection)
    if hSRS.GetAuthorityCode(None) != "3857": raise Exception('Input must be EPSG:3857')

    UpperLeft = getCorner( hDataset, 0.0, 0.0 );
    
    adfGeoTransform = hDataset.GetGeoTransform(can_return_null = True)
    PixelSize = (adfGeoTransform[1], adfGeoTransform[5])
   
    img = imread('../trans.tif')
    img = cv2.Canny(img, 0, 100)

    imsave('../canny.tif', img)
    
    #Legacy findContour method - currently using GDAL Polygonize
    #_, cnts, heirarchy = cv2.findContours(img, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
    #toGeoJSON(cnts)

def toGeoJSON(cnts):
    print('{ "type": "FeatureCollection", "features": [')
    for poly in cnts:
        coords = [];    
   
        for pt in poly.tolist():
            pt = pt[0]

            source = osr.SpatialReference()
            source.ImportFromEPSG(3857)

            target = osr.SpatialReference()
            target.ImportFromEPSG(4326)

            transform = osr.CoordinateTransformation(source, target)

            point = ogr.CreateGeometryFromWkt("POINT (" + str(UpperLeft[0] + (pt[0] * PixelSize[0])) + " " + str(UpperLeft[1] + (pt[1] * PixelSize[1])) + ")")
            point.Transform(transform)
            coords.append([point.GetX(), point.GetY()])
        coords.append(coords[0])

        geojson = {
            "type": "Feature",
            "properties": {},
            "geometry": {
                "type": 'Polygon',
                "coordinates": [coords]
            }
        }

        print(json.dumps(geojson))

    print("]}")

def getCorner( hDataset, x, y ):
    adfGeoTransform = hDataset.GetGeoTransform(can_return_null = True)
    dfGeoX = adfGeoTransform[0] + adfGeoTransform[1] * x + adfGeoTransform[2] * y
    dfGeoY = adfGeoTransform[3] + adfGeoTransform[4] * x + adfGeoTransform[5] * y

    return (dfGeoX, dfGeoY)
main()
