function [meanImg_channels, aligned_image, npy_file_path, meanImg] = load_or_process_cellpose_TSeries(filePath, folders_groups, date_group_path, numChannels, m)
    % Initialisation
    meanImg_channels = cell(numChannels, 1);
    aligned_image = [];
    npy_file_path = [];
    meanImg = [];
    
    % ==== Cas principal : chercher dans folders_groups ====
    current_blue_folders_group = folders_groups{3}{:, 1};
    disp(current_blue_folders_group);

    if isempty(current_blue_folders_group)
        % ---- Cas : pas de blue group → chercher dans Single images ----
        path = fullfile(date_group_path, 'Single images');
        canal_str = 'Ch3';
        
        % 1) Essayer avec Cellpose (_seg.npy)
        cellpose_files = dir(fullfile(path, '*_seg.npy'));
        cellpose_files_canal = cellpose_files(contains({cellpose_files.name}, canal_str));
        
        if ~isempty(cellpose_files_canal)
            npy_file_path = select_or_default(cellpose_files_canal, canal_str, '*.npy');
            if ~isempty(npy_file_path)
                aligned_image_path = strrep(npy_file_path, '_seg.npy', '.tif');
                if isfile(aligned_image_path)
                    aligned_image = normalize_image(imread(aligned_image_path));
                end
            end
        
        else
            % 2) Sinon → chercher fichiers TIF
            tif_files = dir(fullfile(path, '*.tif'));
            tif_files_canal = tif_files(contains({tif_files.name}, canal_str));
            
            if isempty(tif_files_canal)
                disp(['Aucun fichier contenant "', canal_str, '" trouvé.']);
                return;
            end
            
            % Chercher fichiers alignés
            aligned_files = tif_files(~cellfun('isempty', regexp({tif_files.name}, ['^aligned_.*_' canal_str '(_|\.)'])));
            if ~isempty(aligned_files)
                aligned_image_path = select_or_default(aligned_files, canal_str, '*.tif');
                aligned_image = normalize_image(imread(aligned_image_path));
                
                % Récupérer l'image brute et lancer l'animation
                tif_file_path = select_or_default(tif_files_canal, canal_str, '*.tif');
                image_tiff = normalize_image(imread(tif_file_path));

                display_animation(image_tiff, aligned_image);

                % Lancer Cellpose
                npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
            else
                % Aligner à partir d'une image brute
                tif_file_path = select_or_default(tif_files_canal, canal_str, '*.tif');
                image_tiff = normalize_image(imread(tif_file_path));
                
                % Charger ops / meanImg
                [meanImg, meanImg_channels] = load_ops_or_mat(folders_groups{1}{:, 1}, filePath, numChannels);
                canal_idx = str2double(erase(canal_str, 'Ch'));
                meanImg_channels{canal_idx} = image_tiff;
                
                % Alignement
                reg_obj = imregcorr(image_tiff, meanImg, 'similarity');
                T = reg_obj.T;
                aligned_image = normalize_image(imwarp(image_tiff, affine2d(T), 'OutputView', imref2d(size(image_tiff))));
                
                % Sauvegarde
                [~, file_name, ~] = fileparts(tif_file_path);
                aligned_image_path = fullfile(path, ['aligned_', file_name, '.tif']);
                imwrite(aligned_image, aligned_image_path, 'tif');
                
                % Animation
                display_animation(image_tiff, aligned_image);
                
                % Lancer Cellpose
                npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
            end
        end

    else
        % ---- Cas : blue group existant ----
        try
            cellpose_files = dir(fullfile(current_blue_folders_group, '*_seg.npy'));
            aligned_image_path = fullfile(current_blue_folders_group, 'aligned_image.tif');
            
            if ~isempty(cellpose_files)
                npy_file_path = select_or_default(cellpose_files, '', '*.npy');
                if isfile(aligned_image_path)
                    aligned_image = imread(aligned_image_path);
                end
            elseif isfile(aligned_image_path)
                aligned_image = normalize_image(imread(aligned_image_path));
                for j = 1:numChannels
                    tif_file_path = string(folders_groups{j}{m, 1});
                    [meanImg, ~] = load_ops_or_mat(tif_file_path, '', numChannels);
                    meanImg_channels{j} = meanImg;
                end
                display_animation(meanImg_channels{4}, aligned_image);

                npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
            else
                % Recalcul meanImg_channels
                for j = 1:numChannels
                    tif_file_path = string(folders_groups{j}{m, 1});
                    [meanImg, ~] = load_ops_or_mat(tif_file_path, '', numChannels);
                    meanImg_channels{j} = meanImg;
                end

                % Alignement si possible
                % ==============================================================
                % Récapitulatif des alignements de canaux
                %
                % Cas "Single images"
                %   - Référence (fixe) : GCaMP (Canal 1)
                %   - Canal aligné     : Bleu (Canal 3)
                %   - Commentaire      : le Bleu est aligné directement sur le GCaMP
                %
                % Cas "Blue group existant"
                %   - Référence (fixe) : GCaMP (Canal 1)
                %   - Canal aligné     : Vert (Canal 4), puis Bleu (Canal 3)
                %   - Commentaire      : le Vert est aligné sur GCaMP ; 
                %                        le Bleu est transformé avec la même matrice 
                %                        que le Vert → donc indirectement aligné sur GCaMP
                %
                % Conclusion : le GCaMP (Canal 1) sert toujours de référence
                % ============================================================== 

                if ~isempty(meanImg_channels{1}) && ~isempty(meanImg_channels{4})
                    reg_obj = imregcorr(meanImg_channels{4}, meanImg_channels{1}, 'similarity');
                    T = reg_obj.T;
                    aligned_image = normalize_image(imwarp(meanImg_channels{3}, affine2d(T), 'OutputView', imref2d(size(meanImg_channels{3}))));
                    imwrite(aligned_image, aligned_image_path, 'tif');
                    display_animation(meanImg_channels{4}, aligned_image);
                    npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                end
            end
        catch ME
            disp(ME.message);
        end
    end

    % ==== Post-traitement : compléter meanImg_channels ====
    [meanImg_channels, meanImg] = complete_meanImg_channels(meanImg_channels, filePath, folders_groups, m, numChannels, meanImg);
end


% ==== Fonctions utilitaires locales ==================================

function path_out = select_or_default(files, canal_str, pattern)
    if numel(files) > 1
        [selected_file, selected_path] = uigetfile({['*' canal_str pattern]}, ...
            ['Plusieurs fichiers "', canal_str, '" trouvés. Veuillez sélectionner :'], ...
            fullfile(files(1).folder, files(1).name));
        if isequal(selected_file, 0)
            path_out = '';
            return;
        end
        path_out = fullfile(selected_path, selected_file);
    else
        path_out = fullfile(files(1).folder, files(1).name);
    end
end

function [meanImg, meanImg_channels] = load_ops_or_mat(path_in, filePath, numChannels)
    meanImg = [];
    meanImg_channels = cell(numChannels,1);
    [~, ~, ext] = fileparts(path_in);
    files = dir(fullfile(path_in, '*.npy'));
    if ~isempty(files)
        newOpsPath = fullfile(path_in, 'ops.npy');
        try
            mod = py.importlib.import_module('python_function');
            ops = mod.read_npy_file(newOpsPath);
            meanImg = double(ops{'meanImg'});
        catch
            disp('Erreur lors du chargement ops.npy');
        end
    elseif strcmp(ext, '.mat')
        data = load(path_in);
        if isfield(data, 'ops')
            meanImg = data.ops.meanImg;
        end
    elseif exist(filePath, 'file') == 2
        data = load(filePath);
        if isfield(data, 'meanImg_channels')
            meanImg_channels = data.meanImg_channels;
            meanImg = meanImg_channels{1};
        end
    end
end

function [meanImg_channels, meanImg] = complete_meanImg_channels(meanImg_channels, filePath, folders_groups, m, numChannels, meanImg)
    try
        % Charger depuis filePath si c'est un .mat
        if exist(filePath, 'file') == 2
            data = load(filePath);
            if isfield(data, 'meanImg_channels')
                for j = 1:numChannels
                    if isempty(meanImg_channels{j}) && j <= numel(data.meanImg_channels)
                        meanImg_channels{j} = data.meanImg_channels{j};
                    end
                end
            end
        end
        % Si encore vide, essayer folders_groups
        for j = 1:numChannels
            if isempty(meanImg_channels{j})
                tif_file_path = string(folders_groups{j}{m, 1});
                if exist(tif_file_path, 'file') == 2
                    [~, ~, ext] = fileparts(tif_file_path);
                    if strcmp(ext, '.mat')
                        tmp = load(tif_file_path);
                        if isfield(tmp, 'ops') && isfield(tmp.ops, 'meanImg')
                            meanImg_channels{j} = tmp.ops.meanImg;
                        end
                    elseif strcmp(ext, '.tif')
                        tmp = imread(tif_file_path);
                        meanImg_channels{j} = normalize_image(tmp);
                    end
                end
            end
        end
        % Définir meanImg par défaut
        if isempty(meanImg) && ~isempty(meanImg_channels{1})
            meanImg = meanImg_channels{1};
        end
    catch ME
        disp('Erreur lors du post-traitement meanImg_channels :');
        disp(ME.message);
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

function npy_file_path = launch_cellpose_from_matlab(image_path)
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
        npy_file_path = [];
    end
   
    % Vérifier si le fichier .npy existe après l'exécution de Cellpose
    [parent_folder, folder_name, ~] = fileparts(image_path);
    npy_file_name = [folder_name, '_seg.npy'];
    npy_file_path = fullfile(parent_folder, npy_file_name);
    if isfile(npy_file_path)
        npy_file_path = npy_file_path;
        fprintf('Fichier NPY trouvé et ajouté\n');
    else
        % Si aucun fichier NPY n'est trouvé, afficher un message
        disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
        npy_file_path = [];
    end
end
