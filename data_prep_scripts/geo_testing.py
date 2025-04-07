import geopandas as gpd

file_path = "ShinyCIF-Clark/www/shapefiles/tract_sf.shp"

gdf = gpd.read_file(filename=file_path)

merged = gdf.union_all()

# Convert back to a GeoDataFrame
merged_gdf = gpd.GeoDataFrame({"ID": [16001000101]}, geometry=[merged], crs=gdf.crs)

# print(merged_gdf)
# print(merged_gdf.crs)
# Save the new single boundary shapefile
merged_gdf.to_file("merged_boundary.shp")

mf = gpd.read_file("merged_boundary.shp")

print(mf)
