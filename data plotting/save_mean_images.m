function meanImgs = save_mean_images( ...
    label, ...
    current_animal_group, ...
    current_ages_group, ...
    gcamp_output_folders, ...
    current_gcamp_folders_group)

    % SAVE_MEAN_IMAGES
    %
    % Génère et sauvegarde une image moyenne brute pour chaque plan.
    %
    % Sortie :
    %   meanImgs{m}{p}
    %
    %   m = index de l'acquisition
    %   p = index du plan
    %
    % Si l'image TIF existe déjà, elle est chargée sans recalcul.

    numAcquisitions = numel(current_gcamp_folders_group);

    meanImgs = cell(1, numAcquisitions);

    label_clean = strrep(char(string(label)), ' ', '_');
    animal_clean = strrep( ...
        char(string(current_animal_group)), ...
        ' ', '_');

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MEAN IMAGE PROCESSING\n');
    fprintf('Animal : %s\n', char(string(current_animal_group)));
    fprintf('Channel: %s\n', char(string(label)));
    fprintf('Acquisitions: %d\n', numAcquisitions);

    for m = 1:numAcquisitions

        fall_paths = current_gcamp_folders_group{m};

        if isempty(fall_paths)
            fall_paths = {};
        elseif ischar(fall_paths) || isstring(fall_paths)
            fall_paths = {char(fall_paths)};
        end

        nPlanes = numel(fall_paths);
        meanImgs{m} = cell(nPlanes, 1);

        age_name = get_age_name(current_ages_group, m);
        acquisition_name = get_acquisition_name( ...
            fall_paths, ...
            gcamp_output_folders, ...
            m);

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('Acquisition %d/%d\n', m, numAcquisitions);
        fprintf('TSeries : %s\n', acquisition_name);
        fprintf('Age     : %s\n', age_name);
        fprintf('Channel : %s\n', char(string(label)));
        fprintf('Planes  : %d\n', nPlanes);
        fprintf('------------------------------------------------------------\n');

        if nPlanes == 0
            fprintf('Status  : no plane available for this channel.\n');
            continue;
        end

        valid_mask = false(nPlanes, 1);

        %% =========================================================
        % PROCESSING BY PLANE
        % ==========================================================

        for p = 1:nPlanes

            fprintf('\n');
            fprintf('  Plane %d/%d\n', p, nPlanes);

            output_folder_plane = get_output_plane_folder( ...
                gcamp_output_folders, ...
                m, ...
                p);

            if isempty(output_folder_plane)

                warning( ...
                    'save_mean_images:MissingOutputFolder', ...
                    ['Acquisition %d/%d | Plane %d/%d | ' ...
                    'missing output folder.'], ...
                    m, numAcquisitions, p, nPlanes);

                fprintf('    Status: skipped because output folder is missing.\n');
                continue;
            end

            age_clean = strrep(age_name, ' ', '_');

            tif_filename = fullfile( ...
                output_folder_plane, ...
                sprintf( ...
                    'Mean_image_%s_of_%s_%s_plane%d.tif', ...
                    label_clean, ...
                    animal_clean, ...
                    age_clean, ...
                    p - 1));

            % -----------------------------------------------------
            % Load existing mean image
            % -----------------------------------------------------

            if isfile(tif_filename)

                try
                    meanImgs{m}{p} = double(imread(tif_filename));
                    valid_mask(p) = true;

                    fprintf('    Status: existing mean image loaded.\n');
                    fprintf('    File  : %s\n', tif_filename);

                    continue;

                catch ME

                    warning( ...
                        'save_mean_images:ExistingImageReadFailed', ...
                        ['Acquisition %d/%d | Plane %d/%d | ' ...
                        'unable to read existing image: %s'], ...
                        m, numAcquisitions, p, nPlanes, ME.message);

                    fprintf('    Status: existing file unreadable; recalculation attempted.\n');
                end
            end

            % -----------------------------------------------------
            % Validate Suite2p plane path
            % -----------------------------------------------------

            fall_path = fall_paths{p};

            if isempty(fall_path)

                warning( ...
                    'save_mean_images:EmptySuite2pPath', ...
                    ['Acquisition %d/%d | Plane %d/%d | ' ...
                    'empty Suite2p path.'], ...
                    m, numAcquisitions, p, nPlanes);

                fprintf('    Status: skipped because Suite2p path is empty.\n');
                continue;
            end

            fall_path = char(string(fall_path));

            if isfolder(fall_path)

                plane_dir = fall_path;

            elseif isfile(fall_path)

                plane_dir = fileparts(fall_path);

            else

                warning( ...
                    'save_mean_images:InvalidSuite2pPath', ...
                    ['Acquisition %d/%d | Plane %d/%d | ' ...
                    'invalid Suite2p path: %s'], ...
                    m, numAcquisitions, p, nPlanes, fall_path);

                fprintf('    Status: skipped because Suite2p path is invalid.\n');
                continue;
            end

            fprintf('    Suite2p: %s\n', plane_dir);

            ops_npy = fullfile(plane_dir, 'ops.npy');
            ops_mat = fullfile(plane_dir, 'ops.mat');

            % -----------------------------------------------------
            % Load Suite2p mean image
            % -----------------------------------------------------

            meanImg = [];

            if exist(ops_npy, 'file') == 2

                try
                    mod = py.importlib.import_module( ...
                        'python_function');

                    ops = mod.read_npy_file(ops_npy);
                    meanImg = double(ops{'meanImg'});

                    fprintf('    Source: ops.npy\n');

                catch ME

                    warning( ...
                        'save_mean_images:OpsNpyReadFailed', ...
                        ['Acquisition %d/%d | Plane %d/%d | ' ...
                        'unable to read ops.npy: %s'], ...
                        m, numAcquisitions, p, nPlanes, ME.message);

                    fprintf('    Status: ops.npy could not be read.\n');
                    continue;
                end

            elseif exist(ops_mat, 'file') == 2

                try
                    data_ops = load(ops_mat);

                    if ~isfield(data_ops, 'ops') || ...
                            ~isfield(data_ops.ops, 'meanImg')

                        error( ...
                            'The variable ops.meanImg is missing.');
                    end

                    meanImg = double(data_ops.ops.meanImg);

                    fprintf('    Source: ops.mat\n');

                catch ME

                    warning( ...
                        'save_mean_images:OpsMatReadFailed', ...
                        ['Acquisition %d/%d | Plane %d/%d | ' ...
                        'unable to read ops.mat: %s'], ...
                        m, numAcquisitions, p, nPlanes, ME.message);

                    fprintf('    Status: ops.mat could not be read.\n');
                    continue;
                end

            else

                warning( ...
                    'save_mean_images:MissingOpsFile', ...
                    ['Acquisition %d/%d | Plane %d/%d | ' ...
                    'no ops.npy or ops.mat in %s'], ...
                    m, numAcquisitions, p, nPlanes, plane_dir);

                fprintf('    Status: no Suite2p ops file found.\n');
                continue;
            end

            if isempty(meanImg)

                fprintf('    Status: Suite2p mean image is empty.\n');
                continue;
            end

            % -----------------------------------------------------
            % Store and save raw mean image
            % -----------------------------------------------------

            meanImgs{m}{p} = meanImg;
            valid_mask(p) = true;

            meanImg_uint16 = uint16( ...
                max(min(meanImg, 65535), 0));

            try
                imwrite(meanImg_uint16, tif_filename);

                fprintf('    Status: mean image created and saved.\n');
                fprintf('    File  : %s\n', tif_filename);

            catch ME

                warning( ...
                    'save_mean_images:ImageWriteFailed', ...
                    ['Acquisition %d/%d | Plane %d/%d | ' ...
                    'unable to save mean image: %s'], ...
                    m, numAcquisitions, p, nPlanes, ME.message);

                fprintf('    Status: image calculated but not saved.\n');
            end
        end

        %% =========================================================
        % Z PROJECTION
        % ==========================================================

        valid_imgs = meanImgs{m}(valid_mask);
        numValidPlanes = numel(valid_imgs);

        fprintf('\n');
        fprintf('  Z projection\n');

        if numValidPlanes > 1

            root_folder_m = get_acquisition_output_root( ...
                gcamp_output_folders, m);

            if isempty(root_folder_m)

                warning( ...
                    'save_mean_images:MissingProjectionOutputFolder', ...
                    ['Acquisition %d/%d | missing root output ' ...
                    'folder for Z projection.'], ...
                    m, numAcquisitions);

                fprintf('    Status: Z projection skipped; output folder missing.\n');
                continue;
            end

            age_clean = strrep(age_name, ' ', '_');

            tif_global = fullfile( ...
                root_folder_m, ...
                sprintf( ...
                    'Z_projection_%s_%s_%s.tif', ...
                    label_clean, ...
                    animal_clean, ...
                    age_clean));

            if isfile(tif_global)

                fprintf('    Status: existing Z projection retained.\n');
                fprintf('    File  : %s\n', tif_global);

                continue;
            end

            try
                mean_all = mean(cat(3, valid_imgs{:}), 3);

                mean_all_uint16 = uint16( ...
                    max(min(mean_all, 65535), 0));

                imwrite(mean_all_uint16, tif_global);

                fprintf('    Status: Z projection created from %d planes.\n', ...
                    numValidPlanes);
                fprintf('    File  : %s\n', tif_global);

            catch ME

                warning( ...
                    'save_mean_images:ZProjectionFailed', ...
                    ['Acquisition %d/%d | unable to generate ' ...
                    'Z projection: %s'], ...
                    m, numAcquisitions, ME.message);

                fprintf('    Status: Z projection failed.\n');
            end

        elseif numValidPlanes == 1

            fprintf(['    Status: not required; acquisition contains ' ...
                'one valid plane.\n']);

        else

            fprintf(['    Status: not generated; no valid mean image ' ...
                'available.\n']);
        end
    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MEAN IMAGE PROCESSING COMPLETED\n');
    fprintf('Animal : %s\n', char(string(current_animal_group)));
    fprintf('Channel: %s\n', char(string(label)));
    fprintf('============================================================\n');
end


% =====================================================================
% Helpers
% =====================================================================

function age_name = get_age_name(current_ages_group, m)

    age_name = 'age_unknown';

    if isempty(current_ages_group) || m > numel(current_ages_group)
        return;
    end

    current_age = current_ages_group{m};

    if isempty(current_age)
        return;
    end

    age_name = char(string(current_age));
end


function output_folder_plane = get_output_plane_folder( ...
    gcamp_output_folders, m, p)

    output_folder_plane = '';

    if isempty(gcamp_output_folders) || ...
            m > numel(gcamp_output_folders) || ...
            isempty(gcamp_output_folders{m})

        return;
    end

    folders_m = gcamp_output_folders{m};

    if ischar(folders_m) || isstring(folders_m)

        if p == 1
            output_folder_plane = char(folders_m);
        end

        return;
    end

    if ~iscell(folders_m) || ...
            p > numel(folders_m) || ...
            isempty(folders_m{p})

        return;
    end

    output_folder_plane = char(string(folders_m{p}));
end


function root_folder_m = get_acquisition_output_root( ...
    gcamp_output_folders, m)

    root_folder_m = '';

    output_folder_plane = get_output_plane_folder( ...
        gcamp_output_folders, m, 1);

    if isempty(output_folder_plane)
        return;
    end

    root_folder_m = fileparts(output_folder_plane);
end


function acquisition_name = get_acquisition_name( ...
    fall_paths, gcamp_output_folders, m)

    acquisition_name = sprintf('Acquisition_%d', m);

    candidate_path = '';

    if ~isempty(fall_paths)

        first_path = fall_paths{1};

        if ~isempty(first_path)
            candidate_path = char(string(first_path));
        end
    end

    if isempty(candidate_path)

        candidate_path = get_output_plane_folder( ...
            gcamp_output_folders, m, 1);
    end

    if isempty(candidate_path)
        return;
    end

    acquisition_name = find_tseries_name_in_path(candidate_path);
end


function tseries_name = find_tseries_name_in_path(path_value)

    tseries_name = '';

    path_value = char(string(path_value));

    while ~isempty(path_value)

        [parent_path, current_name] = fileparts(path_value);

        if startsWith( ...
                current_name, ...
                'TSeries-', ...
                'IgnoreCase', true)

            tseries_name = current_name;
            return;
        end

        if isempty(parent_path) || strcmp(parent_path, path_value)
            break;
        end

        path_value = parent_path;
    end

    if isempty(tseries_name)
        tseries_name = 'TSeries_unknown';
    end
end