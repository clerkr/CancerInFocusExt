# %%

# Import packages

import sqlalchemy as sa
import pandas as pd
import csv
import json
import os

# Set Area we serve variable
AWS = ['Utah', 'Idaho', 'Wyoming', 'Montana', 'Nevada']

# Set options
OPTIONS = {}
# OPTIONS['datasets'] = ['AQI', 'Radon', 'BRFSS']
OPTIONS['datasets'] = ['BRFSS']

# %%

# Make sure SQL login is configured
try:
    login = json.load(open('setup/SHAPE/data/sql_login.json'))
except:
    raise Exception('Use sql_login_template.json to fill in the login information for sql server then change the name to sql_login.json')
    # If you don't know the SQL server login, ask the RISR contact. Right now, it's Douglas Canada

# %%

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


# %%

# Read State FIPS Table
state_fips = pd.read_sql('select * from census.StateFips', conn)

# Read County FIPS Table
county_fips = pd.read_sql('select * from census.CountyFips', conn)

# Read AQI table
if 'AQI' in OPTIONS['datasets']:
    aqi = pd.read_sql('select * from epa.Aqi', conn)

# Read Radon table
if 'Radon' in OPTIONS['datasets']:
    radon = pd.read_sql('select * from epa.Radon', conn)

# Read BRFSS tables
if 'BRFSS' in OPTIONS['datasets']:
    brfss_brst_crvcl_scrn = pd.read_sql('select * from brfss.BreastAndCervicalCancerScreening', conn)
    brfss_cncr_insr = pd.read_sql('select * from brfss.CancerInsurance', conn)
    brfss_crc_scrn = pd.read_sql('select * from brfss.ColorectalCancerScreening', conn)
    brfss_hlth_care_acs = pd.read_sql('select * from brfss.HealthCareAccess', conn)
    brfss_lng_scrn = pd.read_sql('select * from brfss.LungCancerScreening', conn)
    brfss_mntl_hlth = pd.read_sql('select * from brfss.MentalHealth', conn)
    brfss_scl_det = pd.read_sql('select * from brfss.SocialDeterminants', conn)
    brfss_tbco = pd.read_sql('select * from brfss.Tobacco', conn)

# Close the connection
conn.close()

# %%

# ----- State FIPS -----
# This table is mostly for utility and won't be a part of the dataset directly

# Only keep the columns we want
state_fips = state_fips.drop('idStateFips', axis='columns')

# Create version for just our five states
aws_state_fips = state_fips[[x in AWS for x in state_fips['state']]]


# ----- County FIPS -----
# This table is mostly for utility and won't be a part of the dataset directly

# Only keep the columns we want
county_fips = county_fips.drop('idCountyFips', axis='columns')

# Create version for just our five states
aws_county_fips = county_fips[[x in AWS for x in county_fips['state']]]

# %%

# ----- AQI -------

if 'AQI' in OPTIONS['datasets']:

    # Filter aqi to area we serve
    aqi = aqi[[x in AWS for x in aqi['state']]]

    # Fill in NAs for missing counties
    aqi = aqi.merge(aws_county_fips, how='outer', left_on='fips', right_on='fips')

    # Only keep the columns we want
    aqi = aqi.drop(['idAqi', 'state_x', 'county_x'], axis='columns')

    # Create long data and rename columns
    aqi_long = pd.melt(aqi, id_vars=['state_y', 'county_y', 'fips'], var_name='measure', value_name='value')
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


# %%

# ----- Radon -------

if 'Radon' in OPTIONS['datasets']:

    # Filter radon to area we serve
    radon = radon[[x in AWS for x in radon['state']]]

    # Fill in NAs for missing counties
    radon = radon.merge(aws_county_fips, how='outer', left_on='fips', right_on='fips')

    # Only keep the columns we want
    radon = radon[["state_y", "county_y", "fips", "indoorRadonPotential"]]

    # Create long data and rename columns
    radon_long = pd.melt(radon, id_vars=['state_y', 'county_y', 'fips'], var_name='measure', value_name='value')
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
    radon_long.to_csv('ShinyCIF/www/data/all_county.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = radon_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')


# %%

# ----- BRFSS -----

if 'BRFSS' in OPTIONS['datasets']:

    # --- Breast and Cervical Cancer Screening table ---

    # Filter to area we serve
    brfss_brst_crvcl_scrn = brfss_brst_crvcl_scrn[[x in AWS for x in brfss_brst_crvcl_scrn['state']]]

    # Add FIPS
    brfss_brst_crvcl_scrn = brfss_brst_crvcl_scrn.merge(aws_state_fips, how='outer', on='state')

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
    brfss_brst_crvcl_scrn_long['lbl'] = brfss_brst_crvcl_scrn_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_brst_crvcl_scrn_long = brfss_brst_crvcl_scrn_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_brst_crvcl_scrn_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA")

    # Add measures to measure dictionary
    measures = brfss_brst_crvcl_scrn_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Cancer Insurance table ---

    # Filter to area we serve
    brfss_cncr_insr = brfss_cncr_insr[[x in AWS for x in brfss_cncr_insr['state']]]

    # Add FIPS
    brfss_cncr_insr = brfss_cncr_insr.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_cncr_insr = brfss_cncr_insr.drop(['idCancerInsurance', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_cncr_insr_long = pd.melt(brfss_cncr_insr, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_cncr_insr_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_cncr_insr_long['cat'] = 'Economics & Insurance'
    brfss_cncr_insr_long['RE'] = pd.NA
    brfss_cncr_insr_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_cncr_insr_long['def'] = brfss_cncr_insr_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_cncr_insr_long['fmt'] = brfss_cncr_insr_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_cncr_insr_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_cncr_insr_long['lbl'] = brfss_cncr_insr_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_cncr_insr_long = brfss_cncr_insr_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_cncr_insr_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_cncr_insr_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Colorectal Cancer Screening table ---

    # Filter to area we serve
    brfss_crc_scrn = brfss_crc_scrn[[x in AWS for x in brfss_crc_scrn['state']]]

    # Add FIPS
    brfss_crc_scrn = brfss_crc_scrn.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_crc_scrn = brfss_crc_scrn.drop(['idColorectalCancerScreening', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_crc_scrn_long = pd.melt(brfss_crc_scrn, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_crc_scrn_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_crc_scrn_long['cat'] = 'Screening & Risk Factors'
    brfss_crc_scrn_long['RE'] = pd.NA
    brfss_crc_scrn_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_crc_scrn_long['def'] = brfss_crc_scrn_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_crc_scrn_long['fmt'] = brfss_crc_scrn_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_crc_scrn_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_crc_scrn_long['lbl'] = brfss_crc_scrn_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_crc_scrn_long = brfss_crc_scrn_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_crc_scrn_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_crc_scrn_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Health Care Access table ---

    # Filter to area we serve
    brfss_hlth_care_acs = brfss_hlth_care_acs[[x in AWS for x in brfss_hlth_care_acs['state']]]

    # Add FIPS
    brfss_hlth_care_acs = brfss_hlth_care_acs.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_hlth_care_acs = brfss_hlth_care_acs.drop(['idHealthCareAccess', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_hlth_care_acs_long = pd.melt(brfss_hlth_care_acs, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_hlth_care_acs_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_hlth_care_acs_long['cat'] = 'Sociodemographics'
    brfss_hlth_care_acs_long['RE'] = pd.NA
    brfss_hlth_care_acs_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_hlth_care_acs_long['def'] = brfss_hlth_care_acs_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_hlth_care_acs_long['fmt'] = brfss_hlth_care_acs_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_hlth_care_acs_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_hlth_care_acs_long['lbl'] = brfss_hlth_care_acs_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_hlth_care_acs_long = brfss_hlth_care_acs_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_hlth_care_acs_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_hlth_care_acs_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Lung Cancer Screening table ---

    # Filter to area we serve
    brfss_lng_scrn = brfss_lng_scrn[[x in AWS for x in brfss_lng_scrn['state']]]

    # Add FIPS
    brfss_lng_scrn = brfss_lng_scrn.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_lng_scrn = brfss_lng_scrn.drop(['idLungCancerScreening', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_lng_scrn_long = pd.melt(brfss_lng_scrn, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_lng_scrn_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_lng_scrn_long['cat'] = 'Screening & Risk Factors'
    brfss_lng_scrn_long['RE'] = pd.NA
    brfss_lng_scrn_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_lng_scrn_long['def'] = brfss_lng_scrn_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_lng_scrn_long['fmt'] = brfss_lng_scrn_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_lng_scrn_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_lng_scrn_long['lbl'] = brfss_lng_scrn_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_lng_scrn_long = brfss_lng_scrn_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_lng_scrn_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_lng_scrn_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Mental Health table ---

    # Filter to area we serve
    brfss_mntl_hlth = brfss_mntl_hlth[[x in AWS for x in brfss_mntl_hlth['state']]]

    # Add FIPS
    brfss_mntl_hlth = brfss_mntl_hlth.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_mntl_hlth = brfss_mntl_hlth.drop(['idMentalHealth', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_mntl_hlth_long = pd.melt(brfss_mntl_hlth, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_mntl_hlth_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_mntl_hlth_long['cat'] = 'Other Health Factors'
    brfss_mntl_hlth_long['RE'] = pd.NA
    brfss_mntl_hlth_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_mntl_hlth_long['def'] = brfss_mntl_hlth_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_mntl_hlth_long['fmt'] = brfss_mntl_hlth_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_mntl_hlth_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_mntl_hlth_long['lbl'] = brfss_mntl_hlth_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_mntl_hlth_long = brfss_mntl_hlth_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_mntl_hlth_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_mntl_hlth_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Social Determinants table ---

    # Filter to area we serve
    brfss_scl_det = brfss_scl_det[[x in AWS for x in brfss_scl_det['state']]]

    # Add FIPS
    brfss_scl_det = brfss_scl_det.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_scl_det = brfss_scl_det.drop(['idSocialDeterminants', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_scl_det_long = pd.melt(brfss_scl_det, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_scl_det_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_scl_det_long['cat'] = 'Sociodemographics'
    brfss_scl_det_long['RE'] = pd.NA
    brfss_scl_det_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_scl_det_long['def'] = brfss_scl_det_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_scl_det_long['fmt'] = brfss_scl_det_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_scl_det_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_scl_det_long['lbl'] = brfss_scl_det_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_scl_det_long = brfss_scl_det_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_scl_det_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_scl_det_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Tobacco table ---

    # Filter to area we serve
    brfss_tbco = brfss_tbco[[x in AWS for x in brfss_tbco['state']]]

    # Add FIPS
    brfss_tbco = brfss_tbco.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    brfss_tbco = brfss_tbco.drop(['idTobacco', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    brfss_tbco_long = pd.melt(brfss_tbco, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    brfss_tbco_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    brfss_tbco_long['cat'] = 'Screening & Risk Factors'
    brfss_tbco_long['RE'] = pd.NA
    brfss_tbco_long['Sex'] = pd.NA

    # Create measure definitions column
    brfss_tbco_long['def'] = brfss_tbco_long['measure'].apply(lambda x: brfss_defs[x])

    # Create format column
    brfss_tbco_long['fmt'] = brfss_tbco_long['measure'].apply(lambda x: brfss_fmt[x])

    # Create data source column
    brfss_tbco_long['source'] = 'Behavioral Risk Factor Surveillance System'

    # Create label column
    brfss_tbco_long['lbl'] = brfss_tbco_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    brfss_tbco_long = brfss_tbco_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    brfss_tbco_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = brfss_tbco_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')