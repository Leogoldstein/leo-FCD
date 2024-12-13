import os

def get_unique_folders_in_last_directory(paths):
    """
    Obtenir les dossiers uniques dans le dernier dossier de chaque chemin spécifié.

    Args:
    paths (list): Liste des chemins de dossiers.

    Returns:
    list: Liste des dossiers uniques trouvés dans les derniers dossiers spécifiés.
    """
    last_directories = set()

    # Obtenir le dernier dossier de chaque chemin
    for path in paths:
        last_directory = os.path.basename(os.path.normpath(path))
        last_directories.add(last_directory)

    # Dictionnaire pour stocker les dossiers uniques trouvés dans chaque dernier dossier
    unique_folders = set()

    # Lister les dossiers dans chaque dernier dossier
    for last_directory in last_directories:
        for path in paths:
            parent_directory = os.path.join(os.path.dirname(path), last_directory)
            if os.path.isdir(parent_directory):
                try:
                    for entry in os.listdir(parent_directory):
                        full_path = os.path.join(parent_directory, entry)
                        if os.path.isdir(full_path):
                            unique_folders.add(entry)
                except PermissionError:
                    print(f"Permission refusée pour accéder à {parent_directory}")

    return list(unique_folders)

def select_and_update_paths(paths):
    """
    Permet à l'utilisateur de sélectionner un dossier parmi les dossiers uniques trouvés
    et met à jour les chemins avec le dossier sélectionné.

    Args:
    paths (list): Liste des chemins de dossiers à analyser.

    Returns:
    list: Liste des chemins mis à jour avec le dossier sélectionné.
    """
    # 1. Obtenir les dossiers uniques dans le dernier dossier
    unique_folders = get_unique_folders_in_last_directory(paths)

    if not unique_folders:
        print("Aucun dossier trouvé.")
        return []

    print("Dossiers uniques trouvés dans les derniers dossiers indiqués :")
    for i, folder in enumerate(unique_folders):
        print(f"{i + 1}. {folder}")

    # 2. Permettre à l'utilisateur de sélectionner un dossier
    try:
        selection = int(input("Sélectionnez le numéro du dossier que vous souhaitez ajouter : ")) - 1
        if selection < 0 or selection >= len(unique_folders):
            raise ValueError("Sélection invalide.")
    except ValueError as e:
        print(e)
        return []

    selected_folder = unique_folders[selection]
    print(f"Dossier sélectionné : {selected_folder}")

    # 3. Joindre le dossier sélectionné à tous les chemins de folder_paths
    updated_paths = []
    for path in paths:
        base_path = os.path.dirname(path)
        last_directory = os.path.basename(os.path.normpath(path))
        updated_path = os.path.join(base_path, last_directory, selected_folder)
        updated_paths.append(updated_path)

    # Afficher les chemins mis à jour
    print("Chemins mis à jour :")
    for path in updated_paths:
        print(path)

    return updated_paths