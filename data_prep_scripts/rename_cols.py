import pandas as pd

file_path = '/Users/jonathanroylance/CS_Projects/BIO465/CancerInFocus/CancerInFocusExt/ShinyCIF-Clark/www/data/tract_min_FORAPP.csv'

df = pd.read_csv(file_path)

df.rename(columns={'FacType' : 'cat'}, inplace=True)

df.to_csv(file_path)