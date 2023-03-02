#!/bin/ksh
set -x

for f in global_latitudes.t126.384.190.grb          global_orography.t126.384.190.rg.f77     global_snowfree_albedo.bosu.t126.384.190.grb global_longitudes.t126.384.190.grb         global_orography.t126.384.190.rg.grb     global_snowfree_albedo.bosu.t126.384.190.rg.grb global_lonsperlat.t126.384.190.txt         global_orography_uf.t126.384.190.grb     global_soilmgldas.t126.384.190.grb global_mtnvar.t126.384.190.f77             global_orography_uf.t126.384.190.rg.f77  global_soiltype.statsgo.t126.384.190.grb global_mtnvar.t126.384.190.rg.f77          global_orography_uf.t126.384.190.rg.grb  global_soiltype.statsgo.t126.384.190.rg.grb global_mxsnoalb.uariz.t126.384.190.grb     global_slmask.t126.384.190.grb           global_vegtype.igbp.t126.384.190.grb global_mxsnoalb.uariz.t126.384.190.rg.grb  global_slmask.t126.384.190.rg.f77        global_vegtype.igbp.t126.384.190.rg.grb global_orography.t126.384.190.grb          global_slmask.t126.384.190.rg.grb ;do

ln -fs $f $(echo $f |sed "s?t126.384.190?t190.384.192?g")

done
