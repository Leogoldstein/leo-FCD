function cooblue = load_masks_from_cellpose(path)
    % Cette fonction charge les masques depuis un fichier .npy,
    % extrait les coordonnées des cellules (composants connexes),
    % et retourne les coordonnées dans la cellule 'cooblue'.
    % Elle affiche également les cellules sur un graphique.

    % Lister tous les fichiers .npy dans le répertoire
    npy_files = dir(fullfile(path, '*.npy'));

    % Vérifier si des fichiers .npy existent
    if isempty(npy_files)
        error('Aucun fichier .npy trouvé dans le répertoire spécifié.');
    end

    % Construire le chemin complet du premier fichier .npy
    npy_file_path = fullfile(npy_files(1).folder, npy_files(1).name);
    
    % Utiliser readNPY pour lire le fichier (nécessite la bibliothèque npy-matlab)
    mod = py.importlib.import_module('python_function');
    image = mod.read_npy_file(npy_file_path);           
    
    % Extraire la clé 'masks'
    keys = image.keys();  % Obtenir les clés du dictionnaire
    keys_list = cellfun(@char, cell(py.list(keys)), 'UniformOutput', false);  % Convertir en tableau de chaînes MATLAB
    
    if ismember('masks', keys_list)  % Vérifier si la clé 'masks' existe
        masks = image{'masks'};  % Accéder à la clé 'masks'
        masks_mat = double(py.numpy.array(masks));  % Convertir en tableau MATLAB
        
        % Suppression des NaN dans les masks
        masks_mat(isnan(masks_mat)) = 0;  % Remplacer NaN par 0 (ou autre valeur si nécessaire)
        
        % Afficher le nombre de pixels de masque
        num_mask_pixels = sum(masks_mat(:));  % Nombre de pixels de masque (valeurs égales à 1)
        disp(['Number of mask pixels: ', num2str(num_mask_pixels)]);
       
    else
        error('La clé "masks" n''a pas été trouvée dans le dictionnaire Python.');
    end

    % Identifier les composants connexes dans le masque
    cc = bwconncomp(masks_mat, 8);  % Connexité à 8 voisins pour les pixels actifs

    % Nombre de cellules (composants connexes)
    num_cells = cc.NumObjects;

    % Initialiser un tableau de cellules pour stocker les coordonnées (x, y)
    cooblue = {};  % Cellule pour stocker les coordonnées

    % Afficher les cellules et stocker les coordonnées
    for ncell = 1:num_cells
        % Extraire les indices des pixels de la cellule courante
        cell_pixels = cc.PixelIdxList{ncell};
        
        % Convertir les indices linéaires en coordonnées (x, y)
        [cell_y, cell_x] = ind2sub(size(masks_mat), cell_pixels);
        
        % Stocker les coordonnées dans cooblue
        for pix = 1:length(cell_x)
            cooblue{ncell, pix, 1} = cell_x(pix);  % Coordonnée x
            cooblue{ncell, pix, 2} = cell_y(pix);  % Coordonnée y
        end
        
        % Tracer les coordonnées de la cellule
        hold on;
        plot(cell_x, cell_y, 'o', 'DisplayName', ['Cell ', num2str(ncell)], 'MarkerSize', 3);
    end

    % Ajouter des titres et légendes pour le graphique
    title('Plot of Mask Cells');
    xlabel('X Coordinate');
    ylabel('Y Coordinate');
    legend;

    % Inverser l'axe Y pour aligner correctement les cellules (inverse de l'orientation verticale)
    set(gca, 'YDir', 'reverse');

    hold off;
end
