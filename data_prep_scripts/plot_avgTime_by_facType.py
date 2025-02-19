import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np

def load_data(file_path):
    try:
        df = pd.read_csv(file_path)
        return df
    except Exception as e:
        print(f"Error loading input data: {e}")
        return None

def plot_avgTime_by_facType(df, title):
    plt.figure(figsize=(12, 6))
    sns.set_context('paper', font_scale=1.2)
    sns.set_style('whitegrid')
    
    # Count the number of facilities for each type
    facility_counts = df['Type'].value_counts().sort_index()
    
    # Create the boxplot
    ax = sns.boxplot(x='AvgDriveTime', y='Type', data=df, showmeans=True,
                     palette=sns.color_palette("husl", 3), 
                     meanprops={"marker": '*',
                                "markerfacecolor": "white", 
                                "markersize": "10", 
                                "markeredgecolor": "black"})
    
    plt.title(title, fontsize=20, fontweight='bold')
    plt.xlabel('Average Drive Time (minutes)', fontsize=16)
    plt.ylabel('Facility Type', fontsize=16)

    # Modify y-axis labels to include facility counts
    labels = [f"{label.get_text()}\n(n = {facility_counts[label.get_text()]})" for label in ax.get_yticklabels()]
    ax.set_yticklabels(labels)

    # Get the current handles and labels for the legend
    handles, legend_labels = ax.get_legend_handles_labels()
    
    # Create a custom handle for the mean marker
    from matplotlib.lines import Line2D
    mean_handle = Line2D([], [], marker='*', color='white', markerfacecolor='white', 
                         markersize=10, markeredgecolor='black', linestyle='None')
    
    # Add the mean handle to the existing handles
    handles.append(mean_handle)
    legend_labels.append('Mean')

    # Create the legend with all handles and labels
    ax.legend(handles=handles, labels=legend_labels, title='Legend', loc="upper right", fontsize=14, title_fontsize='15')

    plt.tight_layout()
    plt.show()


def main():
    # Load the facility load data
    facility_load_df = load_data('facility_load_v3.csv')
    
    # Check if the DataFrame is loaded correctly
    if facility_load_df is None:
        print("Failed to load the facility load data.")
        return
    
    # Create a new DataFrame with all facility types
    plot_df = facility_load_df[['Type', 'AvgDriveTime']]

    plot_df['Type'] = plot_df['Type'].replace({'Gastroenterology': 'Colonoscopy', 'Lung Cancer Screening': 'Lung Screening'})
    
    # Ensure we have data for all three facility types
    facility_types = ['Colonoscopy', 'Mammography', 'Lung Screening']
    plot_df = plot_df[plot_df['Type'].isin(facility_types)]
    
    # Plot the average time by facility type
    plot_avgTime_by_facType(plot_df, "Distribution of Average Drive Times to Cancer Screening Facilities")

if __name__ == "__main__":
    main()
