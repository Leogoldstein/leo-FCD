import os
import glob
from tkinter import Tk, filedialog
import tkinter as tk

def process_folders(data_paths):
    """
    Process each folder path to find and verify the existence of required subfolders and files.
    
    Args:
    data_paths (list): List of folder paths to be processed.

    Returns:
    tuple: Contains lists of valid paths, stat paths, ops paths, and iscell paths.
    """
    final_data_path = []

    for path in data_paths:
        # Check if the selected folder contains 'plane' or 'suite2p'
        if 'plane' not in path and 'suite2p' not in path:
            # Check if the selected folder contains 'TSeries'
            if 'TSeries' not in path:
                tseries_folder = os.path.join(path, 'TSeries')
                if os.path.isdir(tseries_folder):
                    path = tseries_folder
                else:
                    tseries_folders = glob.glob(os.path.join(path, 'TSeries*'))
                    tseries_folders = [f for f in tseries_folders if os.path.isdir(f)]
                    
                    if len(tseries_folders) == 1:
                        path = tseries_folders[0]
                    elif len(tseries_folders) > 1:
                        root = Tk()
                        root.withdraw()  # Hide the root window
                        root.attributes('-topmost', True)  # Bring the dialog to the front
                        path = filedialog.askdirectory(initialdir=path, title=f'Select a TSeries folder within {path}')
                        root.destroy()  # Destroy the root window after selection
                        
                        # Check if the user canceled the selection
                        if not path:
                            print('User clicked Cancel. Exiting.')
                            continue
                    else:
                        print(f"No 'TSeries' folder found in '{path}'. Excluding this folder.")
                        continue

            # Check if 'suite2p' subfolder exists
            suite2p_folder = os.path.join(path, 'suite2p')
            if not os.path.isdir(suite2p_folder):
                print(f"Skipping {path}: No 'suite2p' subfolder found.")
                continue

            # List 'plane' folders in suite2pFolder
            plane_folders = [d for d in os.listdir(suite2p_folder) if d.startswith('plane') and os.path.isdir(os.path.join(suite2p_folder, d))]

            if len(plane_folders) == 0:
                print(f"Skipping {suite2p_folder}: No 'plane' folder found.")
                continue
                
            elif len(plane_folders) > 1:
                root = tk.Tk()
                root.withdraw()  # Hide the main window
                path = filedialog.askdirectory(initialdir=suite2p_folder, title=f'Select a plane folder within {suite2p_folder}')
                root.destroy()  # Destroy the root window after selection
                
                # Check if the user canceled the selection
                if not path:
                    print('User clicked Cancel. Exiting.')
                    continue
            else:
                path = os.path.join(suite2p_folder, plane_folders[0])

        # Add the path to the list final_data_path
        path = path.replace("\\", "/")
        final_data_path.append(path)

    # Process the final_data_path to find and verify required files
    npy_results_path = []
    stat_paths = []
    ops_paths = []
    iscell_paths = []
    npy_results_ind = []

    for k, path in enumerate(final_data_path):
        # Build paths to stat.npy, ops.npy, and iscell.npy
        stat_path = os.path.join(path, 'stat.npy')
        ops_path = os.path.join(path, 'ops.npy')
        iscell_path = os.path.join(path, 'iscell.npy')
                
        if os.path.exists(stat_path) and os.path.exists(ops_path) and os.path.exists(iscell_path):
            stat_paths.append(stat_path)  # Add stat.npy path to the list
            ops_paths.append(ops_path)
            iscell_paths.append(iscell_path)
            npy_results_path.append(path)
            npy_results_ind.append(k)
            # Additional processing of the loaded file...
        
        else:
            # If stat.npy does not exist, ask the user to manually select a stat.npy file
            print(f"Error: This folder does not contain a stat.npy file in '{path}'.")

    return final_data_path, npy_results_path, stat_paths, ops_paths, iscell_paths, npy_results_ind