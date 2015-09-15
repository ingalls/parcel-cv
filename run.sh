#!/usr/bin/env bash

# Done:
#COUNTY="Seminole" #Seminole, ga

COUNTY="Pierce" #Pierce, ga

URL="http://qpublic9.qpublic.net/cgi-bin/mapserv60"

OLDIFS=$IFS
mkdir -p /tmp/parcels/
rm /tmp/parcels/* &>/dev/null

if [ ! -f /tmp/bounds ]; then
    while IFS='' read -r line || [[ -n $line ]]; do
        TOPRIGHT=$(echo $line   | jq -r -c '.geometry | .coordinates | .[] | .[]' | sed '2!d')
        BOTTOMLEFT=$(echo $line | jq -r -c '.geometry | .coordinates | .[] | .[]' | sed '4!d')
        echo "[$TOPRIGHT, $BOTTOMLEFT]" >> /tmp/bounds
    done <<< "$( $(dirname $0)/util/cover.js "$(grep "\"13\"" util/county.geojson | grep "$COUNTY" | sed 's/,$//' | jq '.geometry')" | jq -r -c '.features | .[]')"
fi

echo "Beginning Download ($(wc -l /tmp/bounds | grep -Eo "[0-9]+") tiles)"
cat /tmp/bounds | parallel --gnu "$(dirname $0)/util/getImage.sh \"{}\" \"$URL\" \"{#}\" \"$(wc -l /tmp/bounds | grep -Eo "[0-9]+")\""

gdal_merge.py -init 255 -o /tmp/parcel_out.tif /tmp/parcels/*.tif
convert /tmp/parcel_out.tif \
    \( -alpha remove \) \
    \( -fill black -opaque white \) \
    TIFF64:/tmp/parcel_clean.tif
./util/gdalcopyproj.py /tmp/parcel_out.tif /tmp/parcel_clean.tif
gdal_polygonize.py -nomask /tmp/parcel_clean.tif -f "ESRI Shapefile" /tmp/parcel_tile.shp

# Polygonize will be as 54004 even though it is actually 3857
ogr2ogr /tmp/parcel_out.geojson /tmp/parcel_tile.shp -s_srs EPSG:3857 -t_srs EPSG:4326 -f "GeoJSON"

echo '{ "type": "FeatureCollection", "features": [' > /tmp/parcel_pts.geojson.tmp
grep "DN\": 0" /tmp/parcel_out.geojson >> /tmp/parcel_pts.geojson.tmp
sed -i '$s/,$//' /tmp/parcel_pts.geojson.tmp
echo ']}' >> /tmp/parcel_pts.geojson.tmp

./node_modules/turf-cli/turf-point-on-surface.js /tmp/parcel_pts.geojson.tmp > /tmp/parcel_pts.geojson

function getLatLng() {
    curl --silent "http://qpublic9.qpublic.net/qp_mobile/php/getParcel_mm.php?longitude=$2&latitude=$1"
}

echo "LAT,LNG,STR,DISTRICT,REGION" > out.csv
PROG_TOT=$(wc -l /tmp/parcel_pts.geojson | grep -Po '\d+')
PROG_CUR=0
for COORD in $(jq -r -c '.features | .[] | .geometry | .coordinates' /tmp/parcel_pts.geojson); do
    ADDR=$(getLatLng $(echo $COORD | jq '.[1]') $(echo $COORD | jq '.[0]'))

    STR=$(echo $ADDR | jq -r -c '.properties | .["Physical Address"]') 
    REG=$(echo $ADDR | jq -r -c '.properties | .md | .state ')
    DIS=$(echo $ADDR | jq -r -c '.properties | .md | .county')
   
    if [[ ! -z $COORD ]] || [[ ! -z $STR ]]; then
        echo "$(echo $COORD | jq '.[0]'),$(echo $COORD | jq '.[1]'),\"$STR\",\"$DIS\",\"$REG\"" >> out.csv
    fi
    PROG_CUR=$((PROG_CUR+1))
    echo "$PROG_CUR/$PROG_TOT"
done
