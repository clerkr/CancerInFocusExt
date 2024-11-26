
# Import packages

import sqlalchemy as sa
import pandas as pd
import csv
import json
import os

# Set Area we serve variable
AWS = ['Utah', 'Idaho', 'Wyoming', 'Montana', 'Nevada']

# Setup connection to SHAPE
connection_url = sa.engine.URL.create(
    "mssql+pyodbc",
    username="sysshape",
    password="m@cb3+h!",
    host="HCI-DBDEV",
    database="SHAPE",
    query={'driver': 'ODBC Driver 18 for SQL Server', 'TrustServerCertificate': 'yes'}
)
engine = sa.create_engine(connection_url)
conn = engine.connect()

# Read AQI table
aqi = pd.read_sql('select * from epa.Aqi', conn)

# Read Radon table
radon = pd.read_sql('select * from epa.Radon', conn)

# Close the connection
conn.close()

# ----- AQI -------

# Filter aqi to area we serve
aqi = aqi[[x in AWS for x in aqi['state']]]

# Only keep the columns we want
aqi = aqi.drop('idAqi', axis='columns')

# Create long data and rename columns
aqi_long = pd.melt(aqi, id_vars=['state', 'county', 'fips'], var_name='measure', value_name='value')
aqi_long.columns = ['State', 'County', 'GEOID', 'measure', 'value']

# Create columns for category, race/ethnicity, and sex
aqi_long['cat'] = 'Environment'
aqi_long['RE'] = pd.NA
aqi_long['Sex'] = pd.NA

# Create measure definitions column
aqi_defs = json.load(open('setup/SHAPE/data/definitions/aqi.json'))
aqi_long['def'] = aqi_long['measure'].apply(lambda x: aqi_defs[x])

# Create format column
aqi_fmt = json.load(open('setup/SHAPE/data/formats/aqi.json'))
aqi_long['fmt'] = aqi_long['measure'].apply(lambda x: aqi_fmt[x])

# Create data source column
aqi_long['source'] = 'Environmental Protection Agency'

# Create label column
aqi_long['lbl'] = aqi_long['value'].apply(lambda x: str(x))

# Reorder columns
aqi_long = aqi_long[["cat","GEOID","County","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

# Append to county column
aqi_long.to_csv('ShinyCIF/www/data/all_county.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

# Add measures to measure dictionary
measures = aqi_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')


# ----- Radon -------

# Filter radon to area we serve
radon = radon[[x in AWS for x in radon['state']]]

# Only keep the columns we want
radon = radon[["state", "county", "fips", "indoorRadonPotential"]]

# Create long data and rename columns
radon_long = pd.melt(radon, id_vars=['state', 'county', 'fips'], var_name='measure', value_name='value')
radon_long.columns = ['State', 'County', 'GEOID', 'measure', 'value']

# Create columns for category, race/ethnicity, and sex
radon_long['cat'] = 'Environment'
radon_long['RE'] = pd.NA
radon_long['Sex'] = pd.NA

# Create measure definitions column
radon_defs = json.load(open('setup/SHAPE/data/definitions/radon.json'))
radon_long['def'] = radon_long['measure'].apply(lambda x: radon_defs[x])

# Create format column
radon_fmt = json.load(open('setup/SHAPE/data/formats/radon.json'))
radon_long['fmt'] = radon_long['measure'].apply(lambda x: radon_fmt[x])

# Create data source column
radon_long['source'] = 'Environmental Protection Agency'

# Create label column
radon_long['lbl'] = radon_long['value'].apply(lambda x: str(x))

# Reorder columns
radon_long = radon_long[["cat","GEOID","County","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

# Append to county column
# radon_long.to_csv('ShinyCIF/www/data/all_county.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

# Add measures to measure dictionary
measures = radon_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
# measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')