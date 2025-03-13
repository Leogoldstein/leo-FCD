function [meanImg_channels, aligned_image, npy_file_path, meanImg] = load_or_process_cellpose_TSeries(folders_groups, blue_output_folder, date_group_path, numChannels, m)
    % Initialisation des variables
    meanImg_channels = cell(numChannels, 1);
    aligned_image = [];  % Valeur par défaut pour éviter les erreurs d'affectation
    npy_file_path = [];
    meanImg = [];

    % Vérifier si le dossier date_group_path existe
    disp(blue_output_folder)
    if isempty(blue_output_folder)
        path = fullfile(date_group_path, 'Single images');
        if isfolder(path)
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
                
                if ~isempty(npy_file_path)
                    % Créer le chemin du fichier TIFF aligné en remplaçant le suffixe _seg.npy par .tiff
                    aligned_image_path = strrep(npy_file_path, '_seg.npy', '.tif');
                    
                    % Lire l'image alignée
                    aligned_image = imread(aligned_image_path);
                    aligned_image = normalize_image(aligned_image);
                end
            else
                % Si aucun fichier NPY n'existe, passer aux fichiers TIF
                tif_files = dir(fullfile(path, '*.tif'));
                tif_files_canal = tif_files(contains({tif_files.name}, canal_str));
                
                % Vérifier si des fichiers TIF sont disponibles pour ce canal
                if isempty(tif_files_canal)
                    disp(['Aucun fichier contenant "', canal_str, '" trouvé dans le répertoire spécifié.']);
                    return;
                elseif numel(tif_files_canal) > 1
                    % Si plusieurs fichiers existent, demander à l'utilisateur d'en choisir un parmi ceux qui contiennent le canal
                    [selected_file, selected_path] = uigetfile({['*' canal_str '*.tif']}, ...
                        ['Plusieurs fichiers "', canal_str, '" trouvés. Veuillez sélectionner un fichier :'], ...
                        fullfile(tif_files_canal(1).folder, tif_files_canal(1).name));
                    if isequal(selected_file, 0)
                        error('Aucun fichier sélectionné. Opération annulée.');
                    end
                    tif_file_path = fullfile(selected_path, selected_file);
                else
                    % S'il n'y a qu'un seul fichier, l'utiliser directement
                    tif_file_path = fullfile(tif_files_canal(1).folder, tif_files_canal(1).name);
                end
                
                % Vérifier si le fichier est déjà aligné (commence par 'aligned_')
                [~, file_name, ~] = fileparts(tif_file_path);
                aligned_image_path = fullfile(path, ['aligned_', file_name, '.tif']);
                
                if isfile(aligned_image_path)
                    % Si le fichier est déjà aligné, charger l'image alignée
                    aligned_image = imread(aligned_image_path);
                    fprintf('Fichier déjà aligné trouvé, chargé : %s\n', aligned_image_path);

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
                    end
                else
                    % Charger l'image TIFF originale
                    image_tiff = imread(tif_file_path);
                    image_tiff = normalize_image(image_tiff);

                    % Appliquer un alignement de l'image si nécessaire
                    currentFolder = folders_group{1}{:, 1};
                    [~, ~, ext] = fileparts(currentFolder);
                    files = dir(fullfile(currentFolder, '*.npy'));
                    
                    if ~isempty(files)
                        newOpsPath = fullfile(currentFolder, 'ops.npy');
                        try
                            mod = py.importlib.import_module('python_function');
                            ops = mod.read_npy_file(newOpsPath);
                            meanImg = double(ops{'meanImg'});
                        catch ME
                            disp('Erreur lors de l''appel de la fonction Python :');
                            disp(ME.message);
                        end

                    elseif strcmp(ext, '.mat')
                        % Load .mat files
                        data = load(currentFolder);
                        ops = data.ops;
                        meanImg = ops.meanImg;
                    else
                        error('Unsupported file type: %s', ext);
                    end

                    meanImg_channels{1} = meanImg;                   
                    meanImg_channels{canal} = image_tiff; 
                    save(fullfile(path, 'meanImg_channels.mat'), 'meanImg_channels');

                    % Aligner l'image
                    reg_obj = imregcorr(image_tiff, meanImg, 'similarity');
                    T = reg_obj.T;
                    aligned_image = imwarp(image_tiff, affine2d(T), 'OutputView', imref2d(size(image_tiff)));
                    aligned_image = normalize_image(aligned_image);

                    % Sauvegarder l'image alignée
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
                    end
                end  
            end
             if isempty(meanImg_channels{1})
                 filePath = fullfile(path, 'meanImg_channels.mat');          
                     if exist(filePath, 'file') == 2
                        data = load(filePath);
                        if isfield(data, 'meanImg_channels')
                            for j = 1:numChannels
                                % Vérifier si la cellule est vide avant d'assigner
                                if ~isempty(data.meanImg_channels{j})
                                    % Assigner l'image (en conservant le type d'origine)
                                    meanImg_channels{j,:} = data.meanImg_channels{j};
                                else      
                                    meanImg_channels{j,:} = [];
                                end
                            end
                            meanImg = meanImg_channels{1};
                        end
                     end
            end
        end
    else
        try
            cellpose_files = dir(fullfile(blue_output_folder, '*_seg.npy'));
            aligned_image_path = fullfile(blue_output_folder, 'aligned_image.tif');
            npy_file_path = [];
            
            split_path = strsplit(blue_output_folder, filesep); 
            base_path = fullfile(split_path{1:7});
            disp(base_path)
            
            if ~isempty(cellpose_files)                
                if numel(cellpose_files) > 1
                    [selected_file, selected_path] = uigetfile(fullfile(blue_output_folder, '*.npy'), ...
                        'Sélectionnez un fichier .npy');
                    if isequal(selected_file, 0)
                        error('Aucun fichier sélectionné. Opération annulée.');
                    end
                    npy_file_path = fullfile(selected_path, selected_file);
                else
                    npy_file_path = fullfile(cellpose_files(1).folder, cellpose_files(1).name);
                    disp(['Fichier NPY trouvé directement dans : ', npy_file_path]);
                end
                
                if isfile(aligned_image_path) 
                    aligned_image = imread(aligned_image_path);
                     fprintf('Fichier aligné chargé : %s\n', aligned_image_path);
                end

            elseif isfile(aligned_image_path)
                    aligned_image = imread(aligned_image_path);
                    fprintf('Fichier aligné chargé : %s\n', aligned_image_path);
                    
                    filePath = fullfile(base_path, 'meanImg_channels.mat');          
                    if exist(filePath, 'file') == 2
                        data = load(filePath);
                        if isfield(data, 'meanImg_channels')
                            meanImg_channels = data.meanImg_channels;
                            meanImg = meanImg_channels{4};
                        else
                            disp('Impossible to access to meanImg_channels.');
                        end
                    end
                    image_tiff = imread(meanImg);
                    display_animation(image_tiff, aligned_image);
                    launch_cellpose_from_matlab(aligned_image_path); 

                    % Vérifier si le fichier .npy existe après l'exécution de Cellpose
                    if isfile(npy_file_path)
                        npy_file_path = npy_file_path;
                        fprintf('Fichier NPY trouvé et ajouté\n');
                    else
                        % Si aucun fichier NPY n'est trouvé, afficher un message
                        disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
                    end
            
            else
                for j = 1:numChannels
        
                    tif_file_path = string(folders_groups{j}{m, 1});
                    [~, ~, ext] = fileparts(tif_file_path);
                    files = dir(fullfile(tif_file_path, '*.npy'));
                    
                    if ~isempty(files)
                        newOpsPath = fullfile(tif_file_path, 'ops.npy');
                        mod = py.importlib.import_module('python_function');
                        py.importlib.import_module('numpy');
                        ops = mod.read_npy_file(newOpsPath);
                        meanImg = double(ops{'meanImg'});
                    elseif strcmp(ext, '.mat')
                        data = load(tif_file_path);
                        ops = data.ops;
                        meanImg = ops.meanImg;
                    else
                        % Add a message if no .npy files are found
                        disp(['Le fichier est introuvable: ', tif_file_path]);
                    end
                    
                    meanImg_channels{j} = meanImg;
                    save(fullfile(base_path, 'meanImg_channels.mat'), 'meanImg_channels');
                end
                
                if all(cellfun(@(x) ~isempty(x) && isnumeric(x), {meanImg_channels{1}, meanImg_channels{4}}))
                    try
                        reg_obj = imregcorr(meanImg_channels{4}, meanImg_channels{1}, 'similarity');
                        T = reg_obj.T;
                        
                        if ~isempty(meanImg_channels{3}) && isnumeric(meanImg_channels{3})
                            aligned_image = imwarp(meanImg_channels{3}, affine2d(T), 'OutputView', imref2d(size(meanImg_channels{3}))); 
                            not_aligned_image = meanImg_channels{4};
                            aligned_image = normalize_image(aligned_image);
                            imwrite(aligned_image, aligned_image_path, 'tif');
                            fprintf('Image alignée sauvegardée : %s\n', aligned_image_path);
                            display_animation(not_aligned_image, aligned_image);
                            launch_cellpose_from_matlab(aligned_image_path);

                            % Vérifier si le fichier .npy existe après l'exécution de Cellpose
                            if isfile(npy_file_path)
                                npy_file_path = npy_file_path;
                                fprintf('Fichier NPY trouvé et ajouté\n');
                            else
                                % Si aucun fichier NPY n'est trouvé, afficher un message
                                disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
                            end

                        else
                            warning('meanImg_channels{3} est vide ou invalide.');
                        end
                    catch ME
                        disp('Erreur lors de l''alignement des images :');
                        disp(ME.message);
                    end
                else
                    warning('Problème avec meanImg_channels{1} ou meanImg_channels{4}, impossible d’aligner.');
                end
            end
            
            if isempty(meanImg_channels{1})
                 filePath = fullfile(base_path, 'meanImg_channels.mat');          
                 if exist(filePath, 'file') == 2
                    data = load(filePath);
                    if isfield(data, 'meanImg_channels')
                        for j = 1:numChannels
                            % Vérifier si la cellule est vide avant d'assigner
                            if ~isempty(data.meanImg_channels{j})
                                % Assigner l'image (en conservant le type d'origine)
                                meanImg_channels{j,:} = data.meanImg_channels{j};
                            else      
                                meanImg_channels{j,:} = [];
                            end
                        end
                        meanImg = meanImg_channels{1};
                    end
                 end
            end

        catch ME           
            disp(ME.message);
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
    % This function configures the Python environment for Cellpose and launches Cellpose from MATLAB with the graphical interface.
    %
    % Arguments:
    %   - image_path: The path to the image to be processed (in .tif or .png format).
    % Example:
    %   launch_cellpose_from_matlab('C:\path\to\image.png');

    % Path to the Python executable in the Cellpose Conda environment
    pyExec = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe';  % Update with your own path

    % Check if the Python environment is already configured
    currentPyEnv = pyenv;  % Do not pass arguments to pyenv
    if ~strcmp(currentPyEnv.Version, pyExec)
        % If the Python environment is not the one we want, configure it
        pyenv('Version', pyExec);  % Configure the Python environment
    end

    % Check if the Python environment is properly configured
    try
        py.print("Python is working with Cellpose!");
    catch
        error('Error: Python is not properly configured in MATLAB.');
    end

    % Add Cellpose path to the PATH if necessary
    setenv('PATH', [getenv('PATH') ';C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts']);
    
    % Ask the user if they want to launch Cellpose
    answer = questdlg('Do you want to launch Cellpose to process this image?', ...
        'Launch Cellpose', 'Yes', 'No', 'No');
    
    % If the user answers "Yes", launch Cellpose
    if strcmp(answer, 'Yes')
        % Launch the Cellpose graphical interface
        fprintf('Launching Cellpose with the graphical interface to process the image: %s\n', image_path);
        cellposePath = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts\cellpose.exe';  % Specify the absolute path
        system(cellposePath);  % Launch Cellpose with the graphical interface
    else
        fprintf('Cellpose was not launched. Process canceled.\n');
    end
end
