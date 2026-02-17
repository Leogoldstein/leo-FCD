function [data, fields] = process_gcamp_cells( ...
    gcamp_output_folders, ...
    current_xml_group, meta_tbl, ...
    current_gcamp_folders_group, ...
    current_animal_group, current_ages_group, ...
    data, fields)

% PROCESS_GCAMP (version "par plan")
%   Pour chaque groupe m :
%     - initialise / complète data et fields pour les champs GCaMP
%     - charge results.mat si présent
%     - récupère sampling_rate et synchronous_frames
%     - pour chaque plan p :
%         * load_data(fall_path)
%         * peak_detection_tuner(F_gcamp_plane)
%         * masque & outlines (vrais et faux positifs)
%         * (optionnel) isort / raster_processing par plan
%     - sauvegarde toutes les variables GCaMP par plan dans results.mat
%
% Stockage :
%   Tous les champs GCaMP sont de la forme field{m}{p} (par plan), sauf
%   sampling_rate{m} et synchronous_frames{m}.

    numFolders = numel(gcamp_output_folders);

    % ==============================
    % 0) Définition des champs GCaMP (version par plan)
    % ==============================
    fields_gcamp = { ...
        'sampling_rate', 'synchronous_frames', ...
        'F_gcamp_by_plane', 'F_deconv_gcamp_by_plane', ...
        'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', 'valid_gcamp_cells_by_plane', ...
        'DF_gcamp_by_plane', 'Raster_gcamp_by_plane', ...
        'Acttmp2_gcamp_by_plane', 'StartEnd_gcamp_by_plane', ...
        'MAct_gcamp_by_plane', 'thresholds_gcamp_by_plane', ...
        ...
        'stat_by_plane', 'iscell_gcamp_by_plane', ...
        'stat_false_by_plane', 'iscell_false_by_plane', ...
        ...
        'outlines_gcampx_by_plane', 'outlines_gcampy_by_plane', ...
        'gcamp_mask_by_plane', 'gcamp_props_by_plane', ...
        'imageHeight_by_plane', 'imageWidth_by_plane', ...
        ...
        'outlines_gcampx_false_by_plane', 'outlines_gcampy_false_by_plane', ...
        'gcamp_mask_false_by_plane', 'gcamp_props_false_by_plane', ...
        ...
        'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', ...
        'Sm_gcamp_by_plane' ...
    };

    % Compléter la liste globale "fields"
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

        % Charger les données existantes si results.mat existe déjà
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:numel(fields)
                data.(fields{f}){m} = getFieldOrDefault(loaded, fields{f}, []);
            end
        end

        %------------------------------------------------------
        % 2.a) Sampling rate et synchronous_frames
        %------------------------------------------------------
        this_xml = current_xml_group{m};

        % Sampling rate
        if isempty(data.sampling_rate{m})
            idx_meta = strcmp(meta_tbl.Filename, this_xml);

            if any(idx_meta)
                data.sampling_rate{m} = meta_tbl.SamplingRate(idx_meta);
            else
                warning('SamplingRate not found in metadata_results for %s, using find_key_value.', this_xml);
                [~, sampling_rate, ~, ~] = find_key_value(this_xml);
                data.sampling_rate{m} = sampling_rate;
            end
        end

        % synchronous_frames (ex : 200 ms de fenêtre)
        if isempty(data.synchronous_frames{m})
            data.synchronous_frames{m} = round(0.2 * data.sampling_rate{m});
        end

        %------------------------------------------------------
        % 2.b) Récupérer les chemins GCaMP plane par plane pour ce groupe m
        %------------------------------------------------------
        if isempty(current_gcamp_folders_group) || m > numel(current_gcamp_folders_group)
            gcamp_planes_for_session_m = {};
        else
            gcamp_planes_for_session_m = current_gcamp_folders_group{m};  % cell 1×nPlanes
        end

        nPlanes = numel(gcamp_planes_for_session_m);

        % Si déjà calculé (par ex. F_gcamp_by_plane plein), on peut sauter
        if ~isempty(data.DF_gcamp_by_plane{m})
            % On suppose que tout est déjà calculé pour ce m
            continue;
        end

        % Préparer les cell(nPlanes,1) pour tous les champs par plan
        alloc_if_empty = @(fieldName) ...
            ( isempty(data.(fieldName){m}) || numel(data.(fieldName){m}) ~= nPlanes );

        if alloc_if_empty('F_gcamp_by_plane')
            data.F_gcamp_by_plane{m}            = cell(nPlanes,1);
            data.F_deconv_gcamp_by_plane{m}     = cell(nPlanes,1);
            data.F0_gcamp_by_plane{m}     = cell(nPlanes,1);
            data.noise_est_gcamp_by_plane{m}    = cell(nPlanes,1);
            data.valid_gcamp_cells_by_plane{m}  = cell(nPlanes,1);
            data.DF_gcamp_by_plane{m}           = cell(nPlanes,1);
            data.Raster_gcamp_by_plane{m}       = cell(nPlanes,1);
            data.Acttmp2_gcamp_by_plane{m}      = cell(nPlanes,1);
            data.StartEnd_gcamp_by_plane{m}     = cell(nPlanes,1);
            data.MAct_gcamp_by_plane{m}         = cell(nPlanes,1);
            data.thresholds_gcamp_by_plane{m}   = cell(nPlanes,1);

            data.stat_by_plane{m}               = cell(nPlanes,1);
            data.iscell_gcamp_by_plane{m}       = cell(nPlanes,1);
            data.stat_false_by_plane{m}         = cell(nPlanes,1);
            data.iscell_false_by_plane{m}       = cell(nPlanes,1);

            data.outlines_gcampx_by_plane{m}    = cell(nPlanes,1);
            data.outlines_gcampy_by_plane{m}    = cell(nPlanes,1);
            data.gcamp_mask_by_plane{m}         = cell(nPlanes,1);
            data.gcamp_props_by_plane{m}        = cell(nPlanes,1);
            data.imageHeight_by_plane{m}        = cell(nPlanes,1);
            data.imageWidth_by_plane{m}         = cell(nPlanes,1);

            data.outlines_gcampx_false_by_plane{m} = cell(nPlanes,1);
            data.outlines_gcampy_false_by_plane{m} = cell(nPlanes,1);
            data.gcamp_mask_false_by_plane{m}      = cell(nPlanes,1);
            data.gcamp_props_false_by_plane{m}     = cell(nPlanes,1);

            data.isort1_gcamp_by_plane{m}       = cell(nPlanes,1);
            data.isort2_gcamp_by_plane{m}       = cell(nPlanes,1);
            data.Sm_gcamp_by_plane{m}           = cell(nPlanes,1);
        end

        %===============================
        % 2.c) Boucle par PLAN
        %===============================
        for p = 1:nPlanes

            fall_path = gcamp_planes_for_session_m{p};

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

            % Sauvegarde brute
            data.F_gcamp_by_plane{m}{p}        = F_gcamp;
            data.F_deconv_gcamp_by_plane{m}{p} = F_deconv_gcamp;
            data.stat_by_plane{m}{p}           = stat;
            data.iscell_gcamp_by_plane{m}{p}   = iscell;
            data.stat_false_by_plane{m}{p}     = stat_false;
            data.iscell_false_by_plane{m}{p}   = iscell_false;

            %---------------------------------------
            % 2.c.1 Peak detection par plan
            %---------------------------------------
            [~, F0_gcamp, noise_est_gcamp, SNR_gcamp, ...
             valid_gcamp_cells_plane, DF_gcamp_plane, Raster_gcamp_plane, ...
             Acttmp2_gcamp_plane, StartEnd_gcamp_plane, ...
             MAct_gcamp_plane, thresholds_gcamp_plane] = ...
                peak_detection_tuner(F_gcamp, ...
                                     data.sampling_rate{m}, ...
                                     data.synchronous_frames{m}, ...
                                     'animal_group', current_animal_group, ...
                                     'ages_group',   current_ages_group{m}, ...
                                     'nogui', false, ...
                                     'ops', ops);
s
            data.F0_gcamp_by_plane{m}{p}    = F0_gcamp;
            data.noise_est_gcamp_by_plane{m}{p}    = noise_est_gcamp;
            data.valid_gcamp_cells_by_plane{m}{p} = valid_gcamp_cells_plane;
            data.DF_gcamp_by_plane{m}{p}          = DF_gcamp_plane;
            data.Raster_gcamp_by_plane{m}{p}      = Raster_gcamp_plane;
            data.Acttmp2_gcamp_by_plane{m}{p}     = Acttmp2_gcamp_plane;
            data.StartEnd_gcamp_by_plane{m}{p}    = StartEnd_gcamp_plane;
            data.MAct_gcamp_by_plane{m}{p}        = MAct_gcamp_plane;
            data.thresholds_gcamp_by_plane{m}{p}  = thresholds_gcamp_plane;

            %---------------------------------------
            % 2.c.2 Masques & outlines VRAIES cellules
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
            % 2.c.3 Masques & outlines FAUX positifs
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
            % 2.c.4 Tri (isort) par plan (optionnel)
            %---------------------------------------
            if ~isempty(DF_gcamp_plane)
                [isort1_gcamp_plane, isort2_gcamp_plane, Sm_gcamp_plane] = ...
                    raster_processing(DF_gcamp_plane, fall_path, ops);

                data.isort1_gcamp_by_plane{m}{p} = isort1_gcamp_plane;
                data.isort2_gcamp_by_plane{m}{p} = isort2_gcamp_plane;
                data.Sm_gcamp_by_plane{m}{p}     = Sm_gcamp_plane;
            else
                data.isort1_gcamp_by_plane{m}{p} = [];
                data.isort2_gcamp_by_plane{m}{p} = [];
                data.Sm_gcamp_by_plane{m}{p}     = [];
            end

        end % for p = 1:nPlanes

        %==========================================
        % 2.d) Sauvegarder tous les champs GCaMP pour ce m
        %==========================================
        saveStruct = struct();

        for k = 1:numel(fields_gcamp)
            fieldName = fields_gcamp{k};
            if isfield(data, fieldName)
                saveStruct.(fieldName) = data.(fieldName){m};
            end
        end

        % Créer le dossier parent si nécessaire
        outdir = fileparts(filePath);
        if ~exist(outdir, 'dir')
            mkdir(outdir);
        end

        if exist(filePath, 'file') == 2
            save(filePath, '-struct', 'saveStruct', '-append');
        else
            save(filePath, '-struct', 'saveStruct');
        end

    end % for m = 1:numFolders

end % function process_gcamp_cells


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
