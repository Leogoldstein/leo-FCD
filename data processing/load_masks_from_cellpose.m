function [mask_cellpose, props_cellpose, outline_x_cellpose, outline_y_cellpose] = load_masks_from_cellpose(path, canal)
    % Cette fonction charge les masques et les outlines depuis un fichier .npy,
    % et retourne les coordonnées dans 'mask_cellpose', les propriétés dans 'props_cellpose',
    % ainsi que les coordonnées des outlines dans 'outline_x_cellpose' et 'outline_y_cellpose'.
    
    try
        % Déterminer le suffixe correspondant au canal
        switch canal
            case 1
                canal_str = 'Ch1';
            case 2
                canal_str = 'Ch2';
            case 3
                canal_str = 'Ch3';
            otherwise
                error('Le canal spécifié doit être 1, 2, ou 3.');
        end

        % Initialiser les sorties vides
        mask_cellpose = {};
        props_cellpose = struct('Area', {}, 'Centroid', {});
        outline_x_cellpose = {};  % Coordonnées X pour les contours
        outline_y_cellpose = {};  % Coordonnées Y pour les contours

        % Lister tous les fichiers .npy dans le répertoire
        npy_files = dir(fullfile(path, '*.npy'));
        
        % Filtrer les fichiers contenant le canal spécifié dans leur nom
        npy_files_canal = npy_files(contains({npy_files.name}, canal_str));
        
        % Vérifier s'il y a des fichiers disponibles pour ce canal
        if isempty(npy_files_canal)
            error(['Aucun fichier contenant "', canal_str, '" trouvé dans le répertoire spécifié.']);
        elseif numel(npy_files_canal) > 1
            % Si plusieurs fichiers existent, demander à l'utilisateur d'en choisir un
            [selected_file, selected_path] = uigetfile('*.npy', ...
                ['Plusieurs fichiers "', canal_str, '" trouvés. Veuillez sélectionner un fichier :'], ...
                fullfile(npy_files_canal(1).folder, npy_files_canal(1).name));
            if isequal(selected_file, 0)
                error('Aucun fichier sélectionné. Opération annulée par l''utilisateur.');
            end
            npy_file_path = fullfile(selected_path, selected_file);
        else
            % S'il n'y a qu'un seul fichier, l'utiliser directement
            npy_file_path = fullfile(npy_files_canal(1).folder, npy_files_canal(1).name);
        end
        
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
            masks_mat(isnan(masks_mat)) = 0;  % Remplacer NaN par 0
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

        % Nombre de cellules (une cellule par outline)
        num_cells_masks = size(masks_mat, 3);  % Nombre de masques (profondeur du tableau)
        num_cells_outlines = size(outlines_mat, 3);  % Nombre de contours (profondeur du tableau)

        % Initialiser les structures pour stocker les données
        mask_cellpose = {};        % Coordonnées des masques
        props_cellpose = struct('Area', cell(num_cells_masks, 1), 'Centroid', cell(num_cells_masks, 1));
        outline_x_cellpose = {};  % Coordonnées x des outlines
        outline_y_cellpose = {};  % Coordonnées y des outlines
        
        % Traitement des masques et calcul des propriétés
        for ncell = 1:num_cells_masks
            % Extraire les pixels du masque pour la cellule courante
            mask = masks_mat(:,:,ncell); % Masque de la cellule courante
            
            % Vérifier que le masque n'est pas vide
            if any(mask(:))
                % Calcul des propriétés pour chaque cellule (surface et centroïde)
                props = regionprops(mask, 'Area', 'Centroid');
                
                % Extraire le centroïde de la cellule
                centroid = props.Centroid; % Centroid [x, y]
                
                % Inverser la coordonnée Y du centroïde pour correspondre aux coordonnées de l'image
                image_height = size(mask, 1); % Hauteur de l'image
                centroid(2) = image_height - centroid(2) + 1; % Inversion de la coordonnée Y
                
                % Stocker les propriétés
                props_cellpose(ncell).Area = props.Area; % Stocker la surface
                props_cellpose(ncell).Centroid = centroid; % Stocker le centroïde
            else
                % Si le masque est vide, ne rien faire
                props_cellpose(ncell).Area = 0;
                props_cellpose(ncell).Centroid = [NaN, NaN];
            end
        end
        
        % Vérification de la taille de props_cellpose et affichage des centroïdes
        disp('Propriétés des cellules:');
        for ncell = 1:num_cells_masks
            centroid = props_cellpose(ncell).Centroid;
            disp(['Cellule ', num2str(ncell), ': ', num2str(centroid)]);
        end
        
        % Traitement des outlines et inversion des coordonnées Y
        for ncell = 1:num_cells_outlines
            % Extraire les coordonnées des outlines
            outline = outlines_mat(:,:,ncell);
            [outline_y, outline_x] = find(outline);  % Trouver les indices des pixels du contour
        
            % Inverser les coordonnées Y des outlines
            image_height = size(outline, 1);  % Hauteur de l'image (lignes)
            outline_y = image_height - outline_y + 1;  % Inversion des coordonnées Y
        
            % Stocker les coordonnées dans outline_x_cellpose et outline_y_cellpose
            outline_x_cellpose{ncell} = outline_x;  % Coordonnées x des contours
            outline_y_cellpose{ncell} = outline_y;  % Coordonnées y des contours
        end
  
        % Affichage des résultats
        figure;
        hold on;

        % Tracer les masques et les centroïdes
        for ncell = 1:num_cells_masks
            centroid = props_cellpose(ncell).Centroid;
            % Afficher un message de diagnostic
            disp(['Tracé du centroïde de la cellule ', num2str(ncell), ' à ', num2str(centroid)]);
            
            % Tracer le centroïde
            plot(centroid(1), centroid(2), 'rx', 'MarkerSize', 8, 'LineWidth', 2, ...
                 'DisplayName', ['Centroid ', num2str(ncell)]);
        end

        % Tracer les outlines
        for ncell = 1:num_cells_outlines
            pixels_x = outline_x_cellpose{ncell};
            pixels_y = outline_y_cellpose{ncell};
            plot(pixels_x, pixels_y, '.', 'MarkerSize', 1, ...
                 'DisplayName', ['Outline ', num2str(ncell)]);
        end

        % Ajouter des titres et légendes
        title('Plot of Mask Cells and Centroids');
        xlabel('X Coordinate');
        ylabel('Y Coordinate');
        legend;

        hold off;
    
    catch ME
        % Gestion des erreurs avec catch
        fprintf('Erreur rencontrée : %s\n', ME.message);
    end
end
