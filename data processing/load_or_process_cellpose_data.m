function [num_cells_mask, mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_path)
    % Initialiser les variables pour stocker les résultats
    try
        % Utiliser readNPY pour lire le fichier (nécessite la bibliothèque npy-matlab)
        mod = py.importlib.import_module('python_function');
        image = mod.read_npy_file(npy_file_path);

        % Extraire la clé 'masks'
        keys = image.keys();  % Obtenir les clés du dictionnaire
        keys_list = cellfun(@char, cell(py.list(keys)), 'UniformOutput', false);  % Convertir en tableau de chaînes MATLAB

        % Chargement des masques
        if ismember('masks', keys_list)
            masks = image{'masks'};  % Accéder à la clé 'masks'
            masks_mat = double(py.numpy.array(masks));  % Convertir en tableau MATLAB
            num_cells_mask = numel(unique(masks_mat)) - 1; % Soustraire 1 pour ignorer le label 0 (pas de ROI) 
        else
            error('La clé "masks" n''a pas été trouvée dans le dictionnaire Python.');
        end

        % Chargement des outlines
        if ismember('outlines', keys_list)
            outlines = image{'outlines'};  % Accéder à la clé 'outlines'
            outlines_mat = double(py.numpy.array(outlines));  % Convertir en tableau MATLAB
            outlines_mat(isnan(outlines_mat)) = 0;  % Remplacer NaN par 0
        else
            error('La clé "outlines" n''a pas été trouvée dans le dictionnaire Python.');
        end

        % Initialisation des structures pour stocker les résultats
        mask_cellpose = cell(num_cells_mask, 1);         % Masques binaires individuels
        props_cellpose = struct('Area', cell(num_cells_mask, 1), 'Centroid', cell(num_cells_mask, 1));
        outlines_x_cellpose = cell(num_cells_mask, 1);    % Coordonnées X des contours
        outlines_y_cellpose = cell(num_cells_mask, 1);    % Coordonnées Y des contours

        % Traitement de chaque cellule
        for i = 1:num_cells_mask
            % Extraire le masque de la cellule i
            mask_cellpose{i} = (masks_mat == i);

            % Calculer les propriétés (aire, centroïde)
            props = regionprops(mask_cellpose{i}, 'Area', 'Centroid');
            props_cellpose(i).Area = props.Area;
            props_cellpose(i).Centroid = props.Centroid; % Ne pas inverser Y

            % Identifier les contours de la cellule i
            [outline_y, outline_x] = find(bwperim(mask_cellpose{i}));

            % Stocker les contours
            outline_x_cellpose{i} = outline_x;
            outline_y_cellpose{i} = outline_y; % Ne pas inverser Y
        end

    catch ME
        % Gestion des erreurs avec catch
        fprintf('Erreur rencontrée : %s\n', ME.message);
    end
end
