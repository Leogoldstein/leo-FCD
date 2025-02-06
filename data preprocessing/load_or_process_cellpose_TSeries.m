function load_or_process_cellpose_TSeries(folders_groups, date_group_paths, gcamp_output_folders)
    numFolders = length(date_group_paths);
    all_meanImg = cell(numFolders, 4);  % Initialisation de la cellule pour stocker les images moyennes
    current_group_folders_names = cell(numFolders, 4);
    labels = {'Gcamp', 'Red', 'Blue', 'Green'};
    
    % Charger les opérations pour chaque groupe
    for j = 1:length(folders_groups)
        
        current_group_folders = folders_groups{j}(:, 1); % Sélectionne les chemins des dossiers du groupe j
    
        if ~isempty(current_group_folders)  % Vérifier si le groupe contient des dossiers
            try
                % Charger les opérations pour ce groupe
                all_ops = load_ops(current_group_folders); 
                
                % Itérer sur chaque dossier dans le groupe
                for k = 1:length(all_ops)
                    % Vérifier si all_ops{k} est un dictionnaire Python
                    if isa(all_ops{k}, 'py.dict')
                        ops = all_ops{k};  % Dictionnaire Python
                        meanImg = double(ops{'meanImg'});  % Convertir en tableau MATLAB
                    else
                        ops = all_ops{k};  % Structure MATLAB
                        meanImg = ops.meanImg;  % Extraire l'image moyenne
                    end
    
                    % Stocker l'image moyenne dans la cellule
                    all_meanImg{k, j} = meanImg;
    
                    % Stocker le nom du dossier
                    current_group_folders_names{k, j} = folders_groups{j}{k, 2};  
                end
            catch ME
                % Gestion d'erreur si la fonction 'load_ops' échoue
                warning('Error loading operations for group: %s. Error: %s', labels{j}, ME.message);
                all_meanImg(:, j) = [];  % Si une erreur se produit, on vide la colonne
            end
        end
    end
    
    % Aligner les images
    for l = 1:numFolders
        if ~isempty(all_meanImg{l, 1}) && ~isempty(all_meanImg{l, 4})
            % Aligner l'image Gcamp (1) avec l'image Green (4)
            reg_obj = imregcorr(all_meanImg{l, 1}, all_meanImg{l, 4}, 'similarity');
            T = reg_obj.T;
    
            % Appliquer la transformation finale sur l'image Blue (3)
            if ~isempty(all_meanImg{l, 3})
                aligned_image = imwarp(all_meanImg{l, 3}, affine2d(T), 'OutputView', imref2d(size(all_meanImg{l, 3})));          
                aligned_image = normalize_image(aligned_image);

                % Créer un nom de fichier unique basé sur la date et le groupe
                aligned_image_filename = 'aligned_image.tif'; 
                output_path = fullfile(gcamp_output_folders{k}, aligned_image_filename);
                disp(output_path)
                
                % Sauvegarder l'image alignée
                imwrite(aligned_image, output_path, 'tif');
                fprintf('Image alignée sauvegardée : %s\n', output_path);
            end
        end
    end
end

function norm_img = normalize_image(img)
    % Fonction pour normaliser une image entre 0 et 255
    if isfloat(img)
        % Si l'image est en float (double), normaliser entre 0 et 1
        norm_img = mat2gray(img);
    elseif isinteger(img)
        % Si l'image est en entier (uint8, uint16), normaliser entre 0 et 255
        norm_img = double(img) / double(max(img(:))) * 255;
        norm_img = uint8(norm_img);
    else
        error('Type de données non supporté pour l''image.');
    end
end