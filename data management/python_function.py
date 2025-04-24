import numpy as np

def read_npy_file(file_path):
    """
    Lit un fichier .npy et renvoie son contenu sous forme de liste.
    """
    data = np.load(file_path, allow_pickle=True)
    return data.tolist()