import os
import subprocess
import pandas as pd

# This script assumes that the "...toFacilities_v2.xlsx" and "_Final_facilities_v2.csv" files
# are in a "Travel Time" directory; a directory which is in the same working directory as this
# script.

tt_dir = 'Travel Time'
tt_c_dir = 'TravelTimeConverted'

if not os.path.isdir(tt_c_dir):
    os.makedirs(tt_c_dir)

tt_files = [f for f in os.listdir(tt_dir) if ".xlsx" == f[-5:]]

facs = pd.read_csv('Travel Time/_Final_facilities_v2.csv')
fac_types = set(facs['Type'].to_list())

for f in tt_files:
    print(f'Processing {f} ...')
    df = pd.read_excel(f'Travel Time/{f}')
    df_to_write = pd.DataFrame(columns=["CountyTract", "FacID", "FacType", "minutes", "miles"])

    for row in df.itertuples():

        fac_id = row[2]
        ct = row[1]
        fac = facs[facs['FacID'] == fac_id]
        fac_type = fac.iloc[0]['Type']
        tt_min = row[4]
        tot_miles = row[5]

        df_temp = df_to_write[(df_to_write['CountyTract'] == ct) & (df_to_write['FacType'] == fac_type)]
        if len(df_temp) == 0:
            new_row = {"CountyTract":ct, "FacID":fac_id, "FacType":fac_type, "minutes":tt_min, "miles":tot_miles}

            pd.concat([df_to_write, pd.DataFrame([new_row])], ignore_index=True)
    processed_filename = f'{tt_c_dir}/{f[:-5]}.csv'
    print(f'Finished processing {f}.')
    
    df_to_write.to_csv(processed_filename)


