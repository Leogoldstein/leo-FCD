import os
from tkinter import Tk, filedialog
import re

def prompt_user_to_select_folder(PathSave, title='Select Folder'):
    """
    Prompt the user to select a single folder and find subfolders that match a date pattern.

    Args:
    PathSave (str): The initial folder to start the selection from.
    title (str): The title of the dialog box.

    Returns:
    list: A list of folder paths that match the date pattern. Returns an empty list if no matches are found or if the user cancels.
    """
    # Print PathSave to verify its value
    print(f"Initial directory for selection: {PathSave}")

    root = Tk()
    root.withdraw()  # Hide the root window
    root.attributes('-topmost', True)  # Bring the dialog to the front

    # Ensure PathSave is a valid directory
    if not os.path.isdir(PathSave):
        print(f"Error: The directory '{PathSave}' does not exist.")
        return []

    selected_folder = filedialog.askdirectory(initialdir=PathSave, title=title)

    root.destroy()  # Destroy the root window

    if not selected_folder:
        print("No folder selected.")
        return []

    # List to store selected folders
    folder_paths = []

    # Define the pattern for dates in the format YYYY-MM-DD
    date_pattern = re.compile(r'\d{4}-\d{2}-\d{2}')

    # Get a list of all items (files and folders) in selected_folder
    for item_name in os.listdir(selected_folder):
        # Get the full path of the item
        item_path = os.path.join(selected_folder, item_name)

        # Check if the item is a directory and not '.' or '..'
        if os.path.isdir(item_path) and item_name not in ('.', '..'):
            # Check if the item_name matches the date pattern
            if date_pattern.search(item_name):
                folder_paths.append(item_path)
    
    print("data paths:")
    for path in folder_paths:
        print(path)

    return folder_paths
