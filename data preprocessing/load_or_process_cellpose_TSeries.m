function load_or_process_cellpose_TSeries(folders_groups, blue_output_folders)
   
    py.importlib.import_module('numpy');
    labels = {'Gcamp', 'Red', 'Blue', 'Green'};

    % Charger les opérations pour chaque groupe
    for j = 1:length(folders_groups)
       
        current_group_folders = folders_groups{j}(:, 1); % Chemins des dossiers du groupe j    
        try
            % Charger les opérations pour ce groupe
            all_ops = load_ops(current_group_folders); 
            
            % Itérer sur chaque dossier dans le groupe
            for k = 1:length(all_ops)
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
            warning('Erreur lors du chargement des opérations pour le groupe: %s. Erreur: %s', labels{j}, ME.message);
            % Ne pas vider la colonne ici, car l'erreur pourrait être temporaire
            all_meanImg{1:end, j} = {NaN};  % Marquer comme NaN pour indiquer une erreur
        end

    end

    % Charger les opérations pour chaque groupe
    for j = 1:length(folders_groups)

        current_group_folders = folders_groups{j}(:, 1); % Chemins des dossiers du groupe j
        numFolders = length(current_group_folders);
        npy_file_paths = cell(numFolders, 1);
      
        for i = 1:numel(current_group_folders)
            try
                current_folder = current_group_folders{i}; % Dossier actuel
               
                % Lister tous les fichiers .npy
                npy_files = dir(fullfile(current_folder, '*aligned_image.npy'));

                if ~isempty(npy_files)
                    if numel(npy_files) > 1
                        % Sélection utilisateur
                        [selected_file, selected_path] = uigetfile(fullfile(current_folder, '*.npy'), ...
                            'Sélectionnez un fichier .npy');
    
                        if isequal(selected_file, 0)
                            error('Aucun fichier sélectionné. Opération annulée.');
                        end
                        npy_file_path = fullfile(selected_path, selected_file);
                    else
                        npy_file_path = fullfile(npy_files(1).folder, npy_files(1).name);
                    end
    
                    % Vérification et lecture du fichier aligné
                    aligned_image_path = strrep(npy_file_path, '_aligned_image.npy', '.tif');
    
                    if isfile(aligned_image_path)
                        aligned_image = imread(aligned_image_path);
                        aligned_image = normalize_image(aligned_image);
                        fprintf('TIFF aligné trouvé : %s\n', aligned_image_path);
                        npy_file_paths{j, i} = npy_file_path;
                    else
                        fprintf('Fichier TIFF introuvable : %s\n', aligned_image_path);
                    end
    
                else
                    aligned_image_filename = 'aligned_image.tif';
                    
                    % Vérifiez si l'indice i est valide pour blue_output_folders
                    if i <= numel(blue_output_folders) && isfolder(blue_output_folders{i})
                        output_path = fullfile(blue_output_folders{i}, aligned_image_filename);
                    else
                        fprintf('Indice %d est hors limites pour blue_output_folders ou dossier non valide, on passe au dossier suivant.\n', i);
                        continue;  % Passer au dossier suivant
                    end
    
                    if isfile(output_path)
                        aligned_image = imread(output_path);
                        fprintf('Fichier aligné chargé : %s\n', output_path);
    
                        % Exécution de Cellpose
                        launch_cellpose_from_matlab(output_path);
    
                        % Vérifier la création du fichier NPY
                        [~, folder_name, ~] = fileparts(output_path);
                        npy_file_name = [folder_name, '_seg.npy'];
                        npy_file_path = fullfile(current_folder, npy_file_name);
    
                        if isfile(npy_file_path)
                            npy_file_paths{j, i} = npy_file_path;
                            fprintf('Fichier NPY ajouté : %s\n', npy_file_path);
                        else
                            fprintf('Aucun fichier NPY trouvé après Cellpose : %s\n', npy_file_path);
                        end              
                    else
                        fprintf('Aucun fichier aligné trouvé dans : %s\n', current_folder);
    
                        % Vérifier que les images moyennes existent avant alignement
                        if j <= size(all_meanImg, 1) && ~isempty(all_meanImg{j, 1}) && ~isempty(all_meanImg{j, 4})
                            reg_obj = imregcorr(all_meanImg{j, 4}, all_meanImg{j, 1}, 'similarity');
                            T = reg_obj.T;
            
                            if ~isempty(all_meanImg{j, 3})
                                aligned_image = imwarp(all_meanImg{j, 3}, affine2d(T), 'OutputView', imref2d(size(all_meanImg{j, 3})));          
                                aligned_image = normalize_image(aligned_image);
            
                                % Sauvegarde du fichier TIFF aligné
                                imwrite(aligned_image, output_path, 'tif');
                                fprintf('Image alignée sauvegardée : %s\n', output_path);
                            end
                        end
                    end
                end
            catch ME
                % Si une erreur survient, afficher un message d'erreur et passer au dossier suivant
                continue;  % Passer au dossier suivant
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


function display_animation(image_tiff, aligned_image)
    % Fonction pour afficher l'animation
    figureHandle = figure('Position', [100, 100, 800, 600], 'Name', 'Animation');
    while ishandle(figureHandle) && isvalid(figureHandle)
        for i = 1:2
            if ~ishandle(figureHandle) || ~isvalid(figureHandle)
                break; % Sortir de la boucle si la figure est supprimée
            end
            if mod(i, 2) == 1
                imshow(image_tiff, 'Parent', gca);
                title('Image Originale (Normalisée)');
            else
                imshow(aligned_image, 'Parent', gca);
                title('Image Alignée (Normalisée)');
            end
            pause(0.5);
        end
    end
end


function launch_cellpose_from_matlab(image_path)
    % Cette fonction configure l'environnement Python pour Cellpose et lance Cellpose depuis MATLAB avec l'interface graphique.
    % 
    % Arguments :
    %   - image_path : Le chemin vers l'image à traiter (format .tif ou .png).
    % Exemple :
    %   launch_cellpose_from_matlab('C:\chemin\vers\image.png');

    % Chemin vers l'exécutable Python dans l'environnement Conda de Cellpose
    pyExec = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe';  % Mettre à jour avec votre propre chemin

    % Vérifier si l'environnement Python est déjà configuré
    currentPyEnv = pyenv;  % Ne pas passer d'arguments à pyenv
    if ~strcmp(currentPyEnv.Version, pyExec)
        % Si l'environnement Python n'est pas celui que nous voulons, on le configure
        pyenv('Version', pyExec);  % Configurer l'environnement Python
    end

    % Vérifier si l'environnement Python est correctement configuré
    try
        py.print("Python fonctionne dans Cellpose !");
    catch
        error('Erreur : Python n''est pas correctement configuré dans MATLAB.');
    end

    % Ajouter le chemin d'accès de Cellpose au PATH si nécessaire
    setenv('PATH', [getenv('PATH') ';C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts']);
    
    % Ouvrir l'interface graphique de Cellpose
    fprintf('Lancement de Cellpose avec l''interface graphique pour traiter l''image : %s\n', image_path);
    cellposePath = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts\cellpose.exe';  % Spécifiez le chemin absolu
    system(cellposePath);  % Lancer Cellpose avec l'interface graphique
end
