#!/usr/bin/env bash

URL="http://qpublic9.qpublic.net/cgi-bin/mapserv60"

OLDIFS=$IFS
mkdir -p /tmp/parcels/
rm /tmp/parcels/* &>/dev/null

if [ ! -f /tmp/bounds ]; then
    while IFS='' read -r line || [[ -n $line ]]; do
        TOPRIGHT=$(echo $line   | jq -r -c '.geometry | .coordinates | .[] | .[]' | sed '2!d')
        BOTTOMLEFT=$(echo $line | jq -r -c '.geometry | .coordinates | .[] | .[]' | sed '4!d')
        echo "[$TOPRIGHT, $BOTTOMLEFT]" >> /tmp/bounds
    done <<< "$( $(dirname $0)/util/cover.js "$(grep "\"13\"" util/county.geojson | grep "Pierce" | sed 's/,$//' | jq '.geometry')" | jq -r -c '.features | .[]')"
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
ogr2ogr /tmp/parcel_out.geojson /tmp/parcel_tile.shp -t_srs EPSG:4326 -f "GeoJSON"

echo '{ "type": "FeatureCollection", "features": [' > /tmp/parcel_pts.geojson.tmp
grep "DN\": 0" /tmp/parcel_out.geojson >> /tmp/parcel_pts.geojson.tmp
sed -i '$s/,$//' /tmp/parcel_pts.geojson.tmp
echo ']}' >> /tmp/parcel_pts.geojson.tmp

./node_modules/turf-cli/turf-point-on-surface.js /tmp/parcel_pts.geojson.tmp > /tmp/parcel_pts.geojson

function getLatLng() {
    curl "http://qpublic9.qpublic.net/qp_mobile/php/getParcel_mm.php?longitude=$2&latitude=$1" $ARG
}

echo "LAT,LNG,STR,CITY,DISTRICT,REGION" > out.csv
for COORD in $(jq -r -c '.features | .[] | .geometry | .coordinates' /tmp/parcel_pts.geojson); do
    ADDR=$(getLatLng $(echo $COORD | jq '.[1]') $(echo $COORD | jq '.[0]'))

    echo  

    STR=$(echo $ADDR | jq -r -c '.properties | .["Physical Address"]') 
    REG=$(echo $ADDR | jq -r -c '.properties | .md | .state ')
    DIS=$(echo $ADDR | jq -r -c '.properties | .md | .county')
    CIT=$(echo $ADDR | jq -r -c '.properties | .["Taxing District"]')
    echo "$(echo $COORD | jq '.[0]'),$(echo $COORD | jq '.[1]'),$STR,$CIT,$DIS,$REG"
done
