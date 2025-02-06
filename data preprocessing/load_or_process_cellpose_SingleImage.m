function [npy_file_paths, aligned_image] = load_or_process_cellpose_Singleimage(date_group_paths, all_ops)
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

    % Initialiser le cell array pour stocker les images alignées
    numFolders = length(date_group_paths);
    npy_file_paths = cell(numFolders, 1);
    
    % Boucle sur tous les dossiers
    for m = 1:numFolders
        % Définir le chemin des images
        path = fullfile(date_group_paths{m}, 'Single images');
        
        % Lister tous les fichiers .npy dans le répertoire
        npy_files = dir(fullfile(path, '*.npy'));
        npy_files_canal = npy_files(contains({npy_files.name}, canal_str));
        
        % Vérifier si des fichiers NPY sont disponibles pour ce canal
        if ~isempty(npy_files_canal)
            if numel(npy_files_canal) > 1
                % Si plusieurs fichiers existent, demander à l'utilisateur d'en choisir un parmi ceux qui contiennent le canal
                [selected_file, selected_path] = uigetfile({['*' canal_str '*.npy']}, ...
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

            % Créer le chemin du fichier TIFF aligné en remplaçant le suffixe _seg.npy par .tiff
            aligned_image_path = strrep(npy_file_path, '_seg.npy', '.tif');
            
            % Lire l'image alignée
            aligned_image = imread(aligned_image_path);
            aligned_image = normalize_image(aligned_image);
            
            % Ajouter le chemin du fichier NPY à la liste (si nécessaire)
            npy_file_paths{m} = npy_file_path;

        else
            % Si aucun fichier NPY n'existe, passer aux fichiers TIF
            tif_files = dir(fullfile(path, '*.tif'));
            tif_files_canal = tif_files(contains({tif_files.name}, canal_str));
            
            % Vérifier si des fichiers TIF sont disponibles pour ce canal
            if isempty(tif_files_canal)
                % Aucun fichier TIF trouvé, afficher un message et passer à l'itération suivante
                disp(['Aucun fichier contenant "', canal_str, '" trouvé dans le répertoire spécifié. Passage au suivant.']);
                continue;  % Passer à l'itération suivante du processus
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
                    npy_file_paths{m} = npy_file_path;
                    fprintf('Fichier NPY trouvé et ajouté\n');
                else
                    % Si aucun fichier NPY n'est trouvé, afficher un message
                    disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
                end

            else
                % Si le fichier n'est pas aligné, procéder à l'alignement
                output_path = fullfile(path, ['aligned_', file_name, '.tif']);
                % Vérifier si all_ops{m} est un dictionnaire Python
                if isa(all_ops{m}, 'py.dict')
                    ops = all_ops{m}; % Python dictionary
                    meanImg = double(ops{'meanImg'}); % Convertir en tableau MATLAB
                else
                    ops = all_ops{m}; % Structure MATLAB
                    meanImg = ops.meanImg;
                end
                
                % Lire le fichier TIFF
                image_tiff = imread(tif_file_path);
        
                % Aligner l'image
                reg_obj = imregcorr(image_tiff, meanImg, 'similarity');
                T = reg_obj.T;
                
                % Appliquer la transformation finale
                aligned_image = imwarp(image_tiff, affine2d(T), 'OutputView', imref2d(size(image_tiff)));
                
                % Sauvegarder l'image alignée
                imwrite(aligned_image, output_path, 'tif');
                fprintf('Image alignée sauvegardée : %s\n', output_path);
                
                % Normalisation des images avant l'animation
                image_tiff = normalize_image(image_tiff);
                aligned_image = normalize_image(aligned_image);

                % Animation avant de lancer Cellpose
                display_animation(image_tiff, aligned_image);
                
                launch_cellpose_from_matlab(output_path);

                % Vérifier si le fichier .npy existe après l'exécution de Cellpose
                [~, folder_name, ~] = fileparts(output_path);
                npy_file_name = [folder_name, '_seg.npy'];
                npy_file_path = fullfile(path, npy_file_name);
                if isfile(npy_file_path)
                    npy_file_paths{m} = npy_file_path;
                    fprintf('Fichier NPY trouvé et ajouté\n');
                else
                    % Si aucun fichier NPY n'est trouvé, afficher un message
                    disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
                end
            end
        end
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

    % Ouvrir l'interface graphique de Cellpose
    fprintf('Lancement de Cellpose avec l''interface graphique pour traiter l''image : %s\n', image_path);
    system('cellpose');  % Lancer Cellpose avec l'interface graphique
end
