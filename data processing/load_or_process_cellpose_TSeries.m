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
    current_gcamp_folders_group_plane = [];
    current_red_folders_group_plane   = [];
    current_blue_folders_group_plane  = [];
    current_green_folders_group_plane = [];

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

    % Validation minimale des entrées chemin
    if isempty(date_group_path) || ~(ischar(date_group_path) || isstring(date_group_path))
        warning('load_or_process_cellpose_TSeries:InvalidDateGroupPath', ...
            'Invalid date_group_path for plane %d.', p);
        [meanImg_channels, meanImg] = complete_meanImg_channels( ...
            meanImg_channels, filePath, current_gcamp_folders_group_plane, meanImg);
        return;
    end

    if isempty(current_blue_TSeries_path)
        current_blue_TSeries_path = "";
    end

    % ==========================================================
    %  Pré-remplissage des meanImg_channels depuis suite2p
    % ==========================================================
    if ~isempty(current_gcamp_folders_group_plane)
        tmp = load_meanImg_from_path(current_gcamp_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{1} = tmp;
            meanImg             = tmp;
        end
    end

    if ~isempty(current_red_folders_group_plane)
        tmp = load_meanImg_from_path(current_red_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{2} = tmp;
        end
    end

    if ~isempty(current_blue_folders_group_plane)
        tmp = load_meanImg_from_path(current_blue_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{3} = tmp;
        end
    end

    if ~isempty(current_green_folders_group_plane)
        tmp = load_meanImg_from_path(current_green_folders_group_plane);
        if ~isempty(tmp)
            meanImg_channels{4} = tmp;
        end
    end

    if isempty(meanImg) && ~isempty(meanImg_channels{1})
        meanImg = meanImg_channels{1};
    end

    % ==========================================================
    %  CAS 1 : pas de blue group suite2p
    % ==========================================================
    if isempty(current_blue_folders_group_plane)

        path      = fullfile(date_group_path, 'Single images');
        canal_str = 'Ch3';  % Blue

        if exist(path, 'dir')
            % ======================================================
            % CAS 1A : dossier "Single images"
            % ======================================================
            cellpose_files       = dir(fullfile(path, '*_seg.npy'));
            cellpose_files_canal = cellpose_files(contains({cellpose_files.name}, canal_str));

            if ~isempty(cellpose_files_canal)
                % --- seg.npy existe déjà ---
                npy_file_path = select_or_default(cellpose_files_canal, canal_str, '*.npy');
                npy_file_path = validate_existing_file(npy_file_path);

                if ~isempty(npy_file_path)
                    aligned_image_path = strrep(npy_file_path, '_seg.npy', '.tif');

                    % retrouver brute Ch3
                    [pth, name, ext] = fileparts(aligned_image_path);
                    raw_name      = regexprep(name, '^aligned_', '');
                    tif_file_path = fullfile(pth, [raw_name ext]);

                    image_tiff = safe_read_and_normalize(tif_file_path);
                    if ~isempty(image_tiff)
                        meanImg_channels{3} = image_tiff;
                    end

                    aligned_image = safe_read_and_normalize(aligned_image_path);

                    if isempty(aligned_image)
                        warning('seg.npy trouvé mais image alignée absente ou illisible -> recalage relancé');
                        fprintf('[FIX] Recomputing alignment because TIFF missing/unreadable: %s\n', aligned_image_path);

                        [aligned_image, ~, source_used] = align_blue_locally_and_confirm( ...
                            meanImg_channels, aligned_image_path);

                        fprintf('Transform estimated from: %s\n', source_used);

                        if ~isempty(aligned_image)
                            npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                            npy_file_path = validate_existing_file(npy_file_path);
                        else
                            npy_file_path = [];
                        end
                    end
                end

            else
                % --- pas de seg.npy -> chercher tif ---
                tif_files       = dir(fullfile(path, '*.tif'));
                tif_files_canal = tif_files(contains({tif_files.name}, canal_str));

                if isempty(tif_files_canal)
                    disp(['Aucun fichier contenant "', canal_str, '" trouvé.']);
                end

                aligned_files = tif_files(~cellfun('isempty', ...
                    regexp({tif_files.name}, ['^aligned_.*_' canal_str '(_|\.)'])));

                if ~isempty(aligned_files)
                    % --- image alignée déjà présente ---
                    aligned_image_path = select_or_default(aligned_files, canal_str, '*.tif');
                    aligned_image      = safe_read_and_normalize(aligned_image_path);

                    tif_file_path = select_or_default(tif_files_canal, canal_str, '*.tif');
                    image_tiff = safe_read_and_normalize(tif_file_path);
                    if ~isempty(image_tiff)
                        meanImg_channels{3} = image_tiff;
                    end

                    if ~isempty(aligned_image)
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        npy_file_path = validate_existing_file(npy_file_path);
                    else
                        npy_file_path = [];
                    end

                else
                    % --- aucun alignement existant -> recalcul ---
                    tif_file_path = select_or_default(tif_files_canal, canal_str, '*.tif');

                    if isempty(tif_file_path)
                        disp(['Aucun fichier "', canal_str, '" sélectionné ou trouvé.']);
                    else
                        image_tiff = safe_read_and_normalize(tif_file_path);
                        if ~isempty(image_tiff)
                            meanImg_channels{3} = image_tiff;
                        end

                        if isempty(meanImg_channels{1}) && ~isempty(current_gcamp_folders_group_plane)
                            tmp = load_meanImg_from_path(current_gcamp_folders_group_plane);
                            if ~isempty(tmp)
                                meanImg_channels{1} = tmp;
                                meanImg             = tmp;
                            end
                        end

                        if isempty(meanImg_channels{1}) && ~isempty(image_tiff)
                            meanImg_channels{1} = image_tiff;
                            meanImg             = image_tiff;
                        end

                        [~, file_name, ~] = fileparts(tif_file_path);
                        aligned_image_path = fullfile(path, ['aligned_', file_name, '.tif']);

                        [aligned_image, ~, source_used] = align_blue_locally_and_confirm( ...
                            meanImg_channels, aligned_image_path);

                        fprintf('Transform estimated from: %s\n', source_used);

                        if ~isempty(aligned_image)
                            npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                            npy_file_path = validate_existing_file(npy_file_path);
                        else
                            npy_file_path = [];
                        end
                    end
                end
            end

        else
            % ======================================================
            % CAS 1B : Blue\plane*
            % ======================================================
            if ~(ischar(current_blue_TSeries_path) || isstring(current_blue_TSeries_path)) || isempty(current_blue_TSeries_path)
                warning('load_or_process_cellpose_TSeries:InvalidBlueTSeriesPath', ...
                    'Invalid current_blue_TSeries_path for plane %d.', p);
                [meanImg_channels, meanImg] = complete_meanImg_channels( ...
                    meanImg_channels, filePath, current_gcamp_folders_group_plane, meanImg);
                return;
            end

            planeFolderName = sprintf('plane%d', p-1);
            current_blue_TSeries_path_plane = fullfile(current_blue_TSeries_path, planeFolderName);

            if ~isfolder(current_blue_TSeries_path_plane)
                warning('Blue plane folder not found: %s -> fallback to %s', ...
                        current_blue_TSeries_path_plane, current_blue_TSeries_path);
                current_blue_TSeries_path_plane = current_blue_TSeries_path;
            end

            segPattern = sprintf('aligned_%s_AVG*_seg.npy', planeFolderName);
            segFiles   = dir(fullfile(current_blue_TSeries_path_plane, segPattern));

            if ~isempty(segFiles)
                npy_file_path = fullfile(current_blue_TSeries_path_plane, segFiles(1).name);
                npy_file_path = validate_existing_file(npy_file_path);

                [segDir, segName, ~] = fileparts(npy_file_path);
                baseName = regexprep(segName, '_seg$', '');
                aligned_image_path = fullfile(segDir, [baseName '.tif']);

                avgPattern = sprintf('plane%d_AVG*.tif', p-1);
                avgFiles   = dir(fullfile(current_blue_TSeries_path_plane, avgPattern));
                if ~isempty(avgFiles)
                    avg_path = fullfile(current_blue_TSeries_path_plane, avgFiles(1).name);
                    blue_img = safe_read_and_normalize(avg_path);
                    if ~isempty(blue_img)
                        meanImg_channels{3} = blue_img;
                    end
                end

                aligned_image = safe_read_and_normalize(aligned_image_path);

                if isempty(aligned_image)
                    warning('seg.npy trouvé mais image alignée absente ou illisible -> recalage relancé');
                    fprintf('[FIX] Recomputing alignment because TIFF missing/unreadable: %s\n', aligned_image_path);

                    [aligned_image, ~, source_used] = align_blue_locally_and_confirm( ...
                        meanImg_channels, aligned_image_path);

                    fprintf('Transform estimated from: %s\n', source_used);

                    if ~isempty(aligned_image)
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        npy_file_path = validate_existing_file(npy_file_path);
                    else
                        npy_file_path = [];
                    end
                end

            else
                alignedPattern = sprintf('aligned_plane%d_AVG*.tif', p-1);
                alignedFiles   = dir(fullfile(current_blue_TSeries_path_plane, alignedPattern));

                if ~isempty(alignedFiles)
                    aligned_image_path = fullfile(current_blue_TSeries_path_plane, alignedFiles(1).name);
                    aligned_image      = safe_read_and_normalize(aligned_image_path);

                    avgPattern = sprintf('plane%d_AVG*.tif', p-1);
                    avgFiles   = dir(fullfile(current_blue_TSeries_path_plane, avgPattern));
                    if ~isempty(avgFiles)
                        avg_path = fullfile(current_blue_TSeries_path_plane, avgFiles(1).name);
                        blue_img = safe_read_and_normalize(avg_path);
                        if ~isempty(blue_img)
                            meanImg_channels{3} = blue_img;
                        end
                    end

                    if ~isempty(aligned_image)
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        npy_file_path = validate_existing_file(npy_file_path);
                    else
                        npy_file_path = [];
                    end

                else
                    avgPattern = sprintf('plane%d_AVG*.tif', p-1);
                    avgFiles   = dir(fullfile(current_blue_TSeries_path_plane, avgPattern));

                    if isempty(avgFiles)
                        fprintf('No seg, no aligned image, no %s in %s\n', ...
                                avgPattern, current_blue_TSeries_path_plane);
                        npy_file_path = [];
                        aligned_image = [];
                    else
                        avg_path = fullfile(current_blue_TSeries_path_plane, avgFiles(1).name);
                        blue_img = safe_read_and_normalize(avg_path);
                        if ~isempty(blue_img)
                            meanImg_channels{3} = blue_img;
                        end

                        if isempty(meanImg_channels{1}) && ~isempty(current_gcamp_folders_group_plane)
                            meanImg_gcamp = load_meanImg_from_path(current_gcamp_folders_group_plane);
                            if ~isempty(meanImg_gcamp)
                                meanImg_channels{1} = meanImg_gcamp;
                                meanImg             = meanImg_gcamp;
                            end
                        end

                        if isempty(meanImg_channels{1}) && ~isempty(blue_img)
                            meanImg_channels{1} = blue_img;
                            meanImg             = blue_img;
                        end

                        aligned_image_path = fullfile(current_blue_TSeries_path_plane, ...
                            sprintf('aligned_plane%d_AVG.tif', p-1));

                        [aligned_image, ~, source_used] = align_blue_locally_and_confirm( ...
                            meanImg_channels, aligned_image_path);

                        fprintf('Transform estimated from: %s\n', source_used);

                        if ~isempty(aligned_image)
                            npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                            npy_file_path = validate_existing_file(npy_file_path);
                        else
                            npy_file_path = [];
                        end
                    end
                end
            end
        end

    % ==========================================================
    %  CAS 2 : blue group existant
    % ==========================================================
    else
        try
            cellpose_files = dir(fullfile(current_blue_folders_group_plane, '*_seg.npy'));

            if ~isempty(cellpose_files)
                npy_file_path = select_or_default(cellpose_files, '', '*.npy');
                npy_file_path = validate_existing_file(npy_file_path);

                aligned_image_path = [];
                if ~isempty(npy_file_path)
                    [segDir, segName, ~] = fileparts(npy_file_path);
                    baseName = regexprep(segName, '_seg$', '');
                    aligned_image_path = fullfile(segDir, [baseName '.tif']);
                end

                if isempty(aligned_image_path) || ~isfile(aligned_image_path)
                    aligned_image_path = fullfile(current_blue_folders_group_plane, ...
                        sprintf('aligned_plane%d_AVG.tif', p-1));
                end

                aligned_image = safe_read_and_normalize(aligned_image_path);

                if isempty(aligned_image)
                    warning('seg.npy trouvé mais image alignée absente ou illisible -> recalage relancé');
                    fprintf('[FIX] Recomputing alignment because TIFF missing/unreadable: %s\n', aligned_image_path);

                    [aligned_image, ~, source_used] = align_blue_locally_and_confirm( ...
                        meanImg_channels, aligned_image_path);

                    fprintf('Transform estimated from: %s\n', source_used);

                    if ~isempty(aligned_image)
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        npy_file_path = validate_existing_file(npy_file_path);
                    else
                        npy_file_path = [];
                    end
                end

            else
                aligned_image_path = fullfile(current_blue_folders_group_plane, ...
                    sprintf('aligned_plane%d_AVG.tif', p-1));

                if isfile(aligned_image_path)
                    aligned_image = safe_read_and_normalize(aligned_image_path);

                    if ~isempty(aligned_image)
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        npy_file_path = validate_existing_file(npy_file_path);
                    else
                        npy_file_path = [];
                    end

                else
                    if isempty(meanImg_channels{1}) && ~isempty(current_gcamp_folders_group_plane)
                        tmp = load_meanImg_from_path(current_gcamp_folders_group_plane);
                        if ~isempty(tmp)
                            meanImg_channels{1} = tmp;
                            meanImg             = tmp;
                        end
                    end

                    if isempty(meanImg_channels{3}) && ~isempty(current_blue_folders_group_plane)
                        tmp = load_meanImg_from_path(current_blue_folders_group_plane);
                        if ~isempty(tmp)
                            meanImg_channels{3} = tmp;
                        end
                    end

                    [aligned_image, ~, source_used] = align_blue_locally_and_confirm( ...
                        meanImg_channels, aligned_image_path);

                    fprintf('Transform estimated from: %s\n', source_used);

                    if ~isempty(aligned_image)
                        npy_file_path = launch_cellpose_from_matlab(aligned_image_path);
                        npy_file_path = validate_existing_file(npy_file_path);
                    else
                        npy_file_path = [];
                    end
                end
            end

        catch ME
            warning('load_or_process_cellpose_TSeries:ExistingBlueBranchFailed', ...
                'Plane %d: existing-blue branch failed: %s', p, ME.message);
            aligned_image = [];
            npy_file_path = [];
        end
    end

    % ==========================================================
    %  Post-traitement
    % ==========================================================
    [meanImg_channels, meanImg] = complete_meanImg_channels( ...
        meanImg_channels, filePath, current_gcamp_folders_group_plane, meanImg);
end


% =========================================================================
% Helpers locaux
% =========================================================================

function img = safe_read_and_normalize(img_path)
    img = [];
    if isempty(img_path)
        return;
    end
    if ~(ischar(img_path) || isstring(img_path))
        return;
    end
    if ~isfile(img_path)
        return;
    end
    try
        img = normalize_image(imread(img_path));
    catch ME
        warning('load_or_process_cellpose_TSeries:ReadImageFailed', ...
            'Failed reading image "%s": %s', char(img_path), ME.message);
        img = [];
    end
end

function filepath = validate_existing_file(filepath)
    if isempty(filepath)
        filepath = [];
        return;
    end
    if ~(ischar(filepath) || isstring(filepath))
        filepath = [];
        return;
    end
    if ~isfile(filepath)
        filepath = [];
    end
end

% =====================================================================
% ======================== HELPER FUNCTIONS ===========================
% =====================================================================

function [aligned_image, T, source_used] = align_blue_locally_and_confirm( ...
        meanImg_channels, aligned_image_path)

    ref_img = [];
    if numel(meanImg_channels) >= 1
        ref_img = meanImg_channels{1};
    end

    blue_img = [];
    if numel(meanImg_channels) >= 3
        blue_img = meanImg_channels{3};
    end

    green_img = [];
    if numel(meanImg_channels) >= 4
        green_img = meanImg_channels{4};
    end

    aligned_image = [];
    T = [];
    source_used = '';

    if isempty(ref_img)
        warning('align_blue_locally_and_confirm: GCaMP absent.');
        return;
    end

    ref_img = double(ref_img);

    % ----------------------------------------------------------
    % Choix de l'image servant à estimer la translation
    % ----------------------------------------------------------
    if ~isempty(green_img)
        moving_for_estimation = double(green_img);
        source_used = 'Green';
    elseif ~isempty(blue_img)
        moving_for_estimation = double(blue_img);
        source_used = 'Blue';
    else
        warning('align_blue_locally_and_confirm: ni Green ni Blue disponible.');
        return;
    end

    % ----------------------------------------------------------
    % Image finale à translater
    % ----------------------------------------------------------
    if ~isempty(blue_img)
        moving_img = double(blue_img);
    else
        moving_img = double(green_img);
    end

    % ----------------------------------------------------------
    % Recherche locale autour de (0,0), rayon max = 15 px
    % ----------------------------------------------------------
    max_radius = 15;
    [bestTx, bestTy, bestScore] = estimate_local_translation_from_zero( ...
        moving_for_estimation, ref_img, max_radius, 1);

    T = eye(3);
    T(3,1) = bestTx;
    T(3,2) = bestTy;

    fprintf('%s -> GCaMP | local translation from zero: dx = %.3f px, dy = %.3f px\n', ...
        source_used, bestTx, bestTy);
    fprintf('Local correlation score = %.6f\n', bestScore);

    aligned_image = apply_transform_with_phasecorr(moving_img, T, ref_img);

    if isempty(aligned_image)
        warning('align_blue_locally_and_confirm: transformation vide.');
        return;
    end

    % ----------------------------------------------------------
    % Vérification dimensions
    % ----------------------------------------------------------
    if ~isequal(size(aligned_image,1), size(ref_img,1)) || ...
       ~isequal(size(aligned_image,2), size(ref_img,2))
        warning(['Aligned image size mismatch with GCaMP reference. ' ...
                 'Forcing resize as fallback.']);
        aligned_image = imresize(aligned_image, [size(ref_img,1), size(ref_img,2)]);
    end

    % ----------------------------------------------------------
    % Métriques before/after
    % ----------------------------------------------------------
    before_cmp = mat2gray(double(moving_img));
    ref_cmp    = mat2gray(double(ref_img));
    after_cmp  = mat2gray(double(aligned_image));

    if ~isequal(size(before_cmp), size(ref_cmp))
        before_cmp = imresize(before_cmp, size(ref_cmp));
    end

    if ~isequal(size(after_cmp), size(ref_cmp))
        after_cmp = imresize(after_cmp, size(ref_cmp));
    end

    before_err = mean(abs(ref_cmp(:) - before_cmp(:)), 'omitnan');
    after_err  = mean(abs(ref_cmp(:) - after_cmp(:)), 'omitnan');

    fprintf('Error vs ref before = %.6f\n', before_err);
    fprintf('Error vs ref after  = %.6f\n', after_err);
    fprintf('Improvement         = %.6f\n', before_err - after_err);

    % ----------------------------------------------------------
    % Prévisualisation utilisateur avec Enregistrer / Annuler
    % ----------------------------------------------------------
    [was_saved, aligned_image, T] = preview_alignment_with_save_cancel(moving_img, aligned_image, ref_img, T);

    if ~was_saved
        fprintf('Recalage annulé par l''utilisateur.\n');
        aligned_image = [];
        T = [];
        source_used = '';
        return;
    end

    % ----------------------------------------------------------
    % Sauvegarde TIFF aligné
    % ----------------------------------------------------------
    if ~isempty(aligned_image) && ~isempty(aligned_image_path)
        try
            imwrite(aligned_image, aligned_image_path, 'tif');
            fprintf('Aligned image saved: %s\n', aligned_image_path);
        catch ME
            warning('align_blue_locally_and_confirm: impossible de sauver %s (%s).', ...
                aligned_image_path, ME.message);
        end
    end
end

function [bestTx, bestTy, bestScore] = estimate_local_translation_from_zero( ...
    moving_img, ref_img, radius, step)

    if nargin < 4 || isempty(step)
        step = 1;
    end
    if nargin < 3 || isempty(radius)
        radius = 15;
    end

    if isempty(moving_img) || isempty(ref_img)
        bestTx = 0;
        bestTy = 0;
        bestScore = -Inf;
        return;
    end

    moving_img = double(moving_img);
    ref_img    = double(ref_img);

    % -------------------------------------------------
    % 1) Préparation des images pour le recalage
    %    (contours × pondération sombre)
    % -------------------------------------------------
    moving_p = prepare_image_for_registration(moving_img);
    ref_p    = prepare_image_for_registration(ref_img);

    if isempty(moving_p) || isempty(ref_p) || ~isequal(size(moving_p), size(ref_p))
        bestTx = 0;
        bestTy = 0;
        bestScore = -Inf;
        return;
    end

    ref_size = size(ref_p);
    ref_size = ref_size(1:2);

    % -------------------------------------------------
    % 2) ROI centrale
    %    Limite l'influence des bords et du fond
    % -------------------------------------------------
    [H, W] = size(ref_p);

    roi_half_w = round(W * 0.25);
    roi_half_h = round(H * 0.25);

    cx = round(W / 2);
    cy = round(H / 2);

    x1 = max(1, cx - roi_half_w);
    x2 = min(W, cx + roi_half_w);
    y1 = max(1, cy - roi_half_h);
    y2 = min(H, cy + roi_half_h);

    ref_roi = ref_p(y1:y2, x1:x2);

    % -------------------------------------------------
    % 3) Initialisation recherche locale
    % -------------------------------------------------
    bestTx = 0;
    bestTy = 0;
    bestScore = -Inf;

    tx_list = -radius:step:radius;
    ty_list = -radius:step:radius;

    % -------------------------------------------------
    % 4) Recherche exhaustive locale
    % -------------------------------------------------
    for tx = tx_list
        for ty = ty_list

            Ttmp = eye(3);
            Ttmp(3,1) = tx;
            Ttmp(3,2) = ty;

            moved = imwarp(moving_p, affine2d(Ttmp), ...
                'OutputView', imref2d(ref_size));

            moved_roi = moved(y1:y2, x1:x2);

            score = normalized_corr_score(moved_roi, ref_roi);

            if score > bestScore
                bestScore = score;
                bestTx = tx;
                bestTy = ty;
            end
        end
    end

    % -------------------------------------------------
    % 5) Affichage debug
    % -------------------------------------------------
    fprintf('Best local translation: dx = %.3f px, dy = %.3f px, score = %.6f\n', ...
        bestTx, bestTy, bestScore);
end

function score = normalized_corr_score(I1, I2)

    I1 = double(I1);
    I2 = double(I2);

    if isempty(I1) || isempty(I2) || ~isequal(size(I1), size(I2))
        score = -Inf;
        return;
    end

    I1(~isfinite(I1)) = 0;
    I2(~isfinite(I2)) = 0;

    I1 = I1 - mean(I1(:));
    I2 = I2 - mean(I2(:));

    s1 = std(I1(:));
    s2 = std(I2(:));

    if s1 < eps || s2 < eps
        score = -Inf;
        return;
    end

    I1 = I1 / s1;
    I2 = I2 / s2;

    score = mean(I1(:) .* I2(:), 'omitnan');
end

function [was_saved, aligned_img, T] = preview_alignment_with_save_cancel(original_img, aligned_img, ref_img, T)

    was_saved = false;

    if isempty(original_img) || isempty(aligned_img) || isempty(ref_img) || isempty(T)
        return;
    end

    original_img = double(original_img);
    aligned_img  = double(aligned_img);
    ref_img      = double(ref_img);

    dx = T(3,1);
    dy = T(3,2);

    original_disp = enhance_for_overlay(original_img);
    aligned_disp  = enhance_for_overlay(aligned_img);
    ref_disp      = enhance_for_overlay(ref_img);

    hFig = figure( ...
        'Name', 'Preview alignment', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Color', 'w', ...
        'Position', [80 80 1500 720], ...
        'CloseRequestFcn', @onCancel);

    S = struct();
    S.saved = false;
    S.state = 1;
    S.original_img  = original_img;
    S.aligned_img   = aligned_img;
    S.ref_img       = ref_img;
    S.T             = T;

    S.original_disp = original_disp;
    S.aligned_disp  = aligned_disp;
    S.ref_disp      = ref_disp;

    S.ax1 = axes('Parent', hFig, 'Position', [0.05 0.12 0.34 0.78]);
    S.ax2 = axes('Parent', hFig, 'Position', [0.44 0.12 0.34 0.78]);

    S.infoTxt = uicontrol('Parent', hFig, ...
        'Style', 'text', ...
        'String', sprintf(['Recalage automatique appliqué\n\n' ...
                           'dx = %.2f px\n' ...
                           'dy = %.2f px\n\n' ...
                           'Gauche : Original / Alignée\n' ...
                           'Droite : Référence / Alignée\n' ...
                           'Alternance automatique'], dx, dy), ...
        'FontSize', 11, ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.81 0.62 0.16 0.22]);

    S.btnManual = uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Recalage manuel', ...
        'FontSize', 12, ...
        'Units', 'normalized', ...
        'Position', [0.82 0.54 0.14 0.08], ...
        'Callback', @onManual);

    S.btnSave = uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Enregistrer', ...
        'FontSize', 12, ...
        'Units', 'normalized', ...
        'Position', [0.82 0.42 0.14 0.08], ...
        'Callback', @onSave);

    S.btnCancel = uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Annuler', ...
        'FontSize', 12, ...
        'Units', 'normalized', ...
        'Position', [0.82 0.30 0.14 0.08], ...
        'Callback', @onCancel);

    guidata(hFig, S);

    refresh_alternating_display(hFig);

    animTimer = timer( ...
        'ExecutionMode', 'fixedSpacing', ...
        'Period', 0.6, ...
        'TimerFcn', @(~,~) toggle_display(hFig));

    S = guidata(hFig);
    S.animTimer = animTimer;
    guidata(hFig, S);

    start(animTimer);
    uiwait(hFig);

    if isvalid_handle(hFig)
        S = guidata(hFig);

        if isfield(S, 'animTimer') && ~isempty(S.animTimer) && isvalid(S.animTimer)
            stop(S.animTimer);
            delete(S.animTimer);
        end

        was_saved   = S.saved;
        aligned_img = S.aligned_img;
        T           = S.T;

        delete(hFig);
    end

    function toggle_display(fig)
        if ~isvalid_handle(fig)
            return;
        end
        S = guidata(fig);
        S.state = 3 - S.state;
        guidata(fig, S);
        refresh_alternating_display(fig);
    end

    function refresh_alternating_display(fig)
        if ~isvalid_handle(fig)
            return;
        end
    
        S = guidata(fig);
    
        cla(S.ax1);
        cla(S.ax2);
    
        if S.state == 1
            % --- état 1 ---
            imagesc(S.ax1, S.original_disp);
            axis(S.ax1, 'image');
            title(S.ax1, 'Blue original');
    
            imagesc(S.ax2, S.ref_disp);
            axis(S.ax2, 'image');
            title(S.ax2, 'GCaMP reference');
    
        else
            % --- état 2 ---
            imagesc(S.ax1, S.aligned_disp);
            axis(S.ax1, 'image');
            title(S.ax1, 'Blue aligned');
    
            imagesc(S.ax2, S.aligned_disp);
            axis(S.ax2, 'image');
            title(S.ax2, 'Blue aligned');
        end
    
        colormap(S.ax1, parula);
        colormap(S.ax2, parula);
    
        drawnow limitrate;
    end

    function onManual(src, ~)
        fig = ancestor(src, 'figure');
        if isempty(fig) || ~isvalid_handle(fig)
            return;
        end

        S = guidata(fig);

        if isfield(S, 'animTimer') && ~isempty(S.animTimer) && isvalid(S.animTimer)
            stop(S.animTimer);
        end

        [T_manual, was_manual_saved] = manual_translation_gui( ...
            S.original_img, S.ref_img, S.T);

        if was_manual_saved && ~isempty(T_manual)

            S.T = T_manual;
            S.aligned_img = apply_transform_with_phasecorr(S.original_img, S.T, S.ref_img);

            if ~isempty(S.aligned_img)
                S.aligned_disp = enhance_for_overlay(S.aligned_img);

                dx = S.T(3,1);
                dy = S.T(3,2);

                set(S.infoTxt, 'String', sprintf([ ...
                    'Recalage manuel/auto appliqué\n\n' ...
                    'dx = %.2f px\n' ...
                    'dy = %.2f px\n\n' ...
                    'Gauche : Original / Alignée\n' ...
                    'Droite : Référence / Alignée\n' ...
                    'Alternance automatique'], dx, dy));
            end

            guidata(fig, S);
            refresh_alternating_display(fig);
        end

        if isfield(S, 'animTimer') && ~isempty(S.animTimer) && isvalid(S.animTimer)
            start(S.animTimer);
        end
    end

    function onSave(src, ~)
        fig = ancestor(src, 'figure');
        if isempty(fig) || ~isvalid_handle(fig)
            return;
        end

        S = guidata(fig);
        S.saved = true;
        guidata(fig, S);

        if isfield(S, 'animTimer') && ~isempty(S.animTimer) && isvalid(S.animTimer)
            stop(S.animTimer);
        end

        uiresume(fig);
    end

    function onCancel(src, ~)
        fig = src;
        if ~ishandle(fig) || ~strcmp(get(fig, 'Type'), 'figure')
            fig = ancestor(src, 'figure');
        end
        if isempty(fig) || ~isvalid_handle(fig)
            return;
        end

        S = guidata(fig);
        S.saved = false;
        guidata(fig, S);

        if isfield(S, 'animTimer') && ~isempty(S.animTimer) && isvalid(S.animTimer)
            stop(S.animTimer);
        end

        uiresume(fig);
    end
end

function [T_out, was_saved] = manual_translation_gui(moving_img, ref_img, T_init)

    was_saved = false;
    T_out = [];

    if isempty(moving_img) || isempty(ref_img)
        return;
    end

    moving_img = double(moving_img);
    ref_img    = double(ref_img);

    if nargin < 3 || isempty(T_init)
        T_init = eye(3);
    end

    tx = T_init(3,1);
    ty = T_init(3,2);

    ref_size = size(ref_img);
    ref_size = ref_size(1:2);

    S = struct();
    S.moving = moving_img;
    S.ref = ref_img;
    S.tx = tx;
    S.ty = ty;
    S.dragging = false;
    S.startPoint = [0 0];
    S.startTxTy = [tx ty];
    S.saved = false;

    hFig = figure( ...
        'Name', 'Recalage manuel', ...
        'NumberTitle', 'off', ...
        'Color', 'w', ...
        'MenuBar', 'none', ...
        'ToolBar', 'figure', ...
        'Position', [200 120 1200 780], ...
        'WindowButtonDownFcn', @onMouseDown, ...
        'WindowButtonUpFcn', @onMouseUp, ...
        'WindowButtonMotionFcn', @onMouseMove, ...
        'CloseRequestFcn', @onCancel);

    % ===== AXE =====
    S.ax = axes('Parent', hFig, 'Position', [0.05 0.08 0.70 0.86]);
    axis(S.ax, 'image');
    hold(S.ax, 'on');
    colormap(S.ax, parula);

    % ===== BOUTONS =====
    uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Valider', ...
        'FontSize', 11, ...
        'Units', 'normalized', ...
        'Position', [0.81 0.80 0.15 0.08], ...
        'Callback', @onSave);

    uicontrol('Parent', hFig, ...
        'Style', 'pushbutton', ...
        'String', 'Annuler', ...
        'FontSize', 11, ...
        'Units', 'normalized', ...
        'Position', [0.81 0.68 0.15 0.08], ...
        'Callback', @onCancel);

    % ===== SLIDER ALPHA =====
    uicontrol('Parent', hFig, ...
        'Style', 'text', ...
        'String', 'Transparence moving', ...
        'FontSize', 10, ...
        'BackgroundColor', 'w', ...
        'Units', 'normalized', ...
        'Position', [0.81 0.58 0.15 0.04]);

    S.sliderAlpha = uicontrol('Parent', hFig, ...
        'Style', 'slider', ...
        'Min', 0.05, 'Max', 1.0, 'Value', 0.5, ...
        'Units', 'normalized', ...
        'Position', [0.81 0.54 0.15 0.04], ...
        'Callback', @(~,~) refreshOverlay(hFig));

    % ===== TEXTE INFO =====
    S.txt = uicontrol('Parent', hFig, ...
        'Style', 'text', ...
        'String', '', ...
        'FontSize', 11, ...
        'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left', ...
        'Units', 'normalized', ...
        'Position', [0.80 0.35 0.18 0.12]);

    guidata(hFig, S);
    refreshOverlay(hFig);

    uiwait(hFig);

    if isvalid_handle(hFig)
        S = guidata(hFig);

        if S.saved
            T_out = eye(3);
            T_out(3,1) = S.tx;
            T_out(3,2) = S.ty;
            was_saved = true;
        end

        delete(hFig);
    end

    % =========================================================
    % INTERACTIONS SOURIS
    % =========================================================

    function onMouseDown(src, ~)
        S = guidata(src);
        cp = get(S.ax, 'CurrentPoint');
        S.dragging = true;
        S.startPoint = cp(1,1:2);
        S.startTxTy = [S.tx S.ty];
        guidata(src, S);
    end

    function onMouseMove(src, ~)
        S = guidata(src);
        if ~S.dragging
            return;
        end

        cp = get(S.ax, 'CurrentPoint');
        delta = cp(1,1:2) - S.startPoint;

        S.tx = S.startTxTy(1) + delta(1);
        S.ty = S.startTxTy(2) + delta(2);

        guidata(src, S);
        refreshOverlay(src);
    end

    function onMouseUp(src, ~)
        S = guidata(src);
        S.dragging = false;
        guidata(src, S);
    end

    % =========================================================
    % CALLBACKS
    % =========================================================

    function onSave(src, ~)
        fig = ancestor(src, 'figure');
        S = guidata(fig);
        S.saved = true;
        guidata(fig, S);
        uiresume(fig);
    end

    function onCancel(src, ~)
        fig = ancestor(src, 'figure');
        if isempty(fig)
            fig = src;
        end
        if ~isvalid_handle(fig)
            return;
        end
        S = guidata(fig);
        S.saved = false;
        guidata(fig, S);
        uiresume(fig);
    end

    % =========================================================
    % AFFICHAGE
    % =========================================================

    function refreshOverlay(fig)

        if ~isvalid_handle(fig)
            return;
        end

        S = guidata(fig);

        Ttmp = eye(3);
        Ttmp(3,1) = S.tx;
        Ttmp(3,2) = S.ty;

        moved = imwarp(double(S.moving), affine2d(Ttmp), ...
            'OutputView', imref2d(ref_size));

        ref_disp   = enhance_for_overlay(S.ref);
        moved_disp = enhance_for_overlay(moved);

        alpha_val = get(S.sliderAlpha, 'Value');

        cla(S.ax);
        hold(S.ax, 'on');

        imagesc(S.ax, ref_disp);
        hMov = imagesc(S.ax, moved_disp);
        set(hMov, 'AlphaData', alpha_val);

        colormap(S.ax, parula);
        axis(S.ax, 'image');

        title(S.ax, 'Drag souris = translation');

        set(S.txt, 'String', sprintf( ...
            'dx = %.2f px\ndy = %.2f px\nalpha = %.2f', ...
            S.tx, S.ty, alpha_val));

        drawnow limitrate;
    end
end

function Iprep = prepare_image_for_registration(I)

    I = double(I);

    if isempty(I) || all(~isfinite(I(:)))
        Iprep = zeros(size(I));
        return;
    end

    vals = I(isfinite(I));
    if isempty(vals)
        Iprep = zeros(size(I));
        return;
    end

    % -------------------------------------------------
    % 1) Normalisation robuste
    % -------------------------------------------------
    p1  = prctile(vals, 1);
    p99 = prctile(vals, 99);

    if p99 > p1
        I = (I - p1) / (p99 - p1);
    else
        I = mat2gray(I);
    end

    I = max(0, min(1, I));

    % -------------------------------------------------
    % 2) Lissage léger
    % -------------------------------------------------
    I = imgaussfilt(I, 1.0);

    % -------------------------------------------------
    % 3) Carte d'obscurité
    %    sombre = important
    %    très sombre = encore plus important
    % -------------------------------------------------
    darkness = 1 - I;

    % seuil doux : enlève les zones trop peu sombres
    dark_threshold = 0.30;
    darkness = max(0, darkness - dark_threshold);

    % renormalisation après seuil
    if any(darkness(:))
        mx_dark = max(darkness(:));
        if mx_dark > 0
            darkness = darkness / mx_dark;
        end
    end

    % amplification non linéaire :
    % les plus noirs parmi les sombres dominent fortement
    gamma_dark = 2.5;
    dark_weight = darkness .^ gamma_dark;

    % -------------------------------------------------
    % 4) Contours / gradients
    %    On privilégie les bords plutôt que les surfaces
    % -------------------------------------------------
    [Gx, Gy] = imgradientxy(I, 'sobel');
    G = hypot(Gx, Gy);

    G(~isfinite(G)) = 0;

    if any(G(:))
        G = G - min(G(:));
        mx = max(G(:));
        if mx > 0
            G = G / mx;
        end
    end

    % enlève une partie du bruit faible
    G(G < 0.03) = 0;

    % renforcement léger des contours nets
    G = G .^ 1.2;

    % -------------------------------------------------
    % 5) Signal final pour recalage
    %    contours × masque sombre fortement pondéré
    % -------------------------------------------------
    Iprep = G .* dark_weight;

    % -------------------------------------------------
    % 6) Normalisation finale
    % -------------------------------------------------
    Iprep(~isfinite(Iprep)) = 0;

    if any(Iprep(:))
        Iprep = Iprep - min(Iprep(:));
        mx = max(Iprep(:));
        if mx > 0
            Iprep = Iprep / mx;
        end
    end
end

 
function aligned_img = apply_transform_with_phasecorr(channel_img, T, ref_img)

    aligned_img = [];

    if isempty(channel_img) || isempty(T) || isempty(ref_img)
        warning('apply_transform_with_phasecorr: entrée vide.');
        return;
    end

    ref_size = size(ref_img);
    ref_size = ref_size(1:2);

    try
        aligned_raw = imwarp(double(channel_img), affine2d(T), ...
            'OutputView', imref2d(ref_size));
    catch ME
        warning('apply_transform_with_phasecorr: imwarp a échoué (%s).', ME.message);
        return;
    end

    aligned_img = normalize_image(aligned_raw);
end

function meanImg = load_meanImg_from_path(path_in)
    meanImg = [];

    if isempty(path_in)
        return;
    end

    if isfolder(path_in)
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

        ops_mat = fullfile(path_in, 'ops.mat');
        if isfile(ops_mat)
            S = load(ops_mat);
            if isfield(S,'ops') && isfield(S.ops,'meanImg')
                meanImg = S.ops.meanImg;
                return;
            end
        end
    end

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

        if (isempty(meanImg) || (isnumeric(meanImg) && all(meanImg(:) == 0)))
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
    numChannelsLocal   = 4;
    meanImg            = [];
    meanImg_channels   = cell(numChannelsLocal, 1);

    if nargin < 2
        filePath = '';
    end

    [~, ~, ext] = fileparts(path_in);

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
    if isfloat(img)
        norm_img = mat2gray(img);
    elseif isinteger(img)
        denom = double(max(img(:)));
        if denom == 0
            norm_img = uint8(img);
        else
            norm_img = double(img) / denom * 255;
            norm_img = uint8(norm_img);
        end
    else
        norm_img = mat2gray(double(img));
    end
end

function out = enhance_for_overlay(img)

    img = double(img);

    if isempty(img) || all(~isfinite(img(:)))
        out = zeros(size(img));
        return;
    end

    vals = img(isfinite(img));

    p_low  = prctile(vals, 2);
    p_high = prctile(vals, 98);

    if p_high <= p_low
        out = mat2gray(img);
        return;
    end

    out = (img - p_low) / (p_high - p_low);
    out = max(min(out,1),0);
    out = out .^ 0.7;
end

function tf = isvalid_handle(h)
    tf = ~isempty(h) && isgraphics(h);
end

function npy_file_path = launch_cellpose_from_matlab(image_path)
    npy_file_path = [];

    pyExec = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe';

    try
        currentPyEnv = pyenv;
        if ~strcmp(currentPyEnv.Version, pyExec)
            pyenv('Version', pyExec);
        end
    catch ME
        warning('Impossible de configurer pyenv: %s', ME.message);
    end

    try
        py.print("Python is working with Cellpose!");
    catch
        warning('Python n''est pas correctement configuré dans MATLAB.');
    end

    setenv('PATH', [getenv('PATH') ';C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts']);

    answer = questdlg('Do you want to launch Cellpose to process this image?', ...
        'Launch Cellpose', 'Yes', 'No', 'No');

    if strcmp(answer, 'Yes')
        fprintf('Launching Cellpose GUI for image: %s\n', image_path);
        cellposePath = 'C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\Scripts\cellpose.exe';
        system(cellposePath);

        [folderPath, fileName, ~] = fileparts(image_path);
        candidate_npy = fullfile(folderPath, [fileName '_seg.npy']);

        if isfile(candidate_npy)
            npy_file_path = candidate_npy;
            fprintf('Fichier NPY trouvé : %s\n', npy_file_path);
        else
            warning('Aucun fichier NPY trouvé après Cellpose : %s', candidate_npy);
        end
    else
        fprintf('Cellpose non lancé.\n');
    end
end