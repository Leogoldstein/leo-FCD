function [all_num_cells_masks, all_mask_cellpose, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_paths)
    
    numFiles = length(npy_file_paths);
    % Initialiser les cellules pour stocker les données
    all_num_cells_masks = cell(numFiles, 1);
    all_mask_cellpose = cell(numFiles, 1);
    all_props_cellpose = cell(numFiles, 1);
    all_outlines_x_cellpose = cell(numFiles, 1);
    all_outlines_y_cellpose = cell(numFiles, 1);
    
    for m = 1:numFiles
        if ~isempty(npy_file_paths{m})
            npy_file_path = npy_file_paths{m};   
            disp(npy_file_path)
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
                    num_cells_masks = numel(unique(masks_mat)) - 1; % Soustraire 1 pour ignorer le label 0 (pas de ROI) 
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
                mask_cellpose = cell(num_cells_masks, 1);         % Masques binaires individuels
                props_cellpose = struct('Area', cell(num_cells_masks, 1), 'Centroid', cell(num_cells_masks, 1));
                outline_x_cellpose = cell(num_cells_masks, 1);    % Coordonnées X des contours
                outline_y_cellpose = cell(num_cells_masks, 1);    % Coordonnées Y des contours
                
                % Traitement de chaque cellule
                for i = 1:num_cells_masks
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
                
                % Affichage des résultats
                % figure;
                % hold on;
                % 
                % % Tracer les contours et les centroides
                % for i = 1:num_cells_masks
                %     % Récupérer les coordonnées des contours
                %     plot(outline_x_cellpose{i}, outline_y_cellpose{i}, '.', 'MarkerSize', 1, ...
                %          'DisplayName', ['Outline ', num2str(i)]);
                % 
                %     % Récupérer et tracer le centroïde
                %     centroid = props_cellpose(i).Centroid;
                %     plot(centroid(1), centroid(2), 'rx', 'MarkerSize', 8, 'LineWidth', 2, ...
                %          'DisplayName', ['Centroid ', num2str(i)]);
                % 
                %     % Affichage des messages de diagnostic
                %     disp(['Centroïde de la cellule ', num2str(i), ': ', num2str(centroid)]);
                % end
                % 
                % % Ajouter des titres et légendes
                % title('Contours et Centroïdes des Cellules');
                % xlabel('Coordonnée X');
                % ylabel('Coordonnée Y');
                % 
                % % Inverser l'axe Y pour aligner correctement les cellules (inverse de l'orientation verticale)
                % set(gca, 'YDir', 'reverse');
                % 
                % hold off;
        
            catch ME
                % Gestion des erreurs avec catch
                fprintf('Erreur rencontrée : %s\n', ME.message);
            end
            
            % Stocker les résultats dans les variables de sortie
            all_num_cells_masks{m} = num_cells_masks; 
            all_mask_cellpose{m} = mask_cellpose;
            all_props_cellpose{m} = props_cellpose;
            all_outlines_x_cellpose{m} = outline_x_cellpose;      
            all_outlines_y_cellpose{m} = outline_y_cellpose;          
        end
    end
end