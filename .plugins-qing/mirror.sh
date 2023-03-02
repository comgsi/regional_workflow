#!/bin/bash                                                                                                                                                                              
#
# FIX_RRFS mirrors at different HPC platforms
#
HPSS_DIR="/PATH/TO/HPSS/DIR"

if [[ -d /lfs/h2 ]] ; then
    PLATFORM=wcoss2
    MIRROR="/PATH/TO/MIRROR/DIR"
elif [[ -d /scratch1 ]] ; then
    PLATFORM=hera
    MIRROR="/PATH/TO/MIRROR/DIR"
elif [[ -d /carddata ]] ; then
    PLATFORM=s4
    MIRROR="/to/do"
elif [[ -d /jetmon ]] ; then
    PLATFORM=jet
    MIRROR="/PATH/TO/MIRROR/DIR"
elif [[ -d /glade ]] ; then
    PLATFORM=cheyenne
    MIRROR="/PATH/TO/MIRROR/DIR"
elif [[ -d /sw/gaea ]] ; then
    PLATFORM=gaea
    MIRROR="/to/do"
elif [[ -d /work ]]; then
    PLATFORM=orion
    MIRROR="/PATH/TO/MIRROR/DIR"
else
    PLATFORM=unknow
    MIRROR="/this/is/an/unknow/platform"
    exit 1
fi
