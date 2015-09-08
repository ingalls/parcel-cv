#!/usr/bin/env bash

FULLBASE="http://qpublic7.qpublic.net/cgi-bin/mapserv56"
HALFBASE="http://qpublic9.qpublic.net/cgi-bin/mapserv60"
MAP="/qpub1/maps/ga/pierce/parcel4.map"

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

echo "Beginning Download"
    cat /tmp/bounds | parallel --gnu -j4 "$(dirname $0)/util/getImage.sh \"{}\" \"$HALFBASE\" \"{#}\""
exit

gdal_merge.py -init 255 -o out.tif /tmp/parcels/*.tif

