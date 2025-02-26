function [all_meanImg, aligned_images, npy_file_paths] = load_or_process_cellpose_TSeries(folders_groups, blue_output_folders, date_group_paths)
    
    numFolders = length(blue_output_folders);
    npy_file_paths = cell(numFolders, 1);
    aligned_images = cell(numFolders, 1);
    numGroups = length(folders_groups);
    all_meanImg = cell(numFolders, numGroups);
    base_output_folders = cell(numFolders, 1);

    for i = 1:numel(blue_output_folders)
        if isempty(blue_output_folders{i})
            path = fullfile(date_group_paths{i}, 'Single images');
            if isfolder(path)
                currentFolder = folders_groups{1}{i, 1};
                [npy_file_path, aligned_image] = load_or_process_cellpose_SingleImage(date_group_paths{i}, currentFolder);
                all_meanImg = [];  % Initialisation
                aligned_images{i} = aligned_image;
                npy_file_paths{i} = npy_file_path;
            else
                all_meanImg = [];  % Initialisation
                aligned_images{i} = [];
                npy_file_paths{i} = [];
            end
        else 
            split_path = strsplit(blue_output_folders{i}, filesep); 
            base_output_folders{i} = fullfile(split_path{1:7});
    
            try
                output_folder = string(blue_output_folders{i}); % Dossier actuel
                cellpose_files = dir(fullfile(output_folder, '*_seg.npy'));
                aligned_image_path = fullfile(output_folder, 'aligned_image.tif');
                npy_file_path = fullfile(output_folder, 'aligned_image_seg.npy');
             
                if ~isempty(cellpose_files)
                    if numel(cellpose_files) > 1
                        [selected_file, selected_path] = uigetfile(fullfile(output_folder, '*.npy'), ...
                            'Sélectionnez un fichier .npy');
        
                        if isequal(selected_file, 0)
                            error('Aucun fichier sélectionné. Opération annulée.');
                        end
                        npy_file_path = fullfile(selected_path, selected_file);
                    else
                        npy_file_path = fullfile(cellpose_files(1).folder, cellpose_files(1).name);
                    end
        
                    if isfile(aligned_image_path)
                        aligned_image = imread(aligned_image_path);
                        aligned_image = normalize_image(aligned_image);
                        fprintf('TIFF aligné trouvé : %s\n', aligned_image_path);
                        aligned_images{i} = aligned_image;
                        npy_file_paths{i} = npy_file_path;
                    else
                        fprintf('Fichier TIFF introuvable : %s\n', aligned_image_path);
                    end              
                else
                    if isfile(aligned_image_path)
                        aligned_image = imread(aligned_image_path);
                        fprintf('Fichier aligné chargé : %s\n', aligned_image_path);
                        aligned_images{i} = aligned_image;
    
                        % Lancer Cellpose
                        launch_cellpose_from_matlab(aligned_image_path);  
        
                        if isfile(npy_file_path)
                            npy_file_paths{i} = npy_file_path;
                            fprintf('Fichier NPY ajouté : %s\n', npy_file_path);
                        else
                            fprintf('Aucun fichier NPY trouvé après Cellpose : %s\n', npy_file_path);
                            npy_file_paths{i} = [];
                        end
                    else
                        fprintf('Aucun fichier aligné trouvé dans : %s\n', blue_output_folders{i});
                    
                        numGroups = length(folders_groups);
                        meanImg_channels = cell(numGroups, 1);
                        labels = {'Gcamp', 'Red', 'Blue', 'Green'};
                        
                        for j = 1:numGroups
                            try
                                input_path = string(folders_groups{j}{i, 1});
                                disp(input_path)
                                
                                [~, ~, ext] = fileparts(input_path);
                                files = dir(fullfile(input_path, '*.npy'));
                    
                                if ~isempty(files)
                                    % Unpack .npy file paths
                                    newOpsPath = fullfile(input_path, 'ops.npy');
                    
                                    % Call the Python function to load stats and ops
                                    try
                                        mod = py.importlib.import_module('python_function');
                                        py.importlib.import_module('numpy');
                                        ops = mod.read_npy_file(newOpsPath);
                                        
                                        meanImg = double(ops{'meanImg'});
                                    catch ME
                                        error('Failed to call Python function: %s', ME.message);
                                    end
                    
                                elseif strcmp(ext, '.mat')
                                    % Load .mat files
                                    data = load(input_path);
                                    ops = data.ops;
                                    meanImg = ops.meanImg;
                                else
                                    error('Unsupported file type: %s', ext);
                                end
                                       
                                meanImg_channels{j} = meanImg;   
                                
                                save(fullfile(base_output_folders{i}, 'meanImg_channels.mat'), 'meanImg_channels');
    
                            catch ME
                                warning('Erreur de chargement pour le groupe: %s. Erreur: %s', labels{j}, ME.message);
                                meanImg_channels{j} = NaN; % Stocker NaN en cas d'erreur
                            end
                        end
                        
                        %Vérification avant l'alignement
                        if all(cellfun(@(x) ~isempty(x) && isnumeric(x), {meanImg_channels{1}, meanImg_channels{4}}))
                            reg_obj = imregcorr(meanImg_channels{1}, meanImg_channels{4}, 'similarity'); % recalage de l'image gcamp avec l'image green (image de référence)
    
                            T = reg_obj.T;
    
                            if ~isempty(meanImg_channels{3}) && isnumeric(meanImg_channels{3})
                                aligned_image = imwarp(meanImg_channels{3}, affine2d(T), 'OutputView', imref2d(size(meanImg_channels{3})));          
                                not_aligned_image = meanImg_channels{4};
                                
                                aligned_image = normalize_image(aligned_image);
                                aligned_images{i} = aligned_image;
                                imwrite(aligned_image, aligned_image_path, 'tif');
                                fprintf('Image alignée sauvegardée : %s\n', aligned_image_path);
    
                                display_animation(not_aligned_image, aligned_image)
    
                                % Lancer Cellpose
                                launch_cellpose_from_matlab(aligned_image_path);

                                if isfile(npy_file_path)
                                    npy_file_paths{i} = npy_file_path;
                                    fprintf('Fichier NPY ajouté : %s\n', npy_file_path);
                                else
                                    fprintf('Aucun fichier NPY trouvé après Cellpose : %s\n', npy_file_path);
                                    npy_file_paths{i} = [];
                                end
    
                            else
                                warning('meanImg_channels{3} est vide ou invalide.');
                            end  
                        else
                            warning('Problème avec meanImg_channels{1} ou meanImg_channels{4}, impossible d’aligner.');
                        end
                    end
                end
    
                filePath = fullfile(base_output_folders{i}, 'meanImg_channels.mat');
                if exist(filePath, 'file') == 2 
                    data = load(filePath);
                    if isfield(data, 'meanImg_channels')
                        % Si `meanImg_channels` contient 4 éléments, tu peux les affecter un par un
                        [all_meanImg{i,:}] = deal(data.meanImg_channels{:});
                    end
                else
                    fprintf('Fichier meanImg_channels.mat introuvable : %s\n', base_output_folders{i});
                end
    
            catch ME
                warning('Erreur dans le traitement du dossier %d : %s', i, ME.message);
                continue;
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
    image_tiff = double(image_tiff);  % Cast image_tiff to double
    aligned_image = double(aligned_image);  % Cast aligned_image to double

    % Normalisation de aligned_image par rapport à image_tiff
    mean_tiff = mean(image_tiff(:));
    std_tiff = std(image_tiff(:));

    mean_aligned = mean(aligned_image(:));
    std_aligned = std(aligned_image(:));

    % Transformation pour aligner l'intensité
    aligned_image_norm = ((aligned_image - mean_aligned) / std_aligned) * std_tiff + mean_tiff;

    % Assurer que les valeurs restent dans la plage de image_tiff
    aligned_image_norm = max(min(aligned_image_norm, max(image_tiff(:))), min(image_tiff(:)));

    % Création de la figure
    figureHandle = figure('Position', [100, 100, 800, 600], 'Name', 'Animation');
    ax = axes('Parent', figureHandle); % Création des axes

    while ishandle(figureHandle) && isvalid(figureHandle)
        for i = 1:2
            if ~ishandle(figureHandle) || ~isvalid(figureHandle)
                break; % Sortie si la figure est fermée
            end
            if mod(i, 2) == 1
                imagesc(image_tiff, 'Parent', ax);
                title(ax, 'Image Originale (Normalisée)');
            else
                imagesc(aligned_image_norm, 'Parent', ax);
                title(ax, 'Image Alignée (Normalisée)');
            end
            colormap(ax, 'gray'); % Colormap en niveaux de gris
            axis(ax, 'image'); % Maintien des proportions de l'image
            colorbar; % Ajout d'une barre de couleur
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


function [npy_file_path, aligned_image] = load_or_process_cellpose_SingleImage(date_group_path, currentFolder)
    % Fonction pour recaler les images en fonction d'un canal et d'un fichier moyen
    %
    % Arguments :
    % - date_group_paths : Cell array contenant les chemins de chaque dossier
    % - all_ops : Cell array contenant les structures ou dictionnaires Python pour chaque dossier
    %
    % Retourne :
    % - npy_file_paths : Cell array contenant les chemins des fichiers NPY traités
    
    % Demander à l'utilisateur de spécifier le canal
    canal = input('Veuillez entrer le canal (1 pour Rouge, 2 pour Vert, 3 pour Bleu) : ');
    if ~ismember(canal, [1, 2, 3])
        error('Le canal spécifié doit être 1 (Rouge), 2 (Vert) ou 3 (Bleu).');
    end
    
    % Déterminer le suffixe correspondant au canal
    switch canal
        case 1
            canal_str = 'Ch1';
        case 2
            canal_str = 'Ch2';
        case 3
            canal_str = 'Ch3';
    end

    path = fullfile(date_group_path, 'Single images');
    
    % Lister tous les fichiers .npy dans le répertoire
    cellpose_files = dir(fullfile(path, '*_seg.npy'));
    cellpose_files_canal = cellpose_files(contains({cellpose_files.name}, canal_str));
    
    % Vérifier si des fichiers NPY sont disponibles pour ce canal
    if ~isempty(cellpose_files_canal)
        if numel(cellpose_files_canal) > 1
            % Si plusieurs fichiers existent, demander à l'utilisateur d'en choisir un parmi ceux qui contiennent le canal
            [selected_file, selected_path] = uigetfile({['*' canal_str '*.npy']}, ...
                ['Plusieurs fichiers "', canal_str, '" trouvés. Veuillez sélectionner un fichier :'], ...
                fullfile(cellpose_files_canal(1).folder, cellpose_files_canal(1).name));
            if isequal(selected_file, 0)
                error('Aucun fichier sélectionné. Opération annulée par l''utilisateur.');
            end
            npy_file_path = fullfile(selected_path, selected_file);
        else
            % S'il n'y a qu'un seul fichier, l'utiliser directement
            npy_file_path = fullfile(cellpose_files_canal(1).folder, cellpose_files_canal(1).name);
        end

        % Créer le chemin du fichier TIFF aligné en remplaçant le suffixe _seg.npy par .tiff
        aligned_image_path = strrep(npy_file_path, '_seg.npy', '.tif');
        
        % Lire l'image alignée
        aligned_image = imread(aligned_image_path);
        aligned_image = normalize_image(aligned_image);
    else
        % Si aucun fichier NPY n'existe, passer aux fichiers TIF
        tif_files = dir(fullfile(path, '*.tif'));
        tif_files_canal = tif_files(contains({tif_files.name}, canal_str));
        
        % Vérifier si des fichiers TIF sont disponibles pour ce canal
        if isempty(tif_files_canal)
            % Aucun fichier TIF trouvé, afficher un message et passer à l'itération suivante
            disp(['Aucun fichier contenant "', canal_str, '" trouvé dans le répertoire spécifié. Passage au suivant.']);
            aligned_image = [];
            npy_file_path = [];
            return;
        elseif numel(tif_files_canal) > 1
            % Si plusieurs fichiers existent, demander à l'utilisateur d'en choisir un parmi ceux qui contiennent le canal
            [selected_file, selected_path] = uigetfile({['*' canal_str '*.tif']}, ...
                ['Plusieurs fichiers "', canal_str, '" trouvés. Veuillez sélectionner un fichier :'], ...
                fullfile(tif_files_canal(1).folder, tif_files_canal(1).name));
            if isequal(selected_file, 0)
                error('Aucun fichier sélectionné. Opération annulée par l''utilisateur.');
            end
            tif_file_path = fullfile(selected_path, selected_file);
        else
            % S'il n'y a qu'un seul fichier, l'utiliser directement
            tif_file_path = fullfile(tif_files_canal(1).folder, tif_files_canal(1).name);
        end
        
        % Définir le chemin de sortie pour l'image alignée en utilisant toujours tif_file_path
        [~, file_name, ~] = fileparts(tif_file_path); % Utiliser tif_file_path pour le chemin de sortie
        
        % Vérifier si le fichier est déjà aligné (commence par 'aligned_')
        if contains(file_name, 'aligned_')
            % Si le fichier est déjà aligné, charger l'image alignée
            aligned_image = imread(tif_file_path);
            fprintf('Fichier déjà aligné trouvé, chargé : %s\n', tif_file_path);
            
            % Retrouver l'image originale en enlevant le préfixe 'aligned_' et ajouter '.tif'
            original_file_name = [strrep(file_name, 'aligned_', ''), '.tif'];
            original_file_path = fullfile(path, original_file_name);
            image_tiff = imread(original_file_path);
            fprintf('Image originale trouvée, chargée : %s\n', original_file_path);

            % Normalisation des images avant l'animation
            image_tiff = normalize_image(image_tiff);
            aligned_image = normalize_image(aligned_image);

            % Animation avant de lancer Cellpose
            display_animation(image_tiff, aligned_image);
            
            launch_cellpose_from_matlab(tif_file_path);

            % Vérifier si le fichier .npy existe après l'exécution de Cellpose
            [~, folder_name, ~] = fileparts(tif_file_path);
            npy_file_name = [folder_name, '_seg.npy'];
            npy_file_path = fullfile(path, npy_file_name);
            if isfile(npy_file_path)
                npy_file_path = npy_file_path;
                fprintf('Fichier NPY trouvé et ajouté\n');
            else
                % Si aucun fichier NPY n'est trouvé, afficher un message
                disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
                npy_file_path = [];
            end

        else
            % Determine file extension and check for .npy files
            [~, ~, ext] = fileparts(currentFolder);
            files = dir(fullfile(currentFolder, '*.npy'));

            if ~isempty(files)
                % Unpack .npy file paths
                newOpsPath = fullfile(currentFolder, 'ops.npy');

                % Call the Python function to load stats and ops
                try
                    mod = py.importlib.import_module('python_function');
                    ops = mod.read_npy_file(newOpsPath);
                    meanImg = double(ops{'meanImg'});
                catch ME
                    error('Failed to call Python function: %s', ME.message);
                end

            elseif strcmp(ext, '.mat')
                % Load .mat files
                data = load(currentFolder);
                ops = data.ops;
                meanImg = ops.meanImg;
            else
                error('Unsupported file type: %s', ext);
            end

            % Lire le fichier TIFF
            image_tiff = imread(tif_file_path);
    
            % Aligner l'image
            reg_obj = imregcorr(image_tiff, meanImg, 'similarity');
            T = reg_obj.T;
            
            % Appliquer la transformation finale
            aligned_image = imwarp(image_tiff, affine2d(T), 'OutputView', imref2d(size(image_tiff)));
            aligned_image = normalize_image(aligned_image);

            % Sauvegarder l'image alignée
            aligned_image_path = fullfile(path, ['aligned_', file_name, '.tif']);
            imwrite(aligned_image, aligned_image_path, 'tif');
            fprintf('Image alignée sauvegardée : %s\n', aligned_image_path);
            
            % Normalisation des images avant l'animation
            image_tiff = normalize_image(image_tiff);

            % Animation avant de lancer Cellpose
            display_animation(image_tiff, aligned_image);
            
            launch_cellpose_from_matlab(aligned_image_path);

            % Vérifier si le fichier .npy existe après l'exécution de Cellpose
            [~, folder_name, ~] = fileparts(aligned_image_path);
            npy_file_name = [folder_name, '_seg.npy'];
            npy_file_path = fullfile(path, npy_file_name);
            if isfile(npy_file_path)
                npy_file_path = npy_file_path;
                fprintf('Fichier NPY trouvé et ajouté\n');
            else
                % Si aucun fichier NPY n'est trouvé, afficher un message
                disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
                npy_file_path = [];
            end
        end
    end
end