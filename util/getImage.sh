#!/usr/bin/env bash

Q=$(echo $1 | sed 's/\\//g' | jq '.[0] | .[0]')
W=$(echo $1 | sed 's/\\//g' | jq '.[0] | .[1]')
E=$(echo $1 | sed 's/\\//g' | jq '.[1] | .[0]')
R=$(echo $1 | sed 's/\\//g' | jq '.[1] | .[1]')

# $1 Bounds [[UPPERLEFT], [LOWERRIGHT]]
# $2 BaseURL
# $3 ID

# Get Map Image
QUERY=$(echo \
    "$2" \
    "?SERVICE=WMS" \
    "&REQUEST=GetMap" \
    "&VERSION=1.1.1" \
    "&LAYERS=parcels" \
    "&STYLES=" \
    "&FORMAT=image%2Fpng" \
    "&TRANSPARENT=true" \
    "&HEIGHT=512" \
    "&WIDTH=512" \
    "&MAP=%2Fvar%2Fwww%2Fmaps%2Fus%2Fregional%2Fqpmap4_mm.map" \
    "&SRS=EPSG%3A3857" \
    "&BBOX=$Q,$R,$E,$W" \
    | sed 's/ //g'
)

curl -s $QUERY > /tmp/$3.png
gdal_translate -of GTiff -a_ullr $Q $W $E $R -a_srs "EPSG:3857" /tmp/$3.png /tmp/parcels/$(md5 -r /tmp/$3.png | grep -po ".* " | sed 's/ //').tif &>/dev/null

rm /tmp/$3.*
echo "$3/$4"
