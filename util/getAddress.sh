# Args
# $1 COORDS 
# $2 Job #
# $3 Total Jobs
# $4 County

function getLatLng() {
    curl --silent "http://qpublic9.qpublic.net/qp_mobile/php/getParcel_mm.php?longitude=$2&latitude=$1"
}

COORD=$(echo $1 | sed 's/\\//g')
ADDR=$(getLatLng $(echo $COORD | jq '.[1]') $(echo $COORD | jq '.[0]'))

STR=$(echo $ADDR | jq -r -c '.properties | .["Physical Address"]')
REG=$(echo $ADDR | jq -r -c '.properties | .md | .state ')
DIS=$(echo $ADDR | jq -r -c '.properties | .md | .county')

if [[ ! -z $COORD ]] && [[ ! -z $STR ]]; then
    echo "$(echo $COORD | jq '.[0]'),$(echo $COORD | jq '.[1]'),\"$STR\",\"$DIS\",\"$REG\"" >> ${4}_out.csv
fi
echo "$2/$3"
