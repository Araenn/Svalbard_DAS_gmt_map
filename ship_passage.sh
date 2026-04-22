#!/usr/bin/env bash
set -euo pipefail

IBCAO="ibcao_100.nc"
SHIPS_CSV="ships.csv"
TARGET_CRS="EPSG:3996"

OFFSETx=25000
OFFSETy=10000
X0=328000.685765
Y0=-1250000.083459

XMIN=$(echo "$X0 - 0*$OFFSETx" | bc)
XMAX=$(echo "$X0 + $OFFSETx" | bc)
YMIN=$(echo "$Y0 - $OFFSETy" | bc)
YMAX=$(echo "$Y0 + $OFFSETy" | bc)

REGION="${XMIN}/${XMAX}/${YMIN}/${YMAX}"
R_MAIN="-R$REGION"
J_MAIN="-JX18c"

: > ships_xy_all.txt
: > legend_ships.txt
rm -f ship_*.xy ship_*_arrow.xy ships_sorted.csv ships_list.txt legend_all.txt fjord.nc

sort -t, -k4,4 -k5,5 -k3,3 "$SHIPS_CSV" > ships_sorted.csv

while IFS=, read -r lat lon ts name mmsi; do
    read -r x y z < <(echo "$lon $lat 0" | gdaltransform -s_srs EPSG:4326 -t_srs "$TARGET_CRS")
    hour=$(echo "$ts" | cut -d' ' -f2 | cut -d':' -f1)
    printf "%s|%s|%s|%s|%s|%s\n" "$x" "$y" "$ts" "$name" "$mmsi" "$hour" >> ships_xy_all.txt
done < ships_sorted.csv

awk -F'|' '!seen[$4 "|" $5 "|" $6]++ {print $4 "|" $5 "|" $6}' ships_xy_all.txt > ships_list.txt

colors=(
    "#FAB802"  # rouge carmin → fort contraste
    "#7F3B08"  # brun chaud   
  "#C51B7D"  # magenta sombre → parfait pour Plancius 2
   "#5D3A9B"  # violet foncé → parfait pour Plancius 1
  "#E7BBDA"  # vert mer → contraste propre
)

: > legend_ships.txt
i=0

while IFS='|' read -r ship_name ship_mmsi ship_hour; do
    color="${colors[$((i % ${#colors[@]}))]}"

    track_file="ship_${i}.xy"
    arrow_file="ship_${i}_arrow.xy"

    awk -F'|' -v n="$ship_name" -v m="$ship_mmsi" -v h="$ship_hour" \
              -v xmin="$XMIN" -v xmax="$XMAX" -v ymin="$YMIN" -v ymax="$YMAX" '
        ($4 == n && $5 == m && $6 == h) {
            x = $1
            y = $2
            if (x >= xmin && x <= xmax && y >= ymin && y <= ymax) {
                print x, y
            }
        }
    ' ships_xy_all.txt > "$track_file"

    awk '
        {
            x[NR] = $1
            y[NR] = $2
        }
        END {
            if (NR < 2) exit

            x0 = x[NR-1]
            y0 = y[NR-1]
            x1 = x[NR]
            y1 = y[NR]

            dx = x1 - x0
            dy = y1 - y0
            L = sqrt(dx*dx + dy*dy)
            if (L <= 0) exit

            ux = dx / L
            uy = dy / L

            shaft = 0.6 * L

            head = 0.5 * shaft

            c = 0.866025404   # cos(30°)
            s = 0.6   # sin(30°)

            bx = -ux
            by = -uy

            lx = c*bx - s*by
            ly = s*bx + c*by

            rx = c*bx + s*by
            ry = -s*bx + c*by

            xl = x1 + head * lx
            yl = y1 + head * ly
            xr = x1 + head * rx
            yr = y1 + head * ry

            print ">"
            print xs, ys
            print x1, y1

            print ">"
            print x1, y1
            print xl, yl

            print ">"
            print x1, y1
            print xr, yr
        }
    ' "$track_file" > "$arrow_file"

    printf "S 0.25c - 0.35c %s 2.5p 0.5c %s (%sh)\n" \
        "$color" "$ship_name" "$ship_hour" >> legend_ships.txt

    i=$((i + 1))
done < ships_list.txt

gmt begin ship_passage pdf

    gmt set MAP_FRAME_TYPE plain \
            FONT_ANNOT_PRIMARY 12p \
            FONT_LABEL 12p \
            FONT_TITLE 14p

    gmt makecpt -Cibcso -T-6000/0

    gmt grdcut "$IBCAO" $R_MAIN -Gfjord.nc
    gmt grdimage fjord.nc $R_MAIN $J_MAIN -C -I+d

    gmt plot track_ibcao_outer.xy         $R_MAIN $J_MAIN -W2p,black -l"Outer cable"
    gmt plot track_ibcao_outer_section.xy $R_MAIN $J_MAIN -W2p,red   -l"20 km section"

    gmt plot stations_obs.xy $R_MAIN $J_MAIN -St0.55c -Gorange -l"OBS"
    gmt plot stations_st.xy  $R_MAIN $J_MAIN -Sx0.55c -W2.2p,darkgreen -l"Hydrophones"

    i=0
    while IFS='|' read -r ship_name ship_mmsi; do
        color="${colors[$((i % ${#colors[@]}))]}"
        track_file="ship_${i}.xy"
        arrow_file="ship_${i}_arrow.xy"

        gmt plot "$track_file" $R_MAIN $J_MAIN -W4p,"$color" # arrow line

        gmt plot "$track_file" $R_MAIN $J_MAIN -Sc0.25c -G"$color" -W0.5p # points

        gmt plot "$arrow_file" $R_MAIN $J_MAIN -W3p,"$color" # arrow head

        i=$((i + 1))
    done < ships_list.txt

    gmt basemap $R_MAIN $J_MAIN -Baf -BWSen+t"Ships passages at each time window with their direction"

    cat << EOF > legend_all.txt
S 0.25c - 0.35c black 3p 0.5c Outer cable
S 0.25c - 0.35c red   3p 0.5c 20 km section
S 0.25c t 0.35c orange 0.6p,black 0.5c OBS
S 0.25c x 0.35c darkgreen 2.2p 0.5c Hydrophones
D 0.15c 1p
EOF

    cat legend_ships.txt >> legend_all.txt

    gmt legend legend_all.txt -DjBR+w5.5c+o0.25c -F+p1p+gwhite

    gmt colorbar -C \
        -DjBL+o1c/1.3c+w8c/0.2c+h \
        -Bxa1000+l"Depth (m)" \
        -F+p1p+gwhite

gmt end show

rm -f ship_*.xy ship_*_arrow.xy ships_sorted.csv ships_list.txt legend_all.txt fjord.nc *.txt *.gmt