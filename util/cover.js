#!/usr/bin/env node

var cover = require('tile-cover');
var R = require('reproject');
var proj4 = require('proj4');

//cover.js "GeoJSON Polygon"
if (!process.argv[2]) throw new Error('GeoJSON polygon argument required');

ply = cover.geojson(JSON.parse(process.argv[2]), {
    min_zoom: 17,
    max_zoom: 17
});
ply = R.reproject(ply, 'EPSG:4326', 'EPSG:3857', {
    'EPSG:4326': proj4('EPSG:4326'),
    'EPSG:3857': proj4('EPSG:3857')
});

console.log(JSON.stringify(ply))
