import pandas as pd
from csv import QUOTE_NONNUMERIC

fl_comp = "/Users/jonathanroylance/Downloads/facility_load_comprehensive.csv"
all_tracts = '/Users/jonathanroylance/CS_Projects/BIO465/CancerInFocus/CancerInFocusExt/ShinyCIF-Clark/www/data/all_tract.csv'

df = pd.read_csv(fl_comp)
df['CountyTract'] = df['CountyTract'].astype(str).str[1:]
df['CountyTract'] = df['CountyTract'].astype(int)
df.rename(columns={'CountyTract' : 'GEOID'}, inplace=True)

df_t = pd.read_csv(all_tracts)
df_t = df_t[['GEOID', 'Tract', 'County']].drop_duplicates()

df_t = df_t.groupby(['GEOID', 'County']).agg({'Tract': lambda x: min(x, key=len)}).reset_index()

df = df.merge(df_t, on='GEOID', how='left')
df.drop(columns=['miles'], inplace=True)
df.rename(columns={'minutes' : 'value'}, inplace=True)

df['lbl'] = df['value'].round().astype(int).astype(str)
df['measure'] = 'Minutes'
df['fmt'] = 'float64'
df['def'] = 'Minutes Driven'

new_order =['GEOID', 'Tract', 'County', 'State', 'FacID', 'FacType', 'measure', 'value', 'def', 'fmt', 'lbl']
df = df[new_order]
df.rename(columns={'FacType' : 'cat'}, inplace=True)

df.to_csv('/Users/jonathanroylance/CS_Projects/BIO465/CancerInFocus/CancerInFocusExt/ShinyCIF-Clark/www/data/tract_min_FORAPP.csv', 
          index=False,
          quoting=QUOTE_NONNUMERIC)