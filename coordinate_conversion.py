import pandas as pd
from pyproj import Transformer, Proj
import numpy as np

###################################################
### CABLE
###################################################

df = pd.read_csv("outer_cable_positions.csv", sep=";")

ps = Proj(proj='stere', lat_0=90, lon_0=0, lat_ts=75, datum='WGS84', units='m')

x, y = ps(df['Lon'].values, df['Lat'].values)

pd.DataFrame({'X': x, 'Y': y}).to_csv('track_ibcao_outer.xy', sep=' ', index=False, header=False)

###################################################
### CABLE SECTION
###################################################

df = pd.read_csv("track_ibcao_outer.xy", sep="\s+", header=None, names=['X','Y'])

dx = np.diff(df['X'])
dy = np.diff(df['Y'])
dist = np.sqrt(dx**2 + dy**2)
cumdist = np.insert(np.cumsum(dist), 0, 0)

df_section = df[cumdist <= 22000]

df_section.to_csv("track_ibcao_outer_section.xy", sep=' ', index=False, header=False)

###################################################
### SENSORS
###################################################

df = pd.read_csv("sensors_positions.csv", sep=';')

def dms_to_dd(s):
    deg, minutes = s.split('°')
    return float(deg) + float(minutes)/60

df['Lat_dd'] = df['Depl_lat_uib'].apply(dms_to_dd)
df['Lon_dd'] = df['Depl_lon_uib'].apply(dms_to_dd)

# Projection PS (IBCAO)
ps = Proj(proj='stere', lat_0=90, lon_0=0, lat_ts=75, datum='WGS84', units='m')

x, y = ps(df['Lon_dd'].values, df['Lat_dd'].values)
df['X'] = x
df['Y'] = y

df_obs = df[df['Station_letter'].str.startswith('OBS')]
df_st  = df[df['Station_letter'].str.startswith('ST')]

df_obs[['X','Y','Station_letter']].to_csv('stations_obs.xy', sep=' ', index=False, header=False)
df_st[['X','Y','Station_letter']].to_csv('stations_st.xy', sep=' ', index=False, header=False)