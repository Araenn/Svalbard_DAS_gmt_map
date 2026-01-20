This code use GMT v.6.0 to create a map type .pdf with 3 subplots of the Svalbard area.
First plot is the global area, second a zoom on Isfjorden, and last a zoom on Longyearbyen.
Are also plot the outer fiber optic cable or DAS and symbols (triangle, diamond) for sensors location.

The bathymetry used is from IBCAO and can be found here:
https://www.gebco.net/data-products/gridded-bathymetry-data/arctic-ocean

The lastest version is a 100x100m grid.

The map is in Polar Stereographic (PS) coordinates (meters/meters).

The 2 main files are the .py coordinate conversion and the .sh script.

The .py allows you to convert the cable coordinates (mercator) into PS, that you can find and extract by hand there:
https://www.norgeskart.no/#!?project=norgeskart&layers=1001&zoom=3&lat=7197864.00&lon=396722.00
(select nautical chart, go to Svalbard area and look for the pink lines from Lonyearbyen to Ny-Alesund)
After running, you will have .xy files cwith the new coordinates that you'll need for later

The .sh construct and saves the map into a .pdf
First you load your bathymetry
Then choose your zoomed area (Svalbard in this case) with. This part is calculations of the boundaries.
Then you create the basemap with parameters, and the subplots. Each one is separated, and has title, legend, plots and basemap. The area are created with the grdcut command 
and the previous boundaries (here, $-R$REGION_SVALBARD_PS etc). Some .nc files will be created and used right after. The plots for cable and sensors are made thanks to
the .xy files created earlier (such as track_ibcao_outer.xy etc).

The map is saved and showed at the end of the execution.


On this folder, you can find my own visual extraction of the 2 main cables (inner and outer) as .csv files.