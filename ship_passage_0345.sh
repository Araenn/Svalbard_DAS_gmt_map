#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR at line $LINENO: $BASH_COMMAND"' ERR

IBCAO="ibcao_100.nc"
SHIPS_CSV="ships.csv"
TARGET_CRS="EPSG:3996"

# Passage AIS affiche
TARGET_HOUR="03"
TARGET_LABEL="03h45"
TARGET_HOURS_RE='^03$'

OFFSETx=22000
OFFSETy=8000
X0=328000.685765
Y0=-1250000.083459

XMIN=$(echo "$X0 - 0*$OFFSETx" | bc)
XMAX=$(echo "$X0 + $OFFSETx" | bc)
YMIN=$(echo "$Y0 - $OFFSETy" | bc)
YMAX=$(echo "$Y0 + $OFFSETy" | bc)

# Region en metres pour decouper la grille IBCAO
REGION_M="${XMIN}/${XMAX}/${YMIN}/${YMAX}"
R_GRID="-R$REGION_M"

# Region en kilometres pour l'affichage GMT
XMIN_KM=$(awk -v v="$XMIN" 'BEGIN {printf "%.6f", v/1000}')
XMAX_KM=$(awk -v v="$XMAX" 'BEGIN {printf "%.6f", v/1000}')
YMIN_KM=$(awk -v v="$YMIN" 'BEGIN {printf "%.6f", v/1000}')
YMAX_KM=$(awk -v v="$YMAX" 'BEGIN {printf "%.6f", v/1000}')

REGION="${XMIN_KM}/${XMAX_KM}/${YMIN_KM}/${YMAX_KM}"
R_MAIN="-R$REGION"

# Taille classique de la figure unique.
# Le rapport 14/10 est proche du rapport de la region (22 km / 16 km).
J_MAIN="-JX14c/10c"

rm -f ship_*.xy ship_*_arrow.xy \
      ships_xy_all.txt ships_sorted.csv ships_list.txt ships_plot_list.txt \
      legend_all_*.txt legend_ships_*.txt \
      fjord.nc fjord_bathy.nc fjord_km.nc bathy_global.cpt \
      track_ibcao_outer_km.xy track_ibcao_outer_section_km.xy \
      stations_obs_km.xy stations_st_km.xy \
      location_A_box.xy location_A_box_m.xy \
      location_B_box.xy location_B_box_m.xy

: > ships_xy_all.txt
: > ships_plot_list.txt
: > "legend_ships_${TARGET_HOUR}.txt"

sort -t, -k4,4 -k5,5 -k3,3 "$SHIPS_CSV" > ships_sorted.csv

# =========================
# CSV -> coordonnees projetees
# =========================

while IFS=, read -r lat lon ts name mmsi; do
    read -r x y z < <(
        echo "$lon $lat 0" |
            gdaltransform -s_srs EPSG:4326 -t_srs "$TARGET_CRS"
    )

    hour_raw=$(echo "$ts" | cut -d' ' -f2 | cut -d':' -f1)
    hour=$(printf "%02d" "$((10#$hour_raw))")

    read -r x y < <(
        awk -v x="$x" -v y="$y" \
            'BEGIN {printf "%.6f %.6f\n", x/1000, y/1000}'
    )

    printf "%s|%s|%s|%s|%s|%s\n" \
        "$x" "$y" "$ts" "$name" "$mmsi" "$hour" \
        >> ships_xy_all.txt
done < ships_sorted.csv

# Liste unique bateau + MMSI pour l'heure 03 uniquement
awk -F'|' -v re="$TARGET_HOURS_RE" '
    ($6 ~ re) && !seen[$4 "|" $5 "|" $6]++ {
        print $4 "|" $5 "|" $6
    }
' ships_xy_all.txt > ships_list.txt

colors=(
  "#3B4CC0"  # deep blue
  "#B40426"  # deep red
  "#447303"  # green
  "#6F6F6F"  # grey
  "#034E73"
  "#7A3EB1"  # purple
)

# =========================
# Fichiers trajectoires
# =========================

i=0

while IFS='|' read -r ship_name ship_mmsi ship_hour; do
    color="${colors[$((i % ${#colors[@]}))]}"

    track_file="ship_${i}.xy"
    arrow_file="ship_${i}_arrow.xy"

    awk -F'|' \
        -v n="$ship_name" \
        -v m="$ship_mmsi" \
        -v h="$ship_hour" \
        -v xmin="$XMIN_KM" \
        -v xmax="$XMAX_KM" \
        -v ymin="$YMIN_KM" \
        -v ymax="$YMAX_KM" '
        ($4 == n && $5 == m && $6 == h) {
            x = $1
            y = $2
            if (x >= xmin && x <= xmax && y >= ymin && y <= ymax) {
                print x, y
            }
        }
    ' ships_xy_all.txt > "$track_file"

    if [ ! -s "$track_file" ]; then
        rm -f "$track_file"
        continue
    fi

    awk '
    {
        x[NR] = $1
        y[NR] = $2
    }
    END {
        if (NR < 2) exit

        print x[NR],   y[NR]
        print x[NR-1], y[NR-1]
    }
    ' "$track_file" > "$arrow_file"

    printf "%s|%s|%s|%s|%s\n" \
        "$i" "$ship_name" "$ship_mmsi" "$ship_hour" "$color" \
        >> ships_plot_list.txt

    printf "S 0.18c - 0.38c %s 5p 0.55c %s (%s)\n" \
        "$color" "$ship_name" "$TARGET_LABEL" \
        >> "legend_ships_${TARGET_HOUR}.txt"

    i=$((i + 1))
done < ships_list.txt

# =========================
# LOCATION BOXES + CONVERSION DES FICHIERS FIXES
# =========================

echo "Creating location boxes..."

cat << EOF > location_A_box_m.xy
>
342861.68294550787 -1245725.467105799
345261.68294550787 -1245725.467105799
345261.68294550787 -1243325.467105799
342861.68294550787 -1243325.467105799
342861.68294550787 -1245725.467105799
EOF

cat << EOF > location_B_box_m.xy
>
332725.04464564595 -1252023.1616790376
335125.04464564595 -1252023.1616790376
335125.04464564595 -1249623.1616790376
332725.04464564595 -1249623.1616790376
332725.04464564595 -1252023.1616790376
EOF

echo "Converting fixed XY files from m to km..."

convert_xy_to_km() {
    local input="$1"
    local output="$2"

    echo "  $input -> $output"

    if [ ! -f "$input" ]; then
        echo "ERROR: missing file: $input"
        exit 1
    fi

    awk '
        BEGIN {
            FS="[ \t,]+"
            OFS=" "
        }

        /^[[:space:]]*$/ {
            print
            next
        }

        /^[[:space:]]*>/ {
            print ">"
            next
        }

        /^[[:space:]]*#/ {
            print
            next
        }

        {
            if (NF < 2) {
                print "BAD LINE in " FILENAME " line " NR ": " $0 > "/dev/stderr"
                exit 2
            }

            printf "%.6f %.6f", $1 / 1000.0, $2 / 1000.0

            for (i = 3; i <= NF; i++) {
                printf " %s", $i
            }

            printf "\n"
        }
    ' "$input" > "$output"

    echo "  created $output:"
    head -n 3 "$output"
}

convert_xy_to_km track_ibcao_outer.xy         track_ibcao_outer_km.xy
convert_xy_to_km track_ibcao_outer_section.xy track_ibcao_outer_section_km.xy
convert_xy_to_km stations_obs.xy              stations_obs_km.xy
convert_xy_to_km stations_st.xy               stations_st_km.xy
convert_xy_to_km location_A_box_m.xy          location_A_box.xy
convert_xy_to_km location_B_box_m.xy          location_B_box.xy

echo "Fixed XY conversion done."

# =========================
# FIGURE UNIQUE : 03h45
# =========================

gmt begin ship_passage_0345 pdf

    gmt set MAP_FRAME_TYPE plain \
            FONT_ANNOT_PRIMARY 14p \
            FONT_LABEL 14p \
            FONT_TITLE 14p \
            MAP_TITLE_OFFSET 0.05c

    # Decoupe en metres
    gmt grdcut "$IBCAO" $R_GRID -Gfjord.nc

    # Copie avec les axes x/y convertis en kilometres
    cp fjord.nc fjord_km.nc
    gmt grdedit fjord_km.nc -R"$REGION"

    gmt makecpt -Cibcso -T-6000/0 -H > bathy_global.cpt

    ZMIN=$(gmt grdinfo fjord_km.nc -C | awk '{print $6}')
    ZMIN_BAR="$ZMIN"

    # Bathymetrie
    gmt grdimage fjord_km.nc \
        $R_MAIN $J_MAIN \
        -Cbathy_global.cpt \
        -I+d \
        -t25

    # Fibre DAS
    gmt plot track_ibcao_outer_km.xy \
        $R_MAIN $J_MAIN \
        -W2.8p,black

    gmt plot track_ibcao_outer_section_km.xy \
        $R_MAIN $J_MAIN \
        -W2.8p,red

    # Stations
    gmt plot stations_obs_km.xy \
        $R_MAIN $J_MAIN \
        -St0.65c \
        -Gorange

    gmt plot stations_st_km.xy \
        $R_MAIN $J_MAIN \
        -Sx0.65c \
        -W2.4p,darkgreen

    # Zones A et B
    gmt plot location_A_box.xy \
        $R_MAIN $J_MAIN \
        -W0.9p,black,--

    gmt plot location_B_box.xy \
        $R_MAIN $J_MAIN \
        -W0.9p,black,--

    gmt text $R_MAIN $J_MAIN \
        -F+f11p,Helvetica-Bold,black+jCB << EOF
344.061683 -1242.925467 Location A
333.925045 -1249.223162 Location B
EOF

    # Trajectoires AIS du passage de 03h45
    while IFS='|' read -r idx ship_name ship_mmsi ship_hour color; do
        [ "$ship_hour" = "$TARGET_HOUR" ] || continue

        track_file="ship_${idx}.xy"
        arrow_file="ship_${idx}_arrow.xy"

        [ -s "$track_file" ] || continue

        gmt plot "$track_file" \
            $R_MAIN $J_MAIN \
            -W1p,"$color"

        gmt plot "$track_file" \
            $R_MAIN $J_MAIN \
            -Sc0.30c \
            -G"$color" \
            -W0.5p,black

        if [ -s "$arrow_file" ]; then
            gmt plot "$arrow_file" \
                $R_MAIN $J_MAIN \
                -W3p,"$color"+v0.7c+eA+h1.25
        fi
    done < ships_plot_list.txt

    # Axes et titre
    gmt basemap $R_MAIN $J_MAIN \
        -Bxa2f1+l"Easting (km)" \
        -Bya2f1+l"Northing (km)" \
        -BWSen+t"${TARGET_LABEL}"

    # Legende des navires
    gmt legend "legend_ships_${TARGET_HOUR}.txt" \
        -DjBR+w6.5c+o0.25c \
        -F+p0.9p+gwhite@10

    # Echelle bathymetrique centree sous la carte, a l'exterieur du cadre
    gmt colorbar -Cbathy_global.cpt \
        -G${ZMIN_BAR}/0 \
        -DjBL+o1c/1.2c+w4c/0.2c+h \
        -Bxa50+l"Depth (m)" \
        -F+p1p+gwhite

# Finalise le PDF sans tenter de l'ouvrir automatiquement.
# Utiliser "gmt end show" uniquement sur une machine avec interface graphique.
gmt end

rm -f ship_*.xy ship_*_arrow.xy \
      ships_xy_all.txt ships_sorted.csv ships_list.txt ships_plot_list.txt \
      legend_all_*.txt legend_ships_*.txt \
      fjord.nc fjord_km.nc fjord_bathy.nc bathy_crop.cpt bathy_global.cpt \
      track_ibcao_outer_km.xy track_ibcao_outer_section_km.xy \
      stations_obs_km.xy stations_st_km.xy \
      location_A_box.xy location_A_box_m.xy \
      location_B_box.xy location_B_box_m.xy
