# QPublic Scraper

Accepts a QPublic endpoint and produces a set of addresses with their corresponding lat/lng coordinates

## URL Styles

There are several URL Endpoints that will provide access to the data:

### Desktop Map
`http://qpublic7.qpublic.net/qpmap4/map.php?county=ga_calhoun&layers=parcels`

(Must change state code in URL)

### Mobile Map
`http://qpublic9.qpublic.net/qp_mobile/map.php`

## Dependancies

- python 2.7
- OpenCV 3
- Standard bash env
- curl
- jq
- gdal
- GNU Parallel
- nodejs 0.10.x
