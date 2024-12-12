# %%

# Import packages

import sqlalchemy as sa
import pandas as pd
import csv
import json
import os

# Set Area we serve variables
AWS = ['Utah', 'Idaho', 'Wyoming', 'Montana', 'Nevada']
AWS_FIPS = ['16', '30', '32', '49', '56', 16, 30, 32, 49, 56]

# Set options
OPTIONS = {}
# OPTIONS['datasets'] = ['AQI', 'Radon', 'BRFSS', 'FCC']
OPTIONS['datasets'] = ['HINTS', 'BRFSS']

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

# Read Tract FIPS Table
tract_fips = pd.read_sql('select * from census.TractFips', conn)

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

# Read FCC tables
if 'FCC' in OPTIONS['datasets']:
    broadbandCounty = pd.read_sql('select * from fcc.BroadbandCountyDec2023', conn)
    broadbandTract = pd.read_sql('select * from fcc.BroadbandTractDec2023', conn)
    mobileCounty = pd.read_sql('select * from fcc.MobileCountyDec2023', conn)
    mobileTract = pd.read_sql('select * from fcc.MobileTractDec2023', conn)

# Read HINTS tables
if 'HINTS' in OPTIONS['datasets']:
    hints_cncr_com = pd.read_sql('select * from hints.CancerCommunication', conn)
    hints_cncr_percep = pd.read_sql('select * from hints.CancerPerceptions', conn)
    hints_crvcl_cncr = pd.read_sql('select * from hints.CervicalCancer', conn)
    hints_clin_trial = pd.read_sql('select * from hints.ClinicalTrials', conn)
    hints_lng_cncr = pd.read_sql('select * from hints.LungCancer', conn)
    hints_mntl_hlth = pd.read_sql('select * from hints.MentalHealth', conn)
    hints_skn_prot = pd.read_sql('select * from hints.SkinProtection', conn)
    hints_scl_det = pd.read_sql('select * from hints.SocialDeterminants', conn)
    hints_tbco = pd.read_sql('select * from hints.Tobacco', conn)


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


# ----- Tract FIPS -----
# This table is mostly for utility and won't be a part of the dataset directly

# Only keep the columns we want
tract_fips = tract_fips.drop('idTractFips', axis='columns')

# Create version for just our five states
aws_tract_fips = tract_fips[[x in AWS for x in tract_fips['state']]]

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

# %%

# ----- FCC -------

if 'FCC' in OPTIONS['datasets']:

    # --- Broadband County table ---

    # Filter to area we serve
    broadbandCounty = broadbandCounty[[x in AWS_FIPS for x in broadbandCounty['STATEID']]]

    # Fill in NAs for missing counties
    broadbandCounty = broadbandCounty.merge(aws_county_fips, how='outer', left_on='COUNTYID', right_on='fips')

    # Get month and year
    # Currently the tables only contain data for one month and year, so we are making that assumption here
    # If that ever changes, we would need to change this code
    month = broadbandCounty.at[0, 'MONTH']
    year = broadbandCounty.at[0, 'YEAR']

    # Only keep the columns we want
    broadbandCounty = broadbandCounty.drop(['RecordID', 'STATEID', 'COUNTYID', 'TOT_POP', 'MONTH', 'YEAR'], axis='columns')

    # Create long data and rename columns
    broadbandCounty_long = pd.melt(broadbandCounty, id_vars=['state', 'county', 'fips'], var_name='measure', value_name='value')
    broadbandCounty_long.columns = ['State', 'County', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    broadbandCounty_long['cat'] = 'Environment'
    broadbandCounty_long['RE'] = pd.NA
    broadbandCounty_long['Sex'] = pd.NA

    # Create measure definitions column
    fcc_defs = json.load(open('setup/SHAPE/data/definitions/fcc.json'))
    broadbandCounty_long['def'] = broadbandCounty_long['measure'].apply(lambda x: fcc_defs[x])

    # Create format column
    fcc_fmt = json.load(open('setup/SHAPE/data/formats/fcc.json'))
    broadbandCounty_long['fmt'] = broadbandCounty_long['measure'].apply(lambda x: fcc_fmt[x])

    # Create data source column
    broadbandCounty_long['source'] = f'FCC, {month} {year}'

    # Create label column
    broadbandCounty_long['lbl'] = broadbandCounty_long['value'].apply(lambda x: f'{x:.1f}')

    # Reorder columns
    broadbandCounty_long = broadbandCounty_long[["cat","GEOID","County","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    broadbandCounty_long.to_csv('ShinyCIF/www/data/all_county.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = broadbandCounty_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Broadband Tract table ---

    # Filter to area we serve
    broadbandTract = broadbandTract[[x in AWS_FIPS for x in broadbandTract['STATEID']]]

    # Fill in NAs for missing tracts
    broadbandTract = broadbandTract.merge(aws_tract_fips, how='outer', left_on='TRACTID', right_on='fips')

    # Get month and year
    # Currently the tables only contain data for one month and year, so we are making that assumption here
    # If that ever changes, we would need to change this code
    month = broadbandTract.at[0, 'MONTH']
    year = broadbandTract.at[0, 'YEAR']

    # Only keep the columns we want
    broadbandTract = broadbandTract.drop(['RecordID', 'STATEID', 'TRACTID', 'TOT_POP', 'MONTH', 'YEAR'], axis='columns')

    # Create long data and rename columns
    broadbandTract_long = pd.melt(broadbandTract, id_vars=['state', 'county', 'tract', 'fips'], var_name='measure', value_name='value')
    broadbandTract_long.columns = ['State', 'County', 'Tract', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    broadbandTract_long['cat'] = 'Environment'
    broadbandTract_long['RE'] = pd.NA
    broadbandTract_long['Sex'] = pd.NA

    # Create measure definitions column
    broadbandTract_long['def'] = broadbandTract_long['measure'].apply(lambda x: fcc_defs[x])

    # Create format column
    broadbandTract_long['fmt'] = broadbandTract_long['measure'].apply(lambda x: fcc_fmt[x])

    # Create data source column
    broadbandTract_long['source'] = f'FCC, {month} {year}'

    # Create label column
    broadbandTract_long['lbl'] = broadbandTract_long['value'].apply(lambda x: f'{x:.1f}')

    # Reorder columns
    broadbandTract_long = broadbandTract_long[["cat","GEOID","Tract","County","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    broadbandTract_long.to_csv('ShinyCIF/www/data/all_tract.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Measures are the same as county, so they are already in the measure dictionary

    # %%

    # --- Mobile County table ---

    # Filter to area we serve
    mobileCounty = mobileCounty[[x in AWS_FIPS for x in mobileCounty['STATEID']]]

    # Fill in NAs for missing counties
    mobileCounty = mobileCounty.merge(aws_county_fips, how='outer', left_on='COUNTYID', right_on='fips')

    # Get month and year
    # Currently the tables only contain data for one month and year, so we are making that assumption here
    # If that ever changes, we would need to change this code
    month = mobileCounty.at[0, 'MONTH']
    year = mobileCounty.at[0, 'YEAR']

    # Only keep the columns we want
    mobileCounty = mobileCounty.drop(['RecordID', 'STATEID', 'COUNTYID', 'TOT_POP', 'MONTH', 'YEAR'], axis='columns')

    # Create long data and rename columns
    mobileCounty_long = pd.melt(mobileCounty, id_vars=['state', 'county', 'fips'], var_name='measure', value_name='value')
    mobileCounty_long.columns = ['State', 'County', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    mobileCounty_long['cat'] = 'Environment'
    mobileCounty_long['RE'] = pd.NA
    mobileCounty_long['Sex'] = pd.NA

    # Create measure definitions column
    mobileCounty_long['def'] = mobileCounty_long['measure'].apply(lambda x: fcc_defs[x])

    # Create format column
    mobileCounty_long['fmt'] = mobileCounty_long['measure'].apply(lambda x: fcc_fmt[x])

    # Create data source column
    mobileCounty_long['source'] = f'FCC, {month} {year}'

    # Create label column
    mobileCounty_long['lbl'] = mobileCounty_long['value'].apply(lambda x: f'{x:.1f}')

    # Reorder columns
    mobileCounty_long = mobileCounty_long[["cat","GEOID","County","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    mobileCounty_long.to_csv('ShinyCIF/www/data/all_county.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = mobileCounty_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Mobile Tract table ---

    # Filter to area we serve
    mobileTract = mobileTract[[x in AWS_FIPS for x in mobileTract['STATEID']]]

    # Fill in NAs for missing tracts
    mobileTract = mobileTract.merge(aws_tract_fips, how='outer', left_on='TRACTID', right_on='fips')

    # Get month and year
    # Currently the tables only contain data for one month and year, so we are making that assumption here
    # If that ever changes, we would need to change this code
    month = mobileTract.at[0, 'MONTH']
    year = mobileTract.at[0, 'YEAR']

    # Only keep the columns we want
    mobileTract = mobileTract.drop(['RecordID', 'STATEID', 'TRACTID', 'TOT_POP', 'MONTH', 'YEAR'], axis='columns')

    # Create long data and rename columns
    mobileTract_long = pd.melt(mobileTract, id_vars=['state', 'county', 'tract', 'fips'], var_name='measure', value_name='value')
    mobileTract_long.columns = ['State', 'County', 'Tract', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    mobileTract_long['cat'] = 'Environment'
    mobileTract_long['RE'] = pd.NA
    mobileTract_long['Sex'] = pd.NA

    # Create measure definitions column
    mobileTract_long['def'] = mobileTract_long['measure'].apply(lambda x: fcc_defs[x])

    # Create format column
    mobileTract_long['fmt'] = mobileTract_long['measure'].apply(lambda x: fcc_fmt[x])

    # Create data source column
    mobileTract_long['source'] = f'FCC, {month} {year}'

    # Create label column
    mobileTract_long['lbl'] = mobileTract_long['value'].apply(lambda x: f'{x:.1f}')

    # Reorder columns
    mobileTract_long = mobileTract_long[["cat","GEOID","Tract","County","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    mobileTract_long.to_csv('ShinyCIF/www/data/all_tract.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Measures are the same as county, so they are already in the measure dictionary

# %%

# ----- HINTS -----

if 'HINTS' in OPTIONS['datasets']:

    # --- Cancer Communication table ---

    # Filter to area we serve
    hints_cncr_com = hints_cncr_com[[x in AWS for x in hints_cncr_com['state']]]

    # Add FIPS
    hints_cncr_com = hints_cncr_com.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_cncr_com = hints_cncr_com.drop(['idCancerCommunication', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_cncr_com_long = pd.melt(hints_cncr_com, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_cncr_com_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_cncr_com_long['cat'] = 'Cancer Communication & Perceptions'
    hints_cncr_com_long['RE'] = pd.NA
    hints_cncr_com_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_defs = json.load(open('setup/SHAPE/data/definitions/hints.json'))
    hints_cncr_com_long['def'] = hints_cncr_com_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_fmt = json.load(open('setup/SHAPE/data/formats/hints.json'))
    hints_cncr_com_long['fmt'] = hints_cncr_com_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_cncr_com_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_cncr_com_long['lbl'] = hints_cncr_com_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_cncr_com_long = hints_cncr_com_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_cncr_com_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_cncr_com_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Cancer Perceptions table ---

    # Filter to area we serve
    hints_cncr_percep = hints_cncr_percep[[x in AWS for x in hints_cncr_percep['state']]]

    # Add FIPS
    hints_cncr_percep = hints_cncr_percep.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_cncr_percep = hints_cncr_percep.drop(['idCancerPerceptions', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_cncr_percep_long = pd.melt(hints_cncr_percep, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_cncr_percep_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_cncr_percep_long['cat'] = 'Cancer Communication & Perceptions'
    hints_cncr_percep_long['RE'] = pd.NA
    hints_cncr_percep_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_cncr_percep_long['def'] = hints_cncr_percep_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_cncr_percep_long['fmt'] = hints_cncr_percep_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_cncr_percep_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_cncr_percep_long['lbl'] = hints_cncr_percep_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_cncr_percep_long = hints_cncr_percep_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_cncr_percep_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_cncr_percep_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Cervical Cancer table ---

    # Filter to area we serve
    hints_crvcl_cncr = hints_crvcl_cncr[[x in AWS for x in hints_crvcl_cncr['state']]]

    # Add FIPS
    hints_crvcl_cncr = hints_crvcl_cncr.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_crvcl_cncr = hints_crvcl_cncr.drop(['idCervicalCancer', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_crvcl_cncr_long = pd.melt(hints_crvcl_cncr, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_crvcl_cncr_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_crvcl_cncr_long['cat'] = 'Screening & Risk Factors'
    hints_crvcl_cncr_long['RE'] = pd.NA
    hints_crvcl_cncr_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_crvcl_cncr_long['def'] = hints_crvcl_cncr_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_crvcl_cncr_long['fmt'] = hints_crvcl_cncr_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_crvcl_cncr_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_crvcl_cncr_long['lbl'] = hints_crvcl_cncr_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_crvcl_cncr_long = hints_crvcl_cncr_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_crvcl_cncr_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_crvcl_cncr_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Clinical Trials table ---

    # Filter to area we serve
    hints_clin_trial = hints_clin_trial[[x in AWS for x in hints_clin_trial['state']]]

    # Add FIPS
    hints_clin_trial = hints_clin_trial.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_clin_trial = hints_clin_trial.drop(['idClinicalTrials', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_clin_trial_long = pd.melt(hints_clin_trial, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_clin_trial_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_clin_trial_long['cat'] = 'Clinical Trials'
    hints_clin_trial_long['RE'] = pd.NA
    hints_clin_trial_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_clin_trial_long['def'] = hints_clin_trial_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_clin_trial_long['fmt'] = hints_clin_trial_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_clin_trial_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_clin_trial_long['lbl'] = hints_clin_trial_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_clin_trial_long = hints_clin_trial_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_clin_trial_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_clin_trial_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Lung Cancer table ---

    # Filter to area we serve
    hints_lng_cncr = hints_lng_cncr[[x in AWS for x in hints_lng_cncr['state']]]

    # Add FIPS
    hints_lng_cncr = hints_lng_cncr.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_lng_cncr = hints_lng_cncr.drop(['idLungCancer', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_lng_cncr_long = pd.melt(hints_lng_cncr, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_lng_cncr_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_lng_cncr_long['cat'] = 'Screening & Risk Factors'
    hints_lng_cncr_long['RE'] = pd.NA
    hints_lng_cncr_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_lng_cncr_long['def'] = hints_lng_cncr_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_lng_cncr_long['fmt'] = hints_lng_cncr_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_lng_cncr_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_lng_cncr_long['lbl'] = hints_lng_cncr_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_lng_cncr_long = hints_lng_cncr_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_lng_cncr_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_lng_cncr_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Mental Health table ---

    # Filter to area we serve
    hints_mntl_hlth = hints_mntl_hlth[[x in AWS for x in hints_mntl_hlth['state']]]

    # Add FIPS
    hints_mntl_hlth = hints_mntl_hlth.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_mntl_hlth = hints_mntl_hlth.drop(['idMentalHealth', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_mntl_hlth_long = pd.melt(hints_mntl_hlth, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_mntl_hlth_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_mntl_hlth_long['cat'] = 'Other Health Factors'
    hints_mntl_hlth_long['RE'] = pd.NA
    hints_mntl_hlth_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_mntl_hlth_long['def'] = hints_mntl_hlth_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_mntl_hlth_long['fmt'] = hints_mntl_hlth_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_mntl_hlth_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_mntl_hlth_long['lbl'] = hints_mntl_hlth_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_mntl_hlth_long = hints_mntl_hlth_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_mntl_hlth_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_mntl_hlth_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Skin Protection table ---

    # Filter to area we serve
    hints_skn_prot = hints_skn_prot[[x in AWS for x in hints_skn_prot['state']]]

    # Add FIPS
    hints_skn_prot = hints_skn_prot.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_skn_prot = hints_skn_prot.drop(['idSkinProtection', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_skn_prot_long = pd.melt(hints_skn_prot, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_skn_prot_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_skn_prot_long['cat'] = 'Screening & Risk Factors'
    hints_skn_prot_long['RE'] = pd.NA
    hints_skn_prot_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_skn_prot_long['def'] = hints_skn_prot_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_skn_prot_long['fmt'] = hints_skn_prot_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_skn_prot_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_skn_prot_long['lbl'] = hints_skn_prot_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_skn_prot_long = hints_skn_prot_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_skn_prot_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_skn_prot_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Social Determinants table ---

    # Filter to area we serve
    hints_scl_det = hints_scl_det[[x in AWS for x in hints_scl_det['state']]]

    # Add FIPS
    hints_scl_det = hints_scl_det.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_scl_det = hints_scl_det.drop(['idSocialDeterminants', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_scl_det_long = pd.melt(hints_scl_det, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_scl_det_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_scl_det_long['cat'] = 'Sociodemographics'
    hints_scl_det_long['RE'] = pd.NA
    hints_scl_det_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_scl_det_long['def'] = hints_scl_det_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_scl_det_long['fmt'] = hints_scl_det_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_scl_det_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_scl_det_long['lbl'] = hints_scl_det_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_scl_det_long = hints_scl_det_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_scl_det_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_scl_det_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')

    # %%

    # --- Tobacco table ---

    # Filter to area we serve
    hints_tbco = hints_tbco[[x in AWS for x in hints_tbco['state']]]

    # Add FIPS
    hints_tbco = hints_tbco.merge(aws_state_fips, how='outer', on='state')

    # Only keep the columns we want
    hints_tbco = hints_tbco.drop(['idTobacco', 'stateAbbreviation'], axis='columns')

    # Create long data and rename columns
    hints_tbco_long = pd.melt(hints_tbco, id_vars=['state', 'fips'], var_name='measure', value_name='value')
    hints_tbco_long.columns = ['State', 'GEOID', 'measure', 'value']

    # Create columns for category, race/ethnicity, and sex
    hints_tbco_long['cat'] = 'Screening & Risk Factors'
    hints_tbco_long['RE'] = pd.NA
    hints_tbco_long['Sex'] = pd.NA

    # Create measure definitions column
    hints_tbco_long['def'] = hints_tbco_long['measure'].apply(lambda x: hints_defs[x])

    # Create format column
    hints_tbco_long['fmt'] = hints_tbco_long['measure'].apply(lambda x: hints_fmt[x])

    # Create data source column
    hints_tbco_long['source'] = 'Health Information National Trends Survey'

    # Create label column
    hints_tbco_long['lbl'] = hints_tbco_long['value'].apply(lambda x: f'{x * 100:.1f}%' if not pd.isna(x) else x)

    # Reorder columns
    hints_tbco_long = hints_tbco_long[["cat","GEOID","State","measure","value","RE","Sex","def","fmt","source","lbl"]]

    # Append to county column
    hints_tbco_long.to_csv('ShinyCIF/www/data/all_state.csv', index=False, quoting=csv.QUOTE_NONNUMERIC, na_rep="NA", header=False, mode='a')

    # Add measures to measure dictionary
    measures = hints_tbco_long[['measure', 'def', 'fmt', 'source']].drop_duplicates()
    # measures.to_csv('ShinyCIF/www/measure_dictionary_v5.csv', index=False, na_rep="NA", header=False, mode='a')
