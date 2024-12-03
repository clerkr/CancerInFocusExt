
# Import packages

import sqlalchemy as sa
import pandas as pd
import csv
import json
import os

# Set Area we serve variable
AWS = ['Utah', 'Idaho', 'Wyoming', 'Montana', 'Nevada']

try:
    login = json.load(open('setup/SHAPE/data/sql_login.json'))
except:
    raise Exception('Use sql_login_template.json to fill in the login information for sql server then change the name to sql_login.json')
    # If you don't know the SQL server login, ask the RISR contact. Right now, it's Douglas Canada

# Setup connection to SHAPE
connection_url = sa.engine.URL.create(
    "mssql+pyodbc",
    username=login['username'],
    password=login['password'],
    host=login['host'],
    database="SHAPE",
    query={'driver': 'ODBC Driver 18 for SQL Server', 'TrustServerCertificate': 'yes'}
)
engine = sa.create_engine(connection_url)
conn = engine.connect()

# Read State FIPS Table
state_fips = pd.read_sql('select * from census.StateFips', conn)

# Read AQI table
aqi = pd.read_sql('select * from epa.Aqi', conn)

# Read Radon table
radon = pd.read_sql('select * from epa.Radon', conn)

# Read BRFSS tables
brfss_brst_crvcl_scrn = pd.read_sql('select * from brfss.BreastAndCervicalCancerScreening', conn)

# Close the connection
conn.close()


# ----- State FIPS -----
# This table is mostly for utility and won't be a part of the dataset directly

# Only keep the columns we want
state_fips = state_fips.drop('idStateFips', axis='columns')


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
# aqi_long.to_csv('ShinyCIF/www/data/all_county.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

# Add measures to measure dictionary
measures = aqi_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
# measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')


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


# ----- BRFSS -----

# Filter brfss to area we serve
brfss_brst_crvcl_scrn = brfss_brst_crvcl_scrn[[x in AWS for x in brfss_brst_crvcl_scrn['state']]]

# Add FIPS
brfss_brst_crvcl_scrn = brfss_brst_crvcl_scrn.merge(state_fips, how='left', on='state')

# Only keep the columns we want
brfss_brst_crvcl_scrn = brfss_brst_crvcl_scrn.drop(['idBreastAndCervicalCancerScreening', 'stateAbbreviation'], axis='columns')

# Create long data and rename columns
brfss_brst_crvcl_scrn_long = pd.melt(brfss_brst_crvcl_scrn, id_vars=['state', 'fips'], var_name='measure', value_name='value')
brfss_brst_crvcl_scrn_long.columns = ['State', 'GEOID', 'measure', 'value']

# Create columns for category, race/ethnicity, and sex
brfss_brst_crvcl_scrn_long['cat'] = 'Screening & Risk Factors'
brfss_brst_crvcl_scrn_long['RE'] = pd.NA
brfss_brst_crvcl_scrn_long['Sex'] = pd.NA

# Create measure definitions column
brfss_defs = json.load(open('setup/SHAPE/data/definitions/brfss.json'))
brfss_brst_crvcl_scrn_long['def'] = brfss_brst_crvcl_scrn_long['measure'].apply(lambda x: brfss_defs[x])

# Create format column
brfss_fmt = json.load(open('setup/SHAPE/data/formats/brfss.json'))
brfss_brst_crvcl_scrn_long['fmt'] = brfss_brst_crvcl_scrn_long['measure'].apply(lambda x: brfss_fmt[x])

# Create data source column
brfss_brst_crvcl_scrn_long['source'] = 'Behavioral Risk Factor Surveillance System'

# Create label column
brfss_brst_crvcl_scrn_long['lbl'] = brfss_brst_crvcl_scrn_long['value'].apply(lambda x: str(x))

# Reorder columns
brfss_brst_crvcl_scrn_long = brfss_brst_crvcl_scrn_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

# Append to county column
brfss_brst_crvcl_scrn_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA")

# Add measures to measure dictionary
measures = brfss_brst_crvcl_scrn_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')