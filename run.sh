#!/usr/bin/env bash

URL="http://qpublic9.qpublic.net/cgi-bin/mapserv60"

# getLatLng
# - Args: $1=Latitude $2=Longitude
# - Returns: String GeoJSON containing geometry
function getLatLng() {
    curl "http://qpublic9.qpublic.net/qp_mobile/php/getParcel_mm.php?longitude=$2&latitude=$1" $ARG
}

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
cat /tmp/bounds | parallel --gnu -j4 "$(dirname $0)/util/getImage.sh \"{}\" \"$URL\" \"{#}\" \"$(wc -l /tmp/bounds | grep -Eo "[0-9]+")\""

gdal_merge.py -init 255 -o /tmp/parcel_out.tif /tmp/parcels/*.tif
convert /tmp/parcel_out.tif \
    \( -alpha off -fill black -opaque white -alpha on \) \
    \( -transparent black \) \
    TIFF64:trans.tif

./util/gdalcopyproj.py /tmp/parcel_out.tif trans.tif

