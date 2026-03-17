function [data, fields] = process_gcamp_cells( ...
    gcamp_output_folders, ...
    current_xml_group, meta_tbl, ...
    sampling_rate_group, synchronous_frames_group, ...
    current_gcamp_folders_group, ...
    current_animal_group, current_ages_group, ...
    data, fields, meanImgs_gcamp, ...
    current_gcamp_TSeries_path, speed_active_group)

% PROCESS_GCAMP (version "par plan")
% Sauvegarde uniquement s'il y a de nouvelles données renvoyées par
% peak_detection_tuner, en viewer_mode ou non.

    numFolders = numel(gcamp_output_folders);

    % ==============================
    % 0) Définition des champs GCaMP
    % ==============================
    fields_gcamp = { ...
        'F_gcamp_by_plane', 'F_deconv_gcamp_by_plane', ...
        'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', 'valid_gcamp_cells_by_plane', ...
        'DF_gcamp_by_plane', 'Raster_gcamp_by_plane', ...
        'Acttmp2_gcamp_by_plane', 'StartEnd_gcamp_by_plane', ...
        'MAct_gcamp_by_plane', 'thresholds_gcamp_by_plane', ...
        'bad_segs_gcamp_plane', ...
        'stat_by_plane', 'iscell_gcamp_by_plane', ...
        'stat_false_by_plane', 'iscell_false_by_plane', ...
        'outlines_gcampx_by_plane', 'outlines_gcampy_by_plane', ...
        'gcamp_mask_by_plane', 'gcamp_props_by_plane', ...
        'imageHeight_by_plane', 'imageWidth_by_plane', ...
        'outlines_gcampx_false_by_plane', 'outlines_gcampy_false_by_plane', ...
        'gcamp_mask_false_by_plane', 'gcamp_props_false_by_plane', ...
        'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', ...
        'Sm_gcamp_by_plane', 'ops_detections_by_plane' ...
    };

    if isempty(fields)
        fields = fields_gcamp;
    else
        fields = unique([fields(:); fields_gcamp(:)]);
    end

    % ==============================
    % 1) Initialiser / compléter data
    % ==============================
    data = init_data_struct_if_needed(data, numFolders, fields);

    % ==============================
    % 2) Boucle sur les groupes m
    % ==============================
    for m = 1:numFolders

        filePath = fullfile(gcamp_output_folders{m}, 'results.mat');

        % Charger existant si présent
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:numel(fields)
                data.(fields{f}){m} = getFieldOrDefault(loaded, fields{f}, []);
            end
        end

        %------------------------------------------------------
        % 2.b) chemins planes
        %------------------------------------------------------
        if isempty(current_gcamp_folders_group) || m > numel(current_gcamp_folders_group)
            gcamp_planes_for_session_m = {};
        else
            gcamp_planes_for_session_m = current_gcamp_folders_group{m};
        end

        nPlanes = numel(gcamp_planes_for_session_m);

        meanImgs_m = meanImgs_gcamp{m};
        current_gcamp_TSeries_path_m = current_gcamp_TSeries_path{m};

        % flag global : ne sauvegarder que si au moins un plan a changé
        has_new_data_for_group = false;

        %------------------------------------------------------
        % 2.c) allocation si nécessaire
        %------------------------------------------------------
        alloc_if_empty = @(fieldName) ...
            ( isempty(data.(fieldName){m}) || numel(data.(fieldName){m}) ~= nPlanes );

        if alloc_if_empty('F_gcamp_by_plane')
            data.F_gcamp_by_plane{m}               = cell(nPlanes,1);
            data.F_deconv_gcamp_by_plane{m}        = cell(nPlanes,1);
            data.F0_gcamp_by_plane{m}              = cell(nPlanes,1);
            data.noise_est_gcamp_by_plane{m}       = cell(nPlanes,1);
            data.valid_gcamp_cells_by_plane{m}     = cell(nPlanes,1);
            data.DF_gcamp_by_plane{m}              = cell(nPlanes,1);
            data.Raster_gcamp_by_plane{m}          = cell(nPlanes,1);
            data.Acttmp2_gcamp_by_plane{m}         = cell(nPlanes,1);
            data.StartEnd_gcamp_by_plane{m}        = cell(nPlanes,1);
            data.MAct_gcamp_by_plane{m}            = cell(nPlanes,1);
            data.thresholds_gcamp_by_plane{m}      = cell(nPlanes,1);
            data.bad_segs_gcamp_plane{m}           = cell(nPlanes,1);

            data.stat_by_plane{m}                  = cell(nPlanes,1);
            data.iscell_gcamp_by_plane{m}          = cell(nPlanes,1);
            data.stat_false_by_plane{m}            = cell(nPlanes,1);
            data.iscell_false_by_plane{m}          = cell(nPlanes,1);

            data.outlines_gcampx_by_plane{m}       = cell(nPlanes,1);
            data.outlines_gcampy_by_plane{m}       = cell(nPlanes,1);
            data.gcamp_mask_by_plane{m}            = cell(nPlanes,1);
            data.gcamp_props_by_plane{m}           = cell(nPlanes,1);
            data.imageHeight_by_plane{m}           = cell(nPlanes,1);
            data.imageWidth_by_plane{m}            = cell(nPlanes,1);

            data.outlines_gcampx_false_by_plane{m} = cell(nPlanes,1);
            data.outlines_gcampy_false_by_plane{m} = cell(nPlanes,1);
            data.gcamp_mask_false_by_plane{m}      = cell(nPlanes,1);
            data.gcamp_props_false_by_plane{m}     = cell(nPlanes,1);

            data.isort1_gcamp_by_plane{m}          = cell(nPlanes,1);
            data.isort2_gcamp_by_plane{m}          = cell(nPlanes,1);
            data.Sm_gcamp_by_plane{m}              = cell(nPlanes,1);
            data.ops_detections_by_plane{m}        = cell(nPlanes,1);
        end

        %------------------------------------------------------
        % 2.d) boucle par plan
        %------------------------------------------------------
        for p = 1:nPlanes

            fall_path = gcamp_planes_for_session_m{p};
            meanImg_plane = meanImgs_m{p};
            gcamp_TSeries_path_plane = fullfile( ...
                current_gcamp_TSeries_path_m, ...
                sprintf('plane%d', p-1), ...
                'Concatenated.tif');

            if isempty(fall_path)
                fprintf('Group %d, plan %d: invalid fall_path, skipping.\n', m, p);
                continue;
            end

            % load_data sur ce plan
            [~, F_gcamp, F_deconv_gcamp, ops, stat, iscell, stat_false, iscell_false] = ...
                load_data(fall_path);

            if isempty(F_gcamp)
                fprintf('Group %d, plan %d: empty F_gcamp, skipping.\n', m, p);
                continue;
            end

            % brute toujours gardée en mémoire
            data.F_gcamp_by_plane{m}{p}        = F_gcamp;
            data.F_deconv_gcamp_by_plane{m}{p} = F_deconv_gcamp;
            data.stat_by_plane{m}{p}           = stat;
            data.iscell_gcamp_by_plane{m}{p}   = iscell;
            data.stat_false_by_plane{m}{p}     = stat_false;
            data.iscell_false_by_plane{m}{p}   = iscell_false;

            % Déterminer le mode : viewer si DF déjà présent, sinon édition
            viewer_mode_this_plane = ~isempty(data.DF_gcamp_by_plane{m}) && ...
                                     numel(data.DF_gcamp_by_plane{m}) >= p && ...
                                     ~isempty(data.DF_gcamp_by_plane{m}{p});

            if viewer_mode_this_plane
                F_for_view = F_gcamp;
            else
                F_for_view = F_gcamp;
            end

            %---------------------------------------
            % Peak detection par plan
            %---------------------------------------
            [F0_gcamp, noise_est_gcamp, SNR_gcamp, ...
             valid_gcamp_cells_plane, DF_gcamp_plane, Raster_gcamp_plane, ...
             Acttmp2_gcamp_plane, StartEnd_gcamp_plane, ...
             MAct_gcamp_plane, thresholds_gcamp_plane, bad_segs_gcamp_plane, ...
             ops_detection, has_new_outputs] = ...
                peak_detection_tuner(F_for_view, ...
                                     sampling_rate_group{m}, ...
                                     synchronous_frames_group{m}, ...
                                     'animal_group', current_animal_group, ...
                                     'ages_group',   current_ages_group{m}, ...
                                     'viewer_mode', viewer_mode_this_plane, ...
                                     'ops', ops, ...
                                     'iscell', iscell, ...
                                     'stat', stat, ...
                                     'meanImg', meanImg_plane, ...
                                     'gcamp_TSeries_path', gcamp_TSeries_path_plane, ...
                                     'speed', speed_active_group{m}, ...
                                     'meta_tbl', meta_tbl(m,:));

            % Si aucune nouvelle sortie -> ne rien écraser
            if ~has_new_outputs
                fprintf('Group %d, plane %d: no new outputs from peak_detection_tuner, skipping save/update.\n', m, p);
                continue;
            end

            has_new_data_for_group = true;

            %---------------------------------------
            % Stockage détection
            %---------------------------------------
            data.F0_gcamp_by_plane{m}{p}          = F0_gcamp;
            data.noise_est_gcamp_by_plane{m}{p}   = noise_est_gcamp;
            data.valid_gcamp_cells_by_plane{m}{p} = valid_gcamp_cells_plane;
            data.DF_gcamp_by_plane{m}{p}          = DF_gcamp_plane;
            data.Raster_gcamp_by_plane{m}{p}      = Raster_gcamp_plane;
            data.Acttmp2_gcamp_by_plane{m}{p}     = Acttmp2_gcamp_plane;
            data.StartEnd_gcamp_by_plane{m}{p}    = StartEnd_gcamp_plane;
            data.MAct_gcamp_by_plane{m}{p}        = MAct_gcamp_plane;
            data.thresholds_gcamp_by_plane{m}{p}  = thresholds_gcamp_plane;
            data.bad_segs_gcamp_plane{m}{p}       = bad_segs_gcamp_plane;
            data.ops_detections_by_plane{m}       = ops_detection;

            %---------------------------------------
            % Masques & outlines vraies cellules
            %---------------------------------------
            [~, outlines_gcampx_plane, outlines_gcampy_plane, ~, ~, ~] = ...
                load_calcium_mask(iscell, stat, valid_gcamp_cells_plane);

            [gcamp_mask_plane, gcamp_props_plane, imageHeight_plane, imageWidth_plane] = ...
                process_poly2mask(stat, valid_gcamp_cells_plane, ...
                                  outlines_gcampx_plane, outlines_gcampy_plane);

            data.outlines_gcampx_by_plane{m}{p} = outlines_gcampx_plane;
            data.outlines_gcampy_by_plane{m}{p} = outlines_gcampy_plane;
            data.gcamp_mask_by_plane{m}{p}      = gcamp_mask_plane;
            data.gcamp_props_by_plane{m}{p}     = gcamp_props_plane;
            data.imageHeight_by_plane{m}{p}     = imageHeight_plane;
            data.imageWidth_by_plane{m}{p}      = imageWidth_plane;

            %---------------------------------------
            % Masques & outlines faux positifs
            %---------------------------------------
            [NCell_false, outlines_gcampx_false_plane, outlines_gcampy_false_plane, ~, ~, ~] = ...
                load_calcium_mask(iscell_false, stat_false);

            [gcamp_mask_false_plane, gcamp_props_false_plane, ~, ~] = ...
                process_poly2mask(stat_false, NCell_false, ...
                                  outlines_gcampx_false_plane, outlines_gcampy_false_plane);

            data.outlines_gcampx_false_by_plane{m}{p} = outlines_gcampx_false_plane;
            data.outlines_gcampy_false_by_plane{m}{p} = outlines_gcampy_false_plane;
            data.gcamp_mask_false_by_plane{m}{p}      = gcamp_mask_false_plane;
            data.gcamp_props_false_by_plane{m}{p}     = gcamp_props_false_plane;

            %---------------------------------------
            % Tri raster
            %---------------------------------------
            if ~isempty(DF_gcamp_plane) && ~isempty(Raster_gcamp_plane)
                Raster_for_sort = double(Raster_gcamp_plane);

                [isort1_gcamp_plane, isort2_gcamp_plane, Sm_gcamp_plane] = ...
                    raster_processing(Raster_for_sort, fall_path, ops);

                Raster_sorted = Raster_gcamp_plane(isort1_gcamp_plane, :);
                plot_raster_sorted(Raster_sorted, sprintf('Raster trié isort1 — m=%d p=%d', m, p));

                data.isort1_gcamp_by_plane{m}{p} = isort1_gcamp_plane;
                data.isort2_gcamp_by_plane{m}{p} = isort2_gcamp_plane;
                data.Sm_gcamp_by_plane{m}{p}     = Sm_gcamp_plane;
            else
                data.isort1_gcamp_by_plane{m}{p} = [];
                data.isort2_gcamp_by_plane{m}{p} = [];
                data.Sm_gcamp_by_plane{m}{p}     = [];
            end

        end % for p

        %==========================================
        % 2.e) Sauvegarde disque seulement si nouveauté
        %==========================================
        if has_new_data_for_group
            saveStruct = struct();

            for k = 1:numel(fields_gcamp)
                fieldName = fields_gcamp{k};
                if isfield(data, fieldName)
                    saveStruct.(fieldName) = data.(fieldName){m};
                end
            end

            outdir = fileparts(filePath);
            if ~exist(outdir, 'dir')
                mkdir(outdir);
            end

            if exist(filePath, 'file') == 2
                save(filePath, '-struct', 'saveStruct', '-append');
            else
                save(filePath, '-struct', 'saveStruct');
            end

            fprintf('Group %d: results.mat updated.\n', m);
        else
            fprintf('Group %d: no new data, results.mat not modified.\n', m);
        end

    end % for m
end

% ==========================================
% =========== FONCTIONS UTILITAIRES ========
% ==========================================
function data = init_data_struct_if_needed(data, numFolders, fields)
    for f = 1:numel(fields)
        fieldName = fields{f};
        if ~isfield(data, fieldName) || numel(data.(fieldName)) ~= numFolders
            tmpCell = cell(numFolders, 1);
            [tmpCell{:}] = deal([]);
            data.(fieldName) = tmpCell;
        end
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end


function plot_raster_sorted(Raster, figTitle)
% Raster: logical (nCells x T), déjà trié si besoin.

    if nargin < 2 || isempty(figTitle)
        figTitle = 'Raster trié';
    end

    if isempty(Raster) || ~islogical(Raster)
        warning('plot_raster_sorted: Raster vide ou non-logical.');
        return;
    end

    [nC, T] = size(Raster);

    figure('Name', figTitle, 'Color','w');
    ax = axes(); hold(ax,'on'); box(ax,'on');

    [r, c] = find(Raster);
    scatter(ax, c, r, 8, 'k', 'filled');

    xlim(ax, [1 T]);
    ylim(ax, [0.5 nC+0.5]);
    xlabel(ax, 'Frames');
    ylabel(ax, 'Cellules (après tri)');
    title(ax, sprintf('%s — %d cellules x %d frames', figTitle, nC, T));
end