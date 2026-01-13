function [data, fields] = process_blue_cells( ...
                gcamp_output_folders, include_blue_cells, ...
                date_group_paths, ...
                current_gcamp_folders_group, current_red_folders_group, current_blue_folders_group, current_green_folders_group, ...
                current_blue_TSeries_path, ...
                meanImgs_gcamp, ...
                data, fields)
% PROCESS_BLUE_CELLS (version "par plan")
%
% Hypothèses :
%   process_gcamp_cells a déjà rempli, pour chaque groupe m et plan p :
%     - data.F_gcamp_by_plane{m}{p}
%     - data.gcamp_props_by_plane{m}{p}
%     - data.outlines_gcampx_by_plane{m}{p}
%     - data.outlines_gcampy_by_plane{m}{p}
%     - data.iscell_gcamp_by_plane{m}{p}
%     - data.gcamp_props_false_by_plane{m}{p}
%     - data.outlines_gcampx_false_by_plane{m}{p}
%     - data.outlines_gcampy_false_by_plane{m}{p}
%
% Champs BLEU créés par groupe m et par plan p :
%   matched_gcamp_idx_by_plane{m}{p}
%   matched_cellpose_idx_by_plane{m}{p}
%   is_cell_blue_by_plane{m}{p}
%
%   num_cells_mask_by_plane{m}{p}
%   mask_cellpose_by_plane{m}{p}
%   props_cellpose_by_plane{m}{p}
%   outlines_x_cellpose_by_plane{m}{p}
%   outlines_y_cellpose_by_plane{m}{p}
%
%   F_blue_by_plane{m}{p}
%   blue_match_mask_by_plane{m}{p}
%
%   baseline_blue_by_plane{m}{p}
%   valid_blue_cells_by_plane{m}{p}
%   DF_blue_by_plane{m}{p}
%   Raster_blue_by_plane{m}{p}
%   Acttmp2_blue_by_plane{m}{p}
%   StartEnd_blue_by_plane{m}{p}
%   MAct_blue_by_plane{m}{p}
%   thresholds_blue_by_plane{m}{p}


    %======================================================
    % 0) Champs BLEU et initialisation
    %======================================================
    numFolders = numel(gcamp_output_folders);

    fields_blue = { ...
        'matched_gcamp_idx_by_plane', 'matched_cellpose_idx_by_plane', ...
        'is_cell_blue_by_plane', ...
        'num_cells_mask_by_plane', 'mask_cellpose_by_plane', ...
        'props_cellpose_by_plane', ...
        'outlines_x_cellpose_by_plane', 'outlines_y_cellpose_by_plane', ...
        'F_blue_by_plane', 'blue_match_mask_by_plane', ...
        'baseline_blue_by_plane', 'valid_blue_cells_by_plane', ...
        'DF_blue_by_plane', 'Raster_blue_by_plane', ...
        'Acttmp2_blue_by_plane', 'StartEnd_blue_by_plane', ...
        'MAct_blue_by_plane', 'thresholds_blue_by_plane' ...
    };

    if ~isempty(fields)
        fields = unique([fields(:); fields_blue(:)]);
    else
        fields = fields_blue;
    end

    % Initialiser data.*{m}
    data = init_data_struct_if_needed(data, numFolders, fields);

    %======================================================
    % 1) Boucle sur les groupes m
    %======================================================
    for m = 1:numFolders

        filePath = fullfile(gcamp_output_folders{m}, 'results.mat');

        % Charger ce qui existe déjà
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:numel(fields)
                data.(fields{f}){m} = getFieldOrDefault(loaded, fields{f}, []);
            end
        end

        % Pas de bleu demandé → skip
        if ~strcmp(include_blue_cells, '1')
            continue;
        end

        % On suppose que process_gcamp_cells a rempli F_gcamp_by_plane{m}
        if ~isfield(data, 'F_gcamp_by_plane') || ...
           numel(data.F_gcamp_by_plane) < m || ...
           isempty(data.F_gcamp_by_plane{m})
            fprintf('No F_gcamp_by_plane for group %d, skipping blue.\n', m);
            continue;
        end

        F_gcamp_planes = data.F_gcamp_by_plane{m};
        nPlanes        = numel(F_gcamp_planes);

        fprintf('Processing blue cells for group %d (%d planes)...\n', m, nPlanes);

        % Pré-allouer, si pas déjà fait, tous les champs BLEU par plan
        need_alloc = @(fieldName) ...
            (~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m}));

        if need_alloc('matched_gcamp_idx_by_plane')
            data.matched_gcamp_idx_by_plane{m}    = cell(nPlanes,1);
            data.matched_cellpose_idx_by_plane{m} = cell(nPlanes,1);
            data.is_cell_blue_by_plane{m}         = cell(nPlanes,1);

            data.num_cells_mask_by_plane{m}       = cell(nPlanes,1);
            data.mask_cellpose_by_plane{m}        = cell(nPlanes,1);
            data.props_cellpose_by_plane{m}       = cell(nPlanes,1);
            data.outlines_x_cellpose_by_plane{m}  = cell(nPlanes,1);
            data.outlines_y_cellpose_by_plane{m}  = cell(nPlanes,1);

            data.F_blue_by_plane{m}               = cell(nPlanes,1);
            data.blue_match_mask_by_plane{m}      = cell(nPlanes,1);

            data.baseline_blue_by_plane{m}        = cell(nPlanes,1);
            data.valid_blue_cells_by_plane{m}     = cell(nPlanes,1);
            data.DF_blue_by_plane{m}              = cell(nPlanes,1);
            data.Raster_blue_by_plane{m}          = cell(nPlanes,1);
            data.Acttmp2_blue_by_plane{m}         = cell(nPlanes,1);
            data.StartEnd_blue_by_plane{m}        = cell(nPlanes,1);
            data.MAct_blue_by_plane{m}            = cell(nPlanes,1);
            data.thresholds_blue_by_plane{m}      = cell(nPlanes,1);
        end

        % Raccourcis GCaMP par plan (remplis par process_gcamp_cells)
        F_gcamp_by_plane          = data.F_gcamp_by_plane{m};
        gcamp_props_by_plane      = data.gcamp_props_by_plane{m};
        outlines_gx_by_plane      = data.outlines_gcampx_by_plane{m};
        outlines_gy_by_plane      = data.outlines_gcampy_by_plane{m};
        iscell_gcamp_by_plane     = data.iscell_gcamp_by_plane{m};

        % faux positifs par plan
        gcamp_props_false_by_plane    = [];
        outlines_gx_false_by_plane    = [];
        outlines_gy_false_by_plane    = [];
        if isfield(data, 'gcamp_props_false_by_plane') && numel(data.gcamp_props_false_by_plane) >= m
            gcamp_props_false_by_plane = data.gcamp_props_false_by_plane{m};
        end
        if isfield(data, 'outlines_gcampx_false_by_plane') && numel(data.outlines_gcampx_false_by_plane) >= m
            outlines_gx_false_by_plane = data.outlines_gcampx_false_by_plane{m};
        end
        if isfield(data, 'outlines_gcampy_false_by_plane') && numel(data.outlines_gcampy_false_by_plane) >= m
            outlines_gy_false_by_plane = data.outlines_gcampy_false_by_plane{m};
        end

        % chemins suite2p pour cette session
        if isempty(current_gcamp_folders_group) || m > numel(current_gcamp_folders_group)
            gcamp_planes_for_session_m = {};
        else
            gcamp_planes_for_session_m = current_gcamp_folders_group{m};
        end
        if isempty(current_red_folders_group) || m > numel(current_red_folders_group)
            red_planes_for_session_m = {};
        else
            red_planes_for_session_m = current_red_folders_group{m};
        end
        if isempty(current_blue_folders_group) || m > numel(current_blue_folders_group)
            blue_planes_for_session_m = {};
        else
            blue_planes_for_session_m = current_blue_folders_group{m};
        end
        if isempty(current_green_folders_group) || m > numel(current_green_folders_group)
            green_planes_for_session_m = {};
        else
            green_planes_for_session_m = current_green_folders_group{m};
        end

        %=========================
        % BOUCLE UNIQUE sur les plans
        %=========================
        for p = 1:nPlanes

            fprintf('  -> Plan %d\n', p);

            % --- Récup GCaMP plan p ---
            F_gcamp_plane      = F_gcamp_by_plane{p};
            if isempty(F_gcamp_plane)
                fprintf('    Skipping plan %d: empty F_gcamp.\n', p);
                continue;
            end

            gcamp_props_plane  = gcamp_props_by_plane{p};
            outlines_gx_plane  = outlines_gx_by_plane{p};
            outlines_gy_plane  = outlines_gy_by_plane{p};
            iscell_gcamp_plane = iscell_gcamp_by_plane{p};
            meanImg_plane      = meanImgs_gcamp{m}{p};

            % Faux positifs (par plan, si dispo)
            gcamp_props_false_plane   = [];
            outlines_gx_false_plane   = {};
            outlines_gy_false_plane   = {};
            if ~isempty(gcamp_props_false_by_plane) && numel(gcamp_props_false_by_plane) >= p
                gcamp_props_false_plane = gcamp_props_false_by_plane{p};
            end
            if ~isempty(outlines_gx_false_by_plane) && numel(outlines_gx_false_by_plane) >= p
                outlines_gx_false_plane = outlines_gx_false_by_plane{p};
            end
            if ~isempty(outlines_gy_false_by_plane) && numel(outlines_gy_false_by_plane) >= p
                outlines_gy_false_plane = outlines_gy_false_by_plane{p};
            end

            % --- Cellpose / TSeries pour ce plan ---
            [meanImg_channels, aligned_image_plane, npy_file_path, ~] = ...
                load_or_process_cellpose_TSeries( ...
                    filePath, date_group_paths{m}, ...
                    gcamp_planes_for_session_m, ...
                    red_planes_for_session_m, ...
                    blue_planes_for_session_m, ...
                    green_planes_for_session_m, ...
                    current_blue_TSeries_path, p);

            if isempty(npy_file_path)
                fprintf('    Skipping plan %d: no Cellpose output.\n', p);
                continue;
            end

            [num_cells_mask_p, mask_cellpose_p, props_cellpose_p, ...
             outlines_x_p, outlines_y_p] = ...
                load_or_process_cellpose_data(npy_file_path);

            if isempty(props_cellpose_p)
                fprintf('    Skipping plan %d: no Cellpose ROIs.\n', p);
                continue;
            end
            if isempty(meanImg_channels)
                fprintf('    Skipping plan %d: meanImg_channels empty.\n', p);
                continue;
            end
            if isa(meanImg_channels, 'single')
                meanImg_channels = uint16(meanImg_channels);
            end

            %===============================
            % MATCHING GCaMP ↔ Cellpose (plan p)
            %===============================
            R = 5;   % rayon de tolérance

            [matched_gcamp_idx_p, matched_cellpose_idx_p, is_cell_blue_plane] = ...
                show_masks_and_overlaps( ...
                    iscell_gcamp_plane, ...
                    gcamp_props_plane, gcamp_props_false_plane, ...
                    props_cellpose_p, meanImg_plane, aligned_image_plane, ...
                    outlines_gx_plane, outlines_gy_plane, ...
                    outlines_gx_false_plane, outlines_gy_false_plane, ...
                    outlines_x_p, outlines_y_p, ...
                    R, gcamp_output_folders{m});

            data.matched_gcamp_idx_by_plane{m}{p}    = matched_gcamp_idx_p(:);   % indices LOCAUX GCaMP
            data.matched_cellpose_idx_by_plane{m}{p} = matched_cellpose_idx_p(:);
            data.is_cell_blue_by_plane{m}{p}         = is_cell_blue_plane(:);

            %===============================
            % Stockage Cellpose par plan
            %===============================
            data.num_cells_mask_by_plane{m}{p}      = num_cells_mask_p(:);
            data.mask_cellpose_by_plane{m}{p}       = mask_cellpose_p(:);
            data.props_cellpose_by_plane{m}{p}      = props_cellpose_p(:);
            data.outlines_x_cellpose_by_plane{m}{p} = outlines_x_p(:);
            data.outlines_y_cellpose_by_plane{m}{p} = outlines_y_p(:);

            %===============================
            % EXTRACTION DES TRACES BLEUES (plan p)
            %===============================
            mode = "all";
            F_blue_p = get_blue_cells_rois( ...
                    F_gcamp_plane, [], ...
                    num_cells_mask_p, mask_cellpose_p, ...
                    props_cellpose_p, outlines_x_p, outlines_y_p, ...
                    gcamp_planes_for_session_m{p}, mode);

            if ~isempty(F_blue_p)
                F_blue_p = double(F_blue_p);
            else
                F_blue_p = [];
            end
            data.F_blue_by_plane{m}{p} = F_blue_p;

            % masque match / pas-match dans Cellpose (indices locaux)
            nBlueP = size(F_blue_p, 1);
            blue_match_mask_p = false(nBlueP, 1);
            if ~isempty(matched_cellpose_idx_p)
                valid_idx = matched_cellpose_idx_p( ...
                    matched_cellpose_idx_p >= 1 & matched_cellpose_idx_p <= nBlueP);
                blue_match_mask_p(valid_idx) = true;
            end
            data.blue_match_mask_by_plane{m}{p} = blue_match_mask_p;

            %===============================
            % PEAK DETECTION BLEUE - PAR PLAN
            %===============================
            if ~isempty(F_blue_p)
                [~, baseline_blue_p, noise_est_blue_p, SNR_blue_p, valid_blue_cells_p, ...
                 DF_blue_p, Raster_blue_p, Acttmp2_blue_p, StartEnd_blue_p, MAct_blue_p, thresholds_blue_p] = ...
                    peak_detection_tuner(F_blue_p, ...
                                         data.sampling_rate{m}, ...
                                         data.synchronous_frames{m}, ...
                                         'nogui', true);

                data.baseline_blue_by_plane{m}{p}    = baseline_blue_p;
                data.valid_blue_cells_by_plane{m}{p} = valid_blue_cells_p;
                data.DF_blue_by_plane{m}{p}          = DF_blue_p;
                data.Raster_blue_by_plane{m}{p}      = Raster_blue_p;
                data.Acttmp2_blue_by_plane{m}{p}     = Acttmp2_blue_p;
                data.StartEnd_blue_by_plane{m}{p}    = StartEnd_blue_p;
                data.MAct_blue_by_plane{m}{p}        = MAct_blue_p;
                data.thresholds_blue_by_plane{m}{p}  = thresholds_blue_p;
            else
                data.baseline_blue_by_plane{m}{p}    = [];
                data.valid_blue_cells_by_plane{m}{p} = [];
                data.DF_blue_by_plane{m}{p}          = [];
                data.Raster_blue_by_plane{m}{p}      = [];
                data.Acttmp2_blue_by_plane{m}{p}     = [];
                data.StartEnd_blue_by_plane{m}{p}    = [];
                data.MAct_blue_by_plane{m}{p}        = [];
                data.thresholds_blue_by_plane{m}{p}  = [];
            end

        end % for p = 1:nPlanes

        %======================================================
        % 2.x) Sauvegarder results.mat pour ce groupe m
        %======================================================
        saveStruct = struct();
        for f = 1:numel(fields_blue)
            fieldName = fields_blue{f};
            if isfield(data, fieldName)
                saveStruct.(fieldName) = data.(fieldName){m};
            end
        end

        if ~exist(fileparts(filePath), 'dir')
            mkdir(fileparts(filePath));
        end

        if exist(filePath, 'file') == 2
            save(filePath, '-struct', 'saveStruct', '-append');
        else
            save(filePath, '-struct', 'saveStruct');
        end

    end % for m

end % function process_blue_cells


% =========================================================
% =============== FONCTIONS UTILITAIRES ===================
% =========================================================

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
