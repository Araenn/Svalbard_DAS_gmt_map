#!/usr/bin/env bash
set -e

IBCAO="ibcao_100.nc"

OFFSET=28000
X0=331419.685765
Y0=-1250000.083459

XMIN=$(echo "$X0 - $OFFSET" | bc)
XMAX=$(echo "$X0 + $OFFSET" | bc)
YMIN=$(echo "$Y0 - $OFFSET" | bc)
YMAX=$(echo "$Y0 + $OFFSET" | bc)

REGION="${XMIN}/${XMAX}/${YMIN}/${YMAX}"

R_MAIN="-R$REGION"
J_MAIN="-JX18c"

REGION_SVALBARD_PS="-263624.366136/726772.996969/-2518126.587061/-98707.603915"
R_SVAL="-R$REGION_SVALBARD_PS"
J_SVAL="-JX5.5c"

OFFSET_IS=200000
XMINIS=$(echo "$X0 - $OFFSET_IS" | bc)
XMAXIS=$(echo "$X0 + $OFFSET_IS" | bc)
YMINIS=$(echo "$Y0 - $OFFSET_IS" | bc)
YMAXIS=$(echo "$Y0 + $OFFSET_IS" | bc)
REGION_ISFJORDEN_PS="${XMINIS}/${XMAXIS}/${YMINIS}/${YMAXIS}"
R_IS="-R$REGION_ISFJORDEN_PS"
J_IS="-JX5.5c"

gmt begin fjord_capteurs_cables pdf

    gmt set MAP_FRAME_TYPE plain \
            FONT_ANNOT_PRIMARY 12p \
            FONT_LABEL 12p \
            FONT_TITLE 14p

    gmt makecpt -Cibcso -T-6000/0

    # =========================
    # Main map
    # =========================
    gmt grdcut "$IBCAO" $R_MAIN -Gfjord.nc
    gmt grdimage fjord.nc $R_MAIN $J_MAIN -C -I+d

    # Câbles
    gmt plot track_ibcao_outer.xy         $R_MAIN $J_MAIN -W3p,black -l"Outer cable"
    gmt plot track_ibcao_outer_section.xy $R_MAIN $J_MAIN -W3p,red   -l"20 km section"

    # Capteurs
    gmt plot stations_obs.xy $R_MAIN $J_MAIN -St0.7c -Gorange -l"OBS"
    gmt plot stations_st.xy  $R_MAIN $J_MAIN -Sx0.7c -W2p,darkgreen         -l"Hydrophones"

    # Cadre
    gmt basemap $R_MAIN $J_MAIN -Baf -BWSen+t"Isfjorden - bathymetry, DAS cable, geophones and hydrophones"

    # Légende
    gmt legend -DjBR+o0.3c -F+p1p+gwhite

    # Colorbar
    gmt colorbar -C \
    -DjBL+o1c/1.3c+w8c/0.2c+h \
    -Bxa1000+l"Depth (m)" \
    -F+p1p+gwhite

    # =========================
    # Inset 1 : World -> Svalbard
    # =========================
    gmt inset begin -DjTL+w4.5c+o0.25c -F+p1p+gwhite
        gmt coast -Rg -JG15/75/4.5c -Ggray80 -Swhite -A1000 -W0.25p
        echo 15 78 | gmt plot -Sc0.18c -Gred -W0.25p
        echo 15 78 Svalbard | gmt text -F+f10p,Helvetica-Bold,red+jLB -Dj0.15c/0.15c
    gmt inset end

    # =========================
    # Inset 2 : Svalbard -> Isfjorden
    # =========================
    gmt inset begin -DjTR+w5.5c+o0.25c -F+p1p+gwhite
        gmt grdcut "$IBCAO" $R_IS -Gsvalbard_inset.nc
        gmt grdimage svalbard_inset.nc $R_IS $J_IS -C -I+d

        gmt plot track_ibcao_outer.xy $R_IS $J_IS -W1p,black

        cat << EOF | gmt plot $R_IS $J_IS -W1.5p,red
$XMIN $YMIN
$XMAX $YMIN
$XMAX $YMAX
$XMIN $YMAX
$XMIN $YMIN
EOF

        echo "$XMAX $YMAX Isfjorden" | gmt text $R_IS $J_IS -F+f10p,Helvetica-Bold,red+jBL -Dj0.1c/0.1c
    gmt inset end

gmt end show