function [meanImg_channels, aligned_image, npy_file_path, meanImg] = ...
    load_or_process_cellpose_TSeries(filePath, date_group_path, ...
                                     current_gcamp_folders_group, ...
                                     current_red_folders_group, ...
                                     current_blue_folders_group, ...
                                     current_green_folders_group, ...
                                     current_blue_TSeries_path, p)

    % ----- Paramètres locaux -----
    numChannelsLocal = 4;  % 1=GCaMP, 2=Red, 3=Blue, 4=Green

    % Initialisation
    meanImg_channels = cell(numChannelsLocal, 1);
    aligned_image    = [];
    npy_file_path    = [];
    meanImg          = [];

    % ==========================================================
    %  Accès au plan p pour GCaMP / Red / Blue / Green
    % ==========================================================
    current_gcamp_folders_group_plane  = [];
    current_red_folders_group_plane    = [];
    current_blue_folders_group_plane   = [];
    current_green_folders_group_plane  = [];

    if ~isempty(current_gcamp_folders_group) && numel(current_gcamp_folders_group) >= p
        current_gcamp_folders_group_plane = current_gcamp_folders_group{p};
    end
    if ~isempty(current_red_folders_group) && numel(current_red_folders_group) >= p
        current_red_folders_group_plane = current_red_folders_group{p};
    end
    if ~isempty(current_blue_folders_group) && numel(current_blue_folders_group) >= p
        current_blue_folders_group_plane = current_blue_folders_group{p};
    end
    if ~isempty(current_green_folders_group) && numel(current_green_folders_group) >= p
        current_green_folders_group_plane = current_green_folders_group{p};
    end

    if iscell(current_blue_TSeries_path)
        if isempty(current_blue_TSeries_path)
            current_blue_TSeries_path = "";
        else
            current_blue_TSeries_path = current_blue_TSeries_path{1};
        end
    end

    % ==========================================================
    %  0) Pré-remplissage des meanImg_channels à partir des dossiers suite2p
    % ==========================================================
    % GCaMP → canal 1
    if ~isempty(current_gcamp_folders_group_plane)
        tmp = load_meanImg_from_path(current_gcamp_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{1} = tmp;
            meanImg             = tmp;
        end
    end

    % Red → canal 2
    if ~isempty(current_red_folders_group_plane)
        tmp = load_meanImg_from_path(current_red_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{2} = tmp;
        end
    end

    % Blue → canal 3 (si suite2p Blue existe)
    if ~isempty(current_blue_folders_group_plane)
        tmp = load_meanImg_from_path(current_blue_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{3} = tmp;
        end
    end

    % Green → canal 4
    if ~isempty(current_green_folders_group_plane)
        tmp = load_meanImg_from_path(current_green_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{4} = tmp;
        end
    end

    % Si meanImg est encore vide mais canal 1 rempli → utiliser canal 1 comme ref globale
    if isempty(meanImg) && ~isempty(meanImg_channels{1})
        meanImg = meanImg_channels{1};
    end

    % ==========================================================
    %  CAS 1 : pas de blue group suite2p → chercher dans "Single images" ou Blue\plane*
    % ==========================================================
    if isempty(current_blue_folders_group_plane)
        path      = fullfile(date_group_path, 'Single images');
        canal_str = 'Ch3';  % canal Blue

        if exist(path, 'dir')
            % 1) Essayer avec Cellpose (_seg.npy dans Single images)
            cellpose_files       = dir(fullfile(path, '*_seg.npy'));
            cellpose_files_canal = cellpose_files(contains({cellpose_files.name}, canal_str));

            if ~isempty(cellpose_files_canal)
                % On a directement un .npy
                npy_file_path = select_or_default(cellpose_files_canal, canal_str, '*.npy');
                if ~isempty(npy_file_path)
                    aligned_image_path = strrep(npy_file_path, '_seg.npy', '.tif');
                    if isfile(aligned_image_path)
                        aligned_image = normalize_image(imread(aligned_image_path));

                        % Version brute (sans "aligned_") pour l'animation
                        [pth, name, ext] = fileparts(aligned_image_path);
                        name          = regexprep(name, '^aligned_', '');
                        tif_file_path = fullfile(pth, [name ext]);
                        if isfile(tif_file_path)
                            image_tiff = normalize_image(imread(tif_file_path));
                            if isempty(meanImg_channels{3})
                                meanImg_channels{3} = image_tiff;
                            end
                            display_animation(image_tiff, aligned_image);
                        end
                    end
                end

            else
                % 2) Sinon → chercher fichiers TIF
                tif_files       = dir(fullfile(path, '*.tif'));
                tif_files_canal = tif_files(contains({tif_files.name}, canal_str));

                if isempty(tif_files_canal)
                    disp(['Aucun fichier contenant "', canal_str, '" trouvé.']);
                end

                % Chercher fichiers alignés existants
                aligned_files = tif_files(~cellfun('isempty', ...
                    regexp({tif_files.name}, ['^aligned_.*_' canal_str '(_|\.)'])));

                if ~isempty(aligned_files)
                    % On a déjà une image alignée
                    aligned_image_path = select_or_default(aligned_files, canal_str, '*.tif');
                    aligned_image      = normalize_image(imread(aligned_image_path));

                    % Récupérer l'image brute et lancer l'animation
                    tif_file_path = select_or_default(tif_files_canal, canal_str, '*.tif');
                    if isempty(tif_file_path)
                        disp(['Aucun fichier "', canal_str, '" sélectionné ou trouvé.']);
                    else
                        image_tiff = normalize_image(imread(tif_file_path));
                        if isempty(meanImg_channels{3})
                            meanImg_channels{3} = image_tiff;
                        end
                        display_animation(image_tiff, aligned_image);
                    end

                    % Lancer Cellpose sur cette image alignée
                    npy_file_path = launch_cellpose_from_matlab(aligned_image_path);

                else
                    % 3) Aucun alignement existant → aligner à partir d'une image brute
                    tif_file_path = select_or_default(tif_files_canal, canal_str, '*.tif');
                    if isempty(tif_file_path)
                        disp(['Aucun fichier "', canal_str, '" sélectionné ou trouvé.']);
                    else
                        image_tiff = normalize_image(imread(tif_file_path));

                        % Charger meanImg GCaMP si pas déjà dispo
                        if isempty(meanImg) && ~isempty(current_gcamp_folders_group_plane)
                            tmp = load_meanImg_from_path(current_gcamp_folders_group_plane);
                            if ~isempty(tmp)
                                meanImg = tmp;
                                meanImg_channels{1} = tmp;
                            end
                        end

                        % Si on n'a toujours pas de meanImg, on prend l'image brute comme ref
                        if isempty(meanImg)
                            meanImg = image_tiff;
                        end

                        % On met l'image Blue dans le canal 3
                        meanImg_channels{3} = image_tiff;

                        % Sauvegarde du chemin aligné
                        [~, file_name, ~] = fileparts(tif_file_path);
                        aligned_image_path = fullfile(path, ['aligned_', file_name, '.tif']);

                        % === Recalage via fonction dédiée (zones sombres) ===
                        aligned_image = register_blue_with_dark_zones( ...
                            image_tiff, meanImg, aligned_image_path, ...
                            'SingleImages Ch3 vs meanImg');

                        % Animation
                        if ~isempty(aligned_image)
                            display_animation(image_tiff, aligned_image);
                            % Lancer Cellpose
                            npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        else
                            npy_file_path = [];
                        end
                    end
                end
            end

        else
            % Pas de dossier "Single images" → on travaille dans le dossier du plan 'plane<p-1>'
            planeFolderName = sprintf('plane%d', p-1);
            current_blue_TSeries_path_plane = fullfile(current_blue_TSeries_path, planeFolderName);
            
            % Si le sous-dossier plane<p-1> n'existe pas, on retombe sur le dossier \Blue\
            if ~isfolder(current_blue_TSeries_path_plane)
                warning('Blue plane folder not found: %s  → fallback to %s', ...
                        current_blue_TSeries_path_plane, current_blue_TSeries_path);
                current_blue_TSeries_path_plane = current_blue_TSeries_path;
            end
        
            %------------------------------------------------------%
            % 1) Chercher un fichier *_seg.npy spécifique à CE plan
            %    ex: aligned_plane0_AVG_seg.npy
            %------------------------------------------------------%
            segPattern = sprintf('aligned_%s_AVG*_seg.npy', planeFolderName);
            segFiles   = dir(fullfile(current_blue_TSeries_path_plane, segPattern));
        
            if ~isempty(segFiles)
                % --- CAS A : on a déjà un *_seg.npy pour ce plan ---
                npy_file_path = fullfile(current_blue_TSeries_path_plane, segFiles(1).name);
        
                % En déduire l'image TIFF alignée correspondante :
                %   aligned_plane0_AVG_seg.npy -> aligned_plane0_AVG.tif
                [segDir, segName, ~] = fileparts(npy_file_path);
                baseName = regexprep(segName, '_seg$', '');
                aligned_image_path = fullfile(segDir, [baseName '.tif']);
        
                if isfile(aligned_image_path)
                    aligned_image = normalize_image(imread(aligned_image_path));
        
                    % Optionnel : charger l'image AVG brute pour animation
                    avgPattern = sprintf('plane%d_AVG*.tif', p-1);
                    avgFiles   = dir(fullfile(current_blue_TSeries_path_plane, avgPattern));
                    if ~isempty(avgFiles)
                        avg_path = fullfile(current_blue_TSeries_path_plane, avgFiles(1).name);
                        blue_img = normalize_image(imread(avg_path));
                        if isempty(meanImg_channels{3})
                            meanImg_channels{3} = blue_img;
                        end
                        display_animation(blue_img, aligned_image);
                    end
                else
                    warning('Aligned TIFF not found for %s (expected: %s)', ...
                            npy_file_path, aligned_image_path);
                end
        
            else
                %------------------------------------------------------%
                % 2) Pas de *_seg.npy → chercher une image alignée existante
                %    ex: aligned_plane0_AVG*.tif
                %------------------------------------------------------%
                alignedPattern = sprintf('aligned_plane%d_AVG*.tif', p-1);
                alignedFiles   = dir(fullfile(current_blue_TSeries_path_plane, alignedPattern));
            
                if ~isempty(alignedFiles)
                    % --- CAS B : une image alignée existe déjà ---
                    aligned_image_path = fullfile(current_blue_TSeries_path_plane, alignedFiles(1).name);
                    aligned_image      = normalize_image(imread(aligned_image_path));
            
                    % Optionnel : animation avec l'AVG brute si dispo
                    avgPattern = sprintf('plane%d_AVG*.tif', p-1);
                    avgFiles   = dir(fullfile(current_blue_TSeries_path_plane, avgPattern));
                    if ~isempty(avgFiles)
                        avg_path = fullfile(current_blue_TSeries_path_plane, avgFiles(1).name);
                        blue_img = normalize_image(imread(avg_path));
                        if isempty(meanImg_channels{3})
                            meanImg_channels{3} = blue_img;
                        end
                        display_animation(blue_img, aligned_image);
                    end
            
                    % Lancer Cellpose sur l'image alignée
                    npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
        
                else
                    %------------------------------------------------------%
                    % 3) Ni *_seg.npy, ni aligned_*.tif :
                    %    utiliser plane<p-1>_AVG*.tif et recaler sur meanImg GCaMP
                    %    (en utilisant les zones sombres)
                    %------------------------------------------------------%
                    avgPattern = sprintf('plane%d_AVG*.tif', p-1);
                    avgFiles   = dir(fullfile(current_blue_TSeries_path_plane, avgPattern));
                
                    if isempty(avgFiles)
                        fprintf('No seg, no aligned image, no %s in %s\n', ...
                                avgPattern, current_blue_TSeries_path_plane);
                        % Rien trouvé : on laisse npy_file_path et aligned_image vides
                        npy_file_path = [];
                        aligned_image = [];
                    else
                        avg_path = fullfile(current_blue_TSeries_path_plane, avgFiles(1).name);
                        blue_img = normalize_image(imread(avg_path));
                        meanImg_channels{3} = blue_img;
                
                        % ===== Référence : GCaMP canal 1 =====
                        if isempty(meanImg_channels{1}) && ~isempty(current_gcamp_folders_group_plane)
                            meanImg_gcamp = load_meanImg_from_path(current_gcamp_folders_group_plane);
                            if ~isempty(meanImg_gcamp)
                                meanImg_channels{1} = meanImg_gcamp;
                                meanImg             = meanImg_gcamp;
                            end
                        end
                
                        ref_gcamp = meanImg_channels{1};
                        if isempty(ref_gcamp)
                            ref_gcamp = blue_img;  % fallback de sécurité
                        end

                        % Chemin de sauvegarde aligné
                        aligned_image_path = fullfile(current_blue_TSeries_path_plane, ...
                            sprintf('aligned_plane%d_AVG.tif', p-1));

                        % === Recalage via fonction dédiée (zones sombres) ===
                        aligned_image = register_blue_with_dark_zones( ...
                            blue_img, ref_gcamp, aligned_image_path, ...
                            sprintf('Blue AVG plane %d vs GCaMP', p-1));

                        if ~isempty(aligned_image)
                            display_animation(blue_img, aligned_image);
                            npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        else
                            npy_file_path = [];
                        end
                    end
                end
            end
        end


    % ==========================================================
    %  CAS 2 : blue group existant (Suite2p / plane*)
    % ==========================================================
    else
        try
            cellpose_files     = dir(fullfile(current_blue_folders_group_plane, '*_seg.npy'));
            aligned_image_path = fullfile(current_blue_folders_group_plane, ...
                            sprintf('aligned_plane%d_AVG.tif', p-1));

            if ~isempty(cellpose_files)
                % seg.npy déjà présent
                npy_file_path = select_or_default(cellpose_files, '', '*.npy');
                if isfile(aligned_image_path)
                    aligned_image = normalize_image(imread(aligned_image_path));
                end

            elseif isfile(aligned_image_path)
                % Image alignée présente mais pas encore de seg.npy
                aligned_image = normalize_image(imread(aligned_image_path));

                % Affichage de contrôle : on préfère le canal 4 (Green) si dispo,
                % sinon canal 1 (GCaMP)
                ref_disp = [];
                if ~isempty(meanImg_channels{4})
                    ref_disp = meanImg_channels{4};
                elseif ~isempty(meanImg_channels{1})
                    ref_disp = meanImg_channels{1};
                end
                if ~isempty(ref_disp)
                    display_animation(ref_disp, aligned_image);
                end

                npy_file_path = launch_cellpose_from_matlab(aligned_image_path);

                        else
                % Pas encore de seg.npy ni aligned_image → recalcul complet
                % On attend d'avoir Blue (canal 3) et une référence GCaMP (canal 1)

                % GCaMP canal 1 si pas encore rempli
                if isempty(meanImg_channels{1}) && ~isempty(current_gcamp_folders_group_plane)
                    tmp = load_meanImg_from_path(current_gcamp_folders_group_plane);
                    if ~isempty(tmp)
                        meanImg_channels{1} = tmp;
                    end
                end

                % Blue canal 3
                if isempty(meanImg_channels{3}) && ~isempty(current_blue_folders_group_plane)
                    tmp = load_meanImg_from_path(current_blue_folders_group_plane);
                    if ~isempty(tmp)
                        meanImg_channels{3} = tmp;
                    end
                end

                % === Référence = TOUJOURS GCaMP ===
                blue_img = meanImg_channels{3};
                ref_img  = meanImg_channels{1};  % GCaMP

                if isempty(blue_img) || isempty(ref_img)
                    warning('Impossible de déterminer Blue ou GCaMP pour le recalage (suite2p bleu).');
                else
                    % === Recalage via fonction dédiée (zones sombres) ===
                    aligned_image = register_blue_with_dark_zones( ...
                        blue_img, ref_img, aligned_image_path, ...
                        'Suite2p Blue vs GCaMP');

                    if ~isempty(aligned_image)
                        display_animation(ref_img, aligned_image);
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                    else
                        npy_file_path = [];
                    end
                end
            end

        catch ME
            disp(ME.message);
        end
    end

    % ==========================================================
    %  Post-traitement : compléter meanImg_channels / meanImg
    % ==========================================================
    [meanImg_channels, meanImg] = complete_meanImg_channels( ...
        meanImg_channels, filePath, current_gcamp_folders_group_plane, meanImg);
end

% =====================================================================
% ======================== HELPER FUNCTIONS ===========================
% =====================================================================

function aligned_image = register_blue_with_dark_zones(blue_img, ref_img, aligned_image_path, title_prefix)
    % Recalage Blue -> Ref en utilisant l'inversion et un masque de zones sombres
    % blue_img / ref_img : images 2D (double, uint16, etc.)
    % aligned_image_path : chemin où sauver l'image alignée (ou '' pour ne pas sauver)
    % title_prefix       : texte pour les titres de figure

    aligned_image = [];

    if isempty(blue_img) || isempty(ref_img)
        warning('register_blue_with_dark_zones: blue_img ou ref_img vide, recalage annulé.');
        return;
    end

    blue_img = double(blue_img);
    ref_img  = double(ref_img);

    % -----------------------------------------------------------------
    % 1) Affichage avant recalage
    % -----------------------------------------------------------------
    figure('Name',[title_prefix ' - BEFORE'],'Color','w');

    subplot(1,3,1);
    imagesc(blue_img); axis image off; colormap gray;
    title('Blue');

    subplot(1,3,2);
    imagesc(ref_img); axis image off; colormap gray;
    title('Reference');

    % -----------------------------------------------------------------
    % 2) Inversion + masques de zones sombres
    % -----------------------------------------------------------------
    blue_d = mat2gray(blue_img);
    ref_d  = mat2gray(ref_img);

    blue_inv = 1 - blue_d;
    ref_inv  = 1 - ref_d;

    th_ref  = graythresh(ref_inv);
    th_blue = graythresh(blue_inv);

    mask_ref  = ref_inv  > th_ref;
    mask_blue = blue_inv > th_blue;
    mask      = mask_ref & mask_blue;

    if nnz(mask) < 50
        warning(['Masque de zones sombres trop faible (', title_prefix, '), ', ...
                 'utilisation des images complètes pour l''alignement.']);
        blue_for_reg = blue_inv;
        ref_for_reg  = ref_inv;
    else
        blue_for_reg = blue_inv .* mask;
        ref_for_reg  = ref_inv  .* mask;
    end

    subplot(1,3,3);
    imagesc(mask); axis image off;
    title('Mask zones sombres');

    drawnow;

    % -----------------------------------------------------------------
    % 3) Recalage via imregcorr
    % -----------------------------------------------------------------
    try
        reg_obj = imregcorr(blue_for_reg, ref_for_reg, 'similarity');
        T       = reg_obj.T;
    catch ME
        warning('register_blue_with_dark_zones: imregcorr a échoué (%s).', ME.message);
        return;
    end

    aligned_image = normalize_image( ...
        imwarp(blue_img, affine2d(T), ...
               'OutputView', imref2d(size(blue_img))) );

    % -----------------------------------------------------------------
    % 4) Affichage après recalage
    % -----------------------------------------------------------------
    figure('Name',[title_prefix ' - AFTER'],'Color','w');

    subplot(1,2,1);
    imagesc(ref_img); axis image off; colormap gray;
    title('Reference');

    subplot(1,2,2);
    imagesc(aligned_image); axis image off; colormap gray;
    title('Blue aligned');

    drawnow;

    % -----------------------------------------------------------------
    % 5) Sauvegarde éventuelle
    % -----------------------------------------------------------------
    if ~isempty(aligned_image_path)
        try
            imwrite(aligned_image, aligned_image_path, 'tif');
        catch ME
            warning('register_blue_with_dark_zones: impossible de sauver %s (%s).', ...
                    aligned_image_path, ME.message);
        end
    end
end


function meanImg = load_meanImg_from_path(path_in)
    % Charge une meanImg à partir d'un dossier suite2p (ops.npy / ops.mat)
    % ou d'un fichier .mat contenant ops.meanImg

    meanImg = [];

    if isempty(path_in)
        return;
    end

    if isfolder(path_in)
        % 1) ops.npy (prioritaire)
        ops_npy = fullfile(path_in, 'ops.npy');
        if isfile(ops_npy)
            try
                mod = py.importlib.import_module('python_function');
                ops = mod.read_npy_file(ops_npy);
                meanImg = double(ops{'meanImg'});
                return;
            catch
                warning('Erreur lecture ops.npy dans %s', path_in);
            end
        end

        % 2) ops.mat
        ops_mat = fullfile(path_in, 'ops.mat');
        if isfile(ops_mat)
            S = load(ops_mat);
            if isfield(S,'ops') && isfield(S.ops,'meanImg')
                meanImg = S.ops.meanImg;
                return;
            end
        end
    end

    % 3) fichier .mat direct (Fall.mat ou autre contenant ops.meanImg)
    [~,~,ext] = fileparts(path_in);
    if strcmpi(ext,'.mat') && isfile(path_in)
        S = load(path_in);
        if isfield(S,'ops') && isfield(S.ops,'meanImg')
            meanImg = S.ops.meanImg;
            return;
        end
    end
end


function path_out = select_or_default(files, canal_str, pattern)
    if isempty(files)
        path_out = '';
        return;
    end

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


function [meanImg_channels, meanImg] = complete_meanImg_channels( ...
        meanImg_channels, filePath, gcamp_plane_path, meanImg)

    try
        % 1) Compléter à partir de filePath si c'est un .mat avec meanImg_channels
        if ~isempty(filePath) && exist(filePath, 'file') == 2
            data = load(filePath);
            if isfield(data, 'meanImg_channels')
                nLoc = numel(meanImg_channels);
                nSrc = numel(data.meanImg_channels);
                n    = min(nLoc, nSrc);
                for j = 1:n
                    if isempty(meanImg_channels{j})
                        meanImg_channels{j} = data.meanImg_channels{j};
                    end
                end
            end
        end

        % 2) Si toujours pas de meanImg, essayer via gcamp_plane_path
        if (isempty(meanImg) || (isnumeric(meanImg) && all(meanImg(:) == 0)))
            % priorité : canal 1 si déjà rempli
            if ~isempty(meanImg_channels) && numel(meanImg_channels) >= 1 && ...
                    ~isempty(meanImg_channels{1})
                meanImg = meanImg_channels{1};

            elseif ~isempty(gcamp_plane_path)
                [meanImg_tmp, meanImg_channels_tmp] = ...
                    load_ops_or_mat(gcamp_plane_path, filePath);

                if ~isempty(meanImg_tmp)
                    meanImg = meanImg_tmp;
                end
                if ~isempty(meanImg_channels_tmp)
                    % compléter uniquement les canaux vides
                    nLoc = numel(meanImg_channels);
                    nSrc = numel(meanImg_channels_tmp);
                    n    = min(nLoc, nSrc);
                    for j = 1:n
                        if isempty(meanImg_channels{j})
                            meanImg_channels{j} = meanImg_channels_tmp{j};
                        end
                    end
                    if isempty(meanImg) && ~isempty(meanImg_channels{1})
                        meanImg = meanImg_channels{1};
                    end
                end
            end
        end

    catch ME
        disp('Erreur lors du post-traitement meanImg_channels :');
        disp(ME.message);
    end
end


function [meanImg, meanImg_channels] = load_ops_or_mat(path_in, filePath)
    % Version générique que tu utilisais déjà,
    % gardée pour compatibilité avec d'autres parties du code.

    numChannelsLocal   = 4;
    meanImg            = [];
    meanImg_channels   = cell(numChannelsLocal, 1);

    if nargin < 2
        filePath = '';
    end

    [~, ~, ext] = fileparts(path_in);

    % --- Cas : dossier contenant des .npy (suite2p) ---
    if isfolder(path_in)
        files_npy = dir(fullfile(path_in, '*.npy'));
        if ~isempty(files_npy)
            newOpsPath = fullfile(path_in, 'ops.npy');
            try
                mod = py.importlib.import_module('python_function');
                ops = mod.read_npy_file(newOpsPath);
                meanImg = double(ops{'meanImg'});
                meanImg_channels{1} = meanImg;
            catch
                disp('Erreur lors du chargement ops.npy');
            end
        end
    end

    % --- Cas : fichier .mat direct (ops.mat, Fall.mat, autre) ---
    if isempty(meanImg) && strcmpi(ext, '.mat') && exist(path_in, 'file') == 2
        data = load(path_in);
        if isfield(data, 'ops') && isfield(data.ops, 'meanImg')
            meanImg = data.ops.meanImg;
            meanImg_channels{1} = meanImg;
        elseif isfield(data, 'meanImg_channels')
            meanImg_channels = data.meanImg_channels;
            if ~isempty(meanImg_channels) && ~isempty(meanImg_channels{1})
                meanImg = meanImg_channels{1};
            end
        end
    end

    % --- Cas : fallback vers filePath global ---
    if isempty(meanImg) && ~isempty(filePath) && exist(filePath, 'file') == 2
        data = load(filePath);
        if isfield(data, 'meanImg_channels')
            meanImg_channels = data.meanImg_channels;
            if ~isempty(meanImg_channels) && ~isempty(meanImg_channels{1})
                meanImg = meanImg_channels{1};
            end
        elseif isfield(data, 'ops') && isfield(data.ops, 'meanImg')
            meanImg = data.ops.meanImg;
            meanImg_channels{1} = meanImg;
        end
    end
end


function norm_img = normalize_image(img)
    % Fonction pour normaliser une image entre 0 et 255
    if isfloat(img)
        norm_img = mat2gray(img);
    elseif isinteger(img)
        norm_img = double(img) / double(max(img(:))) * 255;
        norm_img = uint8(norm_img);
    else
        error('Type de données non supporté pour l''image.');
    end
end


function display_animation(image_tiff, aligned_image)
    image_tiff    = double(image_tiff);
    aligned_image = double(aligned_image);

    % Normalisation de aligned_image par rapport à image_tiff
    mean_tiff = mean(image_tiff(:));
    std_tiff  = std(image_tiff(:));

    mean_aligned = mean(aligned_image(:));
    std_aligned  = std(aligned_image(:));

    aligned_image_norm = ((aligned_image - mean_aligned) / std_aligned) * std_tiff + mean_tiff;
    aligned_image_norm = max(min(aligned_image_norm, max(image_tiff(:))), min(image_tiff(:)));

    figureHandle = figure('Position', [100, 100, 800, 600], 'Name', 'Animation');
    ax = axes('Parent', figureHandle);

    while ishandle(figureHandle) && isvalid(figureHandle)
        for i = 1:2
            if ~ishandle(figureHandle) || ~isvalid(figureHandle)
                break;
            end
            if mod(i, 2) == 1
                imagesc(image_tiff, 'Parent', ax);
                title(ax, 'Image Originale (Normalisée)');
            else
                imagesc(aligned_image_norm, 'Parent', ax);
                title(ax, 'Image Alignée (Normalisée)');
            end
            colormap(ax, 'gray');
            axis(ax, 'image');
            colorbar;
            pause(0.5);
        end
    end
end


function npy_file_path = launch_cellpose_from_matlab(image_path)

    pyExec = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe';

    currentPyEnv = pyenv;
    if ~strcmp(currentPyEnv.Version, pyExec)
        pyenv('Version', pyExec);
    end

    try
        py.print("Python is working with Cellpose!");
    catch
        error('Error: Python is not properly configured in MATLAB.');
    end

    setenv('PATH', [getenv('PATH') ';C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts']);
    
    answer = questdlg('Do you want to launch Cellpose to process this image?', ...
        'Launch Cellpose', 'Yes', 'No', 'No');
    
    if strcmp(answer, 'Yes')
        fprintf('Launching Cellpose with the graphical interface to process the image: %s\n', image_path);
        cellposePath = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts\cellpose.exe';
        system(cellposePath);
    else
        fprintf('Cellpose was not launched. Process canceled.\n');
        npy_file_path = [];
    end
   
    [parent_folder, folder_name, ~] = fileparts(image_path);
    npy_file_name = [folder_name, '_seg.npy'];
    npy_file_path = fullfile(parent_folder, npy_file_name);
    if isfile(npy_file_path)
        fprintf('Fichier NPY trouvé et ajouté\n');
    else
        disp(['Aucun fichier NPY trouvé après l''exécution de Cellpose dans : ', npy_file_path]);
        npy_file_path = [];
    end
end
