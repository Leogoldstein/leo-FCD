function meanImgs = save_mean_images(label, current_animal_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group)
    % SAVE_MEAN_IMAGES
    % Génère et sauvegarde une meanImg par plan (BRUT, sans normalisation)
    % uniquement si le fichier n'existe pas déjà.
    %
    % Retourne :
    %   meanImgs{m}{p} = image brute du plan p pour l'acquisition m
    %
    % Si le .tif existe déjà, il est relu au lieu d'être recalculé.

    numFolders = length(current_gcamp_folders_group);
    meanImgs = cell(1, numFolders);

    label_clean  = strrep(label, ' ', '_');
    animal_clean = strrep(current_animal_group, ' ', '_');

    for m = 1:numFolders

        fall_paths = current_gcamp_folders_group{m};

        if ischar(fall_paths) || isstring(fall_paths)
            fall_paths = {char(fall_paths)};
        end

        nPlanes = numel(fall_paths);
        meanImgs{m} = cell(nPlanes, 1);

        fprintf("Handling meanImgs for %d planes in folder %d\n", nPlanes, m);

        valid_mask = false(nPlanes,1);

        % ======================================================
        % ======== PAR PLAN ====================================
        % ======================================================
        for p = 1:nPlanes

            % vérifier dossier de sortie plan
            if isempty(gcamp_output_folders{m}) || p > numel(gcamp_output_folders{m}) || isempty(gcamp_output_folders{m}{p})
                warning('Missing output folder for m=%d, p=%d', m, p);
                continue;
            end

            age_clean = '';
            if ~isempty(current_ages_group) && m <= numel(current_ages_group) && ~isempty(current_ages_group{m})
                age_clean = strrep(current_ages_group{m}, ' ', '_');
            end

            tif_filename = fullfile(gcamp_output_folders{m}{p}, ...
                sprintf('Mean_image_%s_of_%s_%s_plane%d.tif', ...
                label_clean, animal_clean, age_clean, p-1));

            % --------------------------------------------------
            % Si le tif existe déjà : recharger et skip calcul
            % --------------------------------------------------
            if isfile(tif_filename)
                try
                    meanImgs{m}{p} = double(imread(tif_filename));
                    valid_mask(p) = true;
                    fprintf('Mean image already exists, loaded %s\n', tif_filename);
                    continue;
                catch ME
                    warning("Error reading existing tif %s : %s", tif_filename, ME.message);
                    % si lecture impossible, on tente recalcul
                end
            end

            fall_path = fall_paths{p};

            if isempty(fall_path)
                warning("Empty fall_path for m=%d, p=%d", m, p);
                continue;
            end

            if isfolder(fall_path)
                plane_dir = fall_path;
            elseif isfile(fall_path)
                plane_dir = fileparts(fall_path);
            else
                warning("Invalid fall_path: %s", string(fall_path));
                continue;
            end

            ops_npy = fullfile(plane_dir, 'ops.npy');
            ops_mat = fullfile(plane_dir, 'ops.mat');

            % ----- Load meanImg seulement si nécessaire -----
            if exist(ops_npy, 'file')
                try
                    mod = py.importlib.import_module('python_function');
                    ops = mod.read_npy_file(ops_npy);
                    meanImg = double(ops{'meanImg'});
                catch ME
                    warning("Error reading %s : %s", ops_npy, ME.message);
                    continue;
                end

            elseif exist(ops_mat, 'file')
                try
                    data_ops = load(ops_mat);
                    meanImg = double(data_ops.ops.meanImg);
                catch ME
                    warning("Error reading %s : %s", ops_mat, ME.message);
                    continue;
                end

            else
                warning("No ops.npy or ops.mat found in %s", plane_dir);
                continue;
            end

            % Stockage brut
            meanImgs{m}{p} = meanImg;
            valid_mask(p) = true;

            % ===== Conversion brute en uint16 =====
            meanImg_uint16 = uint16(max(min(meanImg, 65535), 0));

            % ===== Sauvegarde TIF par plan =====
            imwrite(meanImg_uint16, tif_filename);
            fprintf('Saved %s\n', tif_filename);
        end

        % ======================================================
        % ======== Z PROJECTION (>=2 plans uniquement) =========
        % ======================================================
        valid_imgs = meanImgs{m}(valid_mask);

        if numel(valid_imgs) > 1

            % dossier racine commun = parent du 1er dossier plan
            if ~isempty(gcamp_output_folders{m}) && ~isempty(gcamp_output_folders{m}{1})
                root_folder_m = fileparts(gcamp_output_folders{m}{1});
            else
                warning('Missing root output folder for Z projection in folder %d', m);
                continue;
            end

            age_clean = '';
            if ~isempty(current_ages_group) && m <= numel(current_ages_group) && ~isempty(current_ages_group{m})
                age_clean = strrep(current_ages_group{m}, ' ', '_');
            end

            tif_global = fullfile(root_folder_m, ...
                sprintf('Z_projection_%s_%s_%s.tif', ...
                label_clean, animal_clean, age_clean));

            % si existe déjà : ne pas recalculer
            if isfile(tif_global)
                fprintf('Z projection already exists, skipping %s\n', tif_global);
                continue;
            end

            mean_all = mean(cat(3, valid_imgs{:}), 3);
            mean_all_uint16 = uint16(max(min(mean_all, 65535), 0));

            imwrite(mean_all_uint16, tif_global);
            fprintf('Saved %s\n', tif_global);

        else
            fprintf('Folder %d : un seul plan -> pas de Z projection\n', m);
        end
    end
end