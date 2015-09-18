#!/usr/bin/env bash

# == Avaliable Counties in Georgia =======================
# Seminole ✓    Clinch     ✓    Glynn    ✓    Cook     - 
# Thomas   ✓    Ware       ✓    Brantley ✓    Colquitt -
# Brooks   ✓    Pierce     ✓    Atkinson ✓    Mitchell -
# Lowndes  ✓    Charlton   ✓    Lanier   ✓    Miller   -
# Echols   ✓    Camden     -    Berrien  -    Early  
# Clay          Dougherty       Tift          Irwin
# Calhoun       Worth           Turner        Coffee
# Ben Hill      Telfair         Lee           Randolph
# == Not Avaliable =======================================
# Decatur
# Grady
# Baker
# ======================================================

if [ -z $1 ]; then
    echo "./run <County>"
    exit 1
else
    COUNTY=$1
fi

URL="http://qpublic9.qpublic.net/cgi-bin/mapserv60"

OLDIFS=$IFS

echo "ok - Setting up build environment"
mkdir -p /tmp/${COUNTY}_parcels/
rm /tmp/${COUNTY}_parcels/* &>/dev/null

if [ ! -f /tmp/${COUNTY}_bounds ]; then
    echo "ok - tiling county polygon"
    while IFS='' read -r line || [[ -n $line ]]; do
        TOPRIGHT=$(echo $line   | jq -r -c '.geometry | .coordinates | .[] | .[]' | sed '2!d')
        BOTTOMLEFT=$(echo $line | jq -r -c '.geometry | .coordinates | .[] | .[]' | sed '4!d')
        echo "[$TOPRIGHT, $BOTTOMLEFT]" >> /tmp/${COUNTY}_bounds
    done <<< "$( $(dirname $0)/util/cover.js "$(grep "\"13\"" util/county.geojson | grep "$COUNTY" | sed 's/,$//' | jq '.geometry')" | jq -r -c '.features | .[]')"
else
    echo "ok - using cached tile polygons"
fi

echo "ok - Beginning Download ($(wc -l /tmp/${COUNTY}_bounds | grep -Eo "[0-9]+") tiles)"
cat /tmp/${COUNTY}_bounds | parallel --gnu "$(dirname $0)/util/getImage.sh \"{}\" \"$URL\" \"{#}\" \"$COUNTY\" \"$(wc -l /tmp/${COUNTY}_bounds | grep -Eo "[0-9]+")\""
rm /tmp/${COUNTY}_bounds

echo "ok - merging parcels"
gdal_merge.py -init 255 -o /tmp/${COUNTY}_parcel_out.tif /tmp/${COUNTY}_parcels/*.tif
rm -rf /tmp/${COUNTY}_parcels/

echo "ok - standarize image"
convert /tmp/${COUNTY}_parcel_out.tif \
    \( -alpha remove \) \
    \( -fill black -opaque white \) \
    TIFF64:/tmp/${COUNTY}_parcel_clean.tif

echo "ok - set projection"
./util/gdalcopyproj.py /tmp/${COUNTY}_parcel_out.tif /tmp/${COUNTY}_parcel_clean.tif
rm /tmp/${COUNTY}_parcel_out.tif

echo "ok - gdal_polygonize"
gdal_polygonize.py -nomask /tmp/${COUNTY}_parcel_clean.tif -f "ESRI Shapefile" /tmp/${COUNTY}_parcel_tile.shp
rm /tmp/${COUNTY}_parcel_clean.tif

echo "ok - reproject to 4326"
# Polygonize will be as 54004 even though it is actually 3857
ogr2ogr /tmp/${COUNTY}_parcel_out.geojson /tmp/${COUNTY}_parcel_tile.shp -s_srs EPSG:3857 -t_srs EPSG:4326 -f "GeoJSON"
rm /tmp/${COUNTY}_parcel_tile.*

echo "ok - filter by black"
echo '{ "type": "FeatureCollection", "features": [' > /tmp/${COUNTY}_parcel_pts.geojson.tmp
grep "DN\": 0" /tmp/${COUNTY}_parcel_out.geojson >> /tmp/${COUNTY}_parcel_pts.geojson.tmp
sed -i '$s/,$//' /tmp/${COUNTY}_parcel_pts.geojson.tmp
echo ']}' >> /tmp/${COUNTY}_parcel_pts.geojson.tmp

echo "ok - poly => pt"
./node_modules/turf-cli/turf-point-on-surface.js /tmp/${COUNTY}_parcel_pts.geojson.tmp > /tmp/${COUNTY}_parcel_pts.geojson
rm /tmp/${COUNTY}_parcel_pts.geojson.tmp


jq -r -c '.features | .[] | .geometry | .coordinates' /tmp/${COUNTY}_parcel_pts.geojson > /tmp/${COUNTY}_coords
PROG_TOT=$(wc -l /tmp/${COUNTY}_parcel_pts.geojson | grep -Po '\d+')
rm /tmp/${COUNTY}_parcel_pts.geojson

echo "LNG,LAT,STR,DISTRICT,REGION" > ${COUNTY}_out.csv
cat /tmp/${COUNTY}_coords | parallel -j1 --gnu "./util/getAddress.sh \"{}\" \"{#}\" \"$PROG_TOT\" \"$COUNTY\""
rm /tmp/${COUNTY}_coords
