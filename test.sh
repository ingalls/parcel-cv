find /tmp/parcels -type f -name '*.tif' > /tmp/tifs
gdal_merge.py -init 255 -o out.tif --optfile /tmp/tifs -createonly

for FILE in $(cat /tmp/tifs); do
    gdalwarp $FILE out.tif
done
