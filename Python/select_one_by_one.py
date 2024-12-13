import os
from tkinter import Tk, filedialog

def prompt_user_to_select_one_by_one(initial_folder, title='Select Folders'):
    """
    Prompt the user to select multiple folders, one by one.

    Args:
    initial_folder (str): The initial folder to start the selection from.
    title (str): The title of the dialog box.

    Returns:
    list: List of selected folder paths. Returns an empty list if the user cancels.
    """
    # Vérifier si le dossier initial est valide
    if not os.path.isdir(initial_folder):
        raise ValueError(f"The initial folder '{initial_folder}' does not exist or is not a directory.")
    
    # Initialiser l'interface Tkinter
    root = Tk()
    root.withdraw()  # Masquer la fenêtre principale
    root.attributes('-topmost', True)  # Amener la boîte de dialogue au premier plan
    
    paths = []
    
    while True:
        # Afficher la boîte de dialogue de sélection de dossier
        folder_path = filedialog.askdirectory(initialdir=initial_folder, title=title)
        
        # Si l'utilisateur annule, on sort de la boucle
        if not folder_path:
            break
        
        # Ajouter le dossier sélectionné à la liste
        paths.append(folder_path)
    
    # Détruire la fenêtre Tkinter après utilisation
    root.destroy()
    
    print("data paths:")
    for path in paths:
        print(path)
            
    return paths
