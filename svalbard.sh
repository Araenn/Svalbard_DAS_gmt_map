#!/usr/bin/env bash
set -e

IBCAO="ibcao_100.nc"


# Svalbard area in PS coordinates
REGION_SVALBARD_PS="-263624.366136/726772.996969/-2518126.587061/-98707.603915"

## zoom on Isfjorden ##
# Offset (meters) to adjust
OFFSET_X=90000
OFFSET_Y=40000
# Reference point
X0=349784.449892
Y0=-1249283.373283
# bottom left
REGION_ISFJORDEN_PS_X_bot=$(echo "$X0 - $OFFSET_X" | bc)
REGION_ISFJORDEN_PS_Y_bot=$(echo "$Y0 - $OFFSET_Y" | bc)
# adjustment
REGION_ISFJORDEN_PS_X_top=$(echo "$REGION_ISFJORDEN_PS_X_bot + 130000" | bc)
REGION_ISFJORDEN_PS_Y_top=$(echo "$REGION_ISFJORDEN_PS_Y_bot + 130000" | bc)
# final variable
REGION_ISFJORDEN_PS="${REGION_ISFJORDEN_PS_X_bot}/${REGION_ISFJORDEN_PS_X_top}/${REGION_ISFJORDEN_PS_Y_bot}/${REGION_ISFJORDEN_PS_Y_top}"


## same thing for Lonyearbyen ##

OFFSET_X=40000
OFFSET_Y=$OFFSET_X
OFFSET_X2=$OFFSET_X
OFFSET_Y2=$OFFSET_X

LONGYEARBYEN_X=359419.685765
LONGYEARBYEN_Y=-1218936.083459

REGION_LONGYEARBYEN_PS_X_bot=$(echo "$LONGYEARBYEN_X - $OFFSET_X" | bc)
REGION_LONGYEARBYEN_PS_Y_bot=$(echo "$LONGYEARBYEN_Y - $OFFSET_Y" | bc)

REGION_LONGYEARBYEN_PS_X_top=$(echo "$REGION_LONGYEARBYEN_PS_X_bot + $OFFSET_X2" | bc)
REGION_LONGYEARBYEN_PS_Y_top=$(echo "$REGION_LONGYEARBYEN_PS_Y_bot + $OFFSET_Y2" | bc)

REGION_LONGYEARBYEN_PS="${REGION_LONGYEARBYEN_PS_X_bot}/${REGION_LONGYEARBYEN_PS_X_top}/${REGION_LONGYEARBYEN_PS_Y_bot}/${REGION_LONGYEARBYEN_PS_Y_top}"

## creation of the map ##

gmt begin svalbard_isfjorden_ps pdf
gmt set MAP_FRAME_TYPE plain FONT_ANNOT_PRIMARY 16p FONT_LABEL 10p FONT_TITLE 14p
gmt makecpt -Cibcso -T-6000/0

gmt subplot begin 2x2 -Fs24c/24c -M1.2c -A+jTL+o1c

# (a) Svalbard
gmt subplot set 0
gmt grdcut $IBCAO -R$REGION_SVALBARD_PS -Gglobal_svalbard.nc
gmt grdimage global_svalbard.nc -R$REGION_SVALBARD_PS -JX24c -C -I+d
gmt plot track_ibcao_outer.xy -R$REGION_SVALBARD_PS -JX24c -W3p,black -l"Outer cable"
#gmt plot track_ibcao_inner.xy -R$REGION_SVALBARD_PS -JX24c -W3p,pink
gmt basemap -Baf -BWSen+t"Svalbard - Bathymetry IBCAO v4 (PS)"
gmt legend -DjTR+o1c -F+p1p+ggray95

# (b) Isfjorden
gmt subplot set 1
gmt grdcut $IBCAO -R$REGION_ISFJORDEN_PS -Gisfjorden.nc
gmt grdimage isfjorden.nc -R$REGION_ISFJORDEN_PS -JX24c -C -I+d
gmt plot track_ibcao_outer.xy -R$REGION_ISFJORDEN_PS -JX24c -W4p,black -l"Outer cable"
gmt plot track_ibcao_outer_section.xy -R$REGION_ISFJORDEN_PS -JX24c -W3p,red -l"20 km section"
gmt plot stations_obs.xy -R$REGION_ISFJORDEN_PS -St1c -Gdarkgreen -l"OBS"
#gmt text stations_obs.xy -R$REGION_ISFJORDEN_PS -F+f8p+jBR -Dj0.1c/0.5c
gmt plot stations_st.xy -R$REGION_ISFJORDEN_PS -Sx1c -Gorange -l"Hydrophones"
#gmt text stations_st.xy -R$REGION_ISFJORDEN_PS -F+f8p+jTL -Dj0.1c/0.5c
gmt basemap -Baf -BWSen+t"Isfjorden - Bathymetry IBCAO v4 (PS)"
gmt legend -DjTR+o1c -F+p1p+ggray95

# (c) LONGYEARBYEN
gmt subplot set 2
gmt grdcut $IBCAO -R$REGION_LONGYEARBYEN_PS -Glongyearbyen_ibcao.nc
gmt grdimage longyearbyen_ibcao.nc -R$REGION_LONGYEARBYEN_PS -JX24c -C -I+d

gmt plot track_ibcao_outer.xy -R$REGION_LONGYEARBYEN_PS -JX24c -W4p,black -l"Outer cable"
gmt plot track_ibcao_outer_section.xy -R$REGION_LONGYEARBYEN_PS -JX24c -W3p,red -l"20 km section"
gmt plot stations_obs.xy -R$REGION_LONGYEARBYEN_PS -St1c -Gdarkgreen -l"OBS"
#gmt text stations_obs.xy -R$REGION_LONGYEARBYEN_PS -F+f8p+jBR -Dj0.1c/0.5c
gmt plot stations_st.xy -R$REGION_LONGYEARBYEN_PS -Sx1c -Gorange -l"Hydrophones"
#gmt text stations_st.xy -R$REGION_LONGYEARBYEN_PS -F+f8p+jTL -Dj0.1c/0.5c

gmt basemap -Baf -BWSen+t"Longyearbyen - Bathymetry IBCAO v4 (PS)"
gmt legend -DjTR+o1c -F+p1p+ggray95

gmt set FONT_ANNOT_PRIMARY 8p
gmt colorbar -C -Dx0c/-1.5c+w50c/0.5c+h -Bxa1000+l"Depth (m)"
gmt subplot end
gmt end show
