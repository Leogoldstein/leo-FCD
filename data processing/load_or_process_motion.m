function [motion, camFolders, needs_processing] = load_or_process_motion( ...
    TSeries_folders, ...
    gcamp_root_folders, ...
    numAcquisitions, ...
    avg_block, ...
    metadata, ...
    animal, ...
    data, ...
    processing_mode)

% LOAD_OR_PROCESS_MOTION
%
% Centralise TOUT le traitement motion d'une acquisition :
%   - motion energy comportementale ;
%   - etat mouvement / speed_active ;
%   - deviation Suite2p depuis ops.corrXY, PAR PLAN ;
%   - bad_segs_group, PAR PLAN ;
%
% Priorite :
%   1) data.motion deja complet ;
%   2) chargement SELECTIF de results_motion.mat ;
%   3) calcul uniquement des champs encore manquants.
%
% En load_only : recharge ce qui existe puis calcule automatiquement
% uniquement les champs manquants, sans prompt et sans ouvrir Fiji.
% En interactive : si la motion camera manque, demande si Fiji doit etre
% ouvert puis si la motion energy doit etre calculee directement.
%
% IMPORTANT :
%   - l'association recording <-> TSeries est deja centralisee en amont
%     dans folder_selection ; aucun realignement local n'est effectue ici.
%   - results_motion.mat est l'unique fichier motion utilise.
%   - camFolders n'est PAS stocke dans data.motion.
%   - tous les champs motion calcules ici sont sauvegardes dans
%     results_motion.mat.

    if nargin < 8 || isempty(processing_mode)
        processing_mode = 'interactive';
    end

    processing_mode = char(string(processing_mode));
    if ~ismember(lower(processing_mode), {'load_only','interactive'})
        error('processing_mode must be ''load_only'' or ''interactive''.');
    end

    is_load_only = strcmpi(processing_mode,'load_only');
    needs_processing = false;

    % Tous les champs produits par CETTE fonction et sauvegardes dans
    % results_motion.mat. run_gcamp_peak_detection n'en calcule aucun.
    fields_motion = { ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group', ...
        'motion_energy_status', ...
        'bad_segs_group', ...
        'deviation_group' ...
    };

    initial_motion_presence = capture_motion_field_presence( ...
        data, fields_motion, numAcquisitions);

    data = init_motion_data_struct_if_needed( ...
        data, numAcquisitions, fields_motion);

    camFolders = cell(numAcquisitions,1);
    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    motion_strategy = [];
    motion_strategy_initialized = false;

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MOTION PROCESSING\n');
    fprintf('Animal       : %s\n', animal);
    fprintf('Acquisitions : %d\n', numAcquisitions);
    fprintf('Average block: %d frames\n', avg_block);
    fprintf('============================================================\n');

    for m = 1:numAcquisitions

        data = ensure_motion_entry_exists( ...
            data, fields_motion, numAcquisitions, m);

        presence_m = initial_motion_presence(:,m);

        tseries_path_m = TSeries_folders{m};
        [~, tseries_name] = fileparts(tseries_path_m);

        % =========================================================
        % Metadata / sampling rate for this acquisition
        % =========================================================
        metadata_m = ...
            get_metadata_for_record( ...
                metadata, ...
                m);

        if ~isfield(metadata_m,'gcamp_plane') || ...
                isempty(metadata_m.gcamp_plane)

            error( ...
                'load_or_process_motion:MissingGCaMPMetadata', ...
                'GCaMP metadata missing for acquisition %d.', ...
                m);
        end

        metadata_gcamp_m = ...
            metadata_m.gcamp_plane;

        if ~isfield(metadata_gcamp_m,'SamplingRatePlane') || ...
                isempty(metadata_gcamp_m.SamplingRatePlane)

            error( ...
                'load_or_process_motion:MissingSamplingRatePlane', ...
                'GCaMP metadata missing SamplingRatePlane for acquisition %d.', ...
                m);
        end

        if ~isfield(metadata_gcamp_m,'NumPlanes') || ...
                isempty(metadata_gcamp_m.NumPlanes)

            error( ...
                'load_or_process_motion:MissingNumPlanes', ...
                'GCaMP metadata missing NumPlanes for acquisition %d.', ...
                m);
        end

        sampling_rate_plane_m = ...
            metadata_gcamp_m.SamplingRatePlane;

        nPlanes = ...
            metadata_gcamp_m.NumPlanes;

        sampling_rate_motion_m = ...
            sampling_rate_plane_m * ...
            nPlanes;

        fprintf('\n------------------------------------------------------------\n');
        fprintf('Motion acquisition %d/%d\n',m,numAcquisitions);
        fprintf('Animal            : %s\n',animal);
        fprintf('TSeries           : %s\n',tseries_name);
        fprintf('Sampling rate plan: %.4f Hz\n',sampling_rate_plane_m);
        fprintf('Planes            : %d\n',nPlanes);
        fprintf('Motion/camera rate: %.4f Hz\n',sampling_rate_motion_m);
        fprintf('------------------------------------------------------------\n');

        root_folder_m = gcamp_root_folders{m};
        if isempty(root_folder_m)
            warning('load_or_process_motion:MissingOutputFolder', ...
                ['Acquisition %d/%d | %s | impossible de determiner ' ...
                 'gcamp_root folder.'],m,numAcquisitions,tseries_name);
            needs_processing = true;
            continue;
        end

        fprintf('Output folder: %s\n',root_folder_m);

        % results_motion.mat est l'unique source/sortie motion.
        savePath = fullfile(root_folder_m,'results_motion.mat');

        % =========================================================
        % Camera folder
        % =========================================================
        [cam_folder_m, cam_folder_needs_save] = ...
            resolve_camera_folder(savePath,tseries_path_m,m, ...
                numAcquisitions,tseries_name);

        camFolders{m} = cam_folder_m;

        if cam_folder_needs_save
            saveCam = struct('camFolders',cam_folder_m);
            try
                if exist(savePath,'file') == 2
                    save(savePath,'-struct','saveCam','-append');
                else
                    save(savePath,'-struct','saveCam');
                end
                fprintf('  Saved : camFolders added to results_motion.mat.\n');
            catch ME
                warning('load_or_process_motion:CameraPathSaveFailed', ...
                    ['Acquisition %d/%d | %s | unable to save ' ...
                     'camFolders: %s'], ...
                    m,numAcquisitions,tseries_name,ME.message);
            end
        end

        % =========================================================
        % 1) MEMOIRE : ne rien relire si elle est reellement complete
        %
        % Une structure non vide mais plus courte que results_motion.mat
        % est consideree comme croppee, donc incomplete.
        % =========================================================
        cropped_fields_pre = ...
            get_cropped_motion_fields_to_restore(data,savePath,m);

        if motion_already_complete(data,m,fields_motion,presence_m,is_load_only) && ...
                isempty(cropped_fields_pre)
            fprintf('\nMemory status: complete.\n');
            fprintf('Motion status: %s\n',get_motion_status_name(data,m));
            fprintf('Action       : no reload or recalculation required.\n');

            if ~is_load_only
                save_motion_figure_if_missing( ...
                    root_folder_m,data,m,animal, ...
                    tseries_name,sampling_rate_motion_m,avg_block);
            end
            continue;
        end

        % =========================================================
        % 2) DISQUE : chargement SELECTIF de results_motion.mat
        % =========================================================
        has_new_data_for_acquisition = false;

        if exist(savePath,'file') == 2
            fields_to_load = get_motion_fields_to_load( ...
                data,fields_motion,presence_m,m,is_load_only);

            % data.motion peut etre non vide mais avoir ete croppe par un
            % passage precedent de run_gcamp_peak_detection. Comparer les
            % vecteurs full-length sauvegardes et restaurer seulement le
            % bloc temporel concerne.
            cropped_fields_to_restore = ...
                get_cropped_motion_fields_to_restore( ...
                    data,savePath,m);

            fields_to_load = unique( ...
                [fields_to_load(:); cropped_fields_to_restore(:)], ...
                'stable');

            fprintf('\nMemory status: incomplete.\n');

            if ~isempty(fields_to_load)
                try
                    vars = whos('-file',savePath);
                    names = {vars.name};
                    fields_available = fields_to_load( ...
                        ismember(fields_to_load,names));

                    if ~isempty(fields_available)
                        fprintf('Loading only missing/cropped motion variables:\n');
                        for k = 1:numel(fields_available)
                            fprintf('  %s\n',fields_available{k});
                        end

                        loaded = load(savePath,fields_available{:});
                        [data,presence_m] = merge_loaded_motion_into_data( ...
                            data,loaded,fields_available,fields_motion, ...
                            presence_m,m,cropped_fields_to_restore);
                    else
                        fprintf(['Saved motion data: none of the missing ' ...
                            'variables is available in results_motion.mat.\n']);
                    end
                catch ME
                    warning('load_or_process_motion:ResultsLoadFailed', ...
                        ['Acquisition %d/%d | %s | unable to load ' ...
                         'missing fields from results_motion.mat: %s'], ...
                        m,numAcquisitions,tseries_name,ME.message);
                end
            else
                fprintf(['Saved motion data: no variable needs to be ' ...
                    'loaded from results_motion.mat.\n']);
            end
        else
            fprintf('\nSaved motion file: not found.\n');
        end

        if motion_already_complete(data,m,fields_motion,presence_m,is_load_only)
            fprintf('Memory completed from saved file.\n');
            fprintf('Motion status: %s\n',get_motion_status_name(data,m));
            fprintf('Action       : calculation skipped.\n');

            if ~is_load_only
                save_motion_figure_if_missing( ...
                    root_folder_m,data,m,animal, ...
                    tseries_name,sampling_rate_motion_m,avg_block);
            end
            continue;
        end

        % =========================================================
        % 3) COMPLETION DES DONNEES MANQUANTES
        %
        % load_only : aucun choix utilisateur. Les calculs manquants sont
        % lances directement et seuls les champs absents sont produits.
        % interactive : les calculs Suite2p restent automatiques, tandis
        % que la motion camera conserve le choix Fiji / calcul direct / skip.
        % =========================================================

        % =========================================================
        % 3a) SUITE2P MOTION ARTIFACTS
        %
        % Toute l'ancienne logique corrXY -> deviation / bad frames est ici.
        % Aucun autre pipeline ne doit la recalculer.
        % =========================================================
        [data,presence_m,artifact_changed] = ...
            ensure_suite2p_motion_artifacts( ...
                data,m,fields_motion,presence_m,tseries_name);

        has_new_data_for_acquisition = ...
            has_new_data_for_acquisition || artifact_changed;

        if ~suite2p_motion_complete(data,m)
            needs_processing = true;
        end

        % Si les donnees camera etaient deja completes et que seuls les
        % champs Suite2p manquaient, on peut maintenant sauvegarder et finir.
        if motion_already_complete(data,m,fields_motion,presence_m,is_load_only)
            save_motion_fields_if_needed( ...
                savePath,data,fields_motion,m, ...
                has_new_data_for_acquisition,tseries_name);

            if ~is_load_only
                save_motion_figure_if_missing( ...
                    root_folder_m,data,m,animal, ...
                    tseries_name,sampling_rate_motion_m,avg_block);
            end

            continue;
        end

        % =========================================================
        % 3b) Camera absente
        % =========================================================
        if isempty(cam_folder_m)
            data = assign_empty_camera_motion_fields_if_missing(data,m);
            data.motion.motion_energy_status{m} = 'no_camera';
            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath,data,fields_motion,m,true,tseries_name);
            continue;
        end

        filepath = fullfile(cam_folder_m,'cam_crop.tif');
        fprintf('\nCamera data\n');

        if exist(filepath,'file') ~= 2
            fprintf('  Movie status: cam_crop.tif not found.\n');
            fprintf('  Expected file: %s\n',filepath);

            data = assign_empty_camera_motion_fields_if_missing(data,m);
            data.motion.motion_energy_status{m} = 'no_motion';
            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath,data,fields_motion,m,true,tseries_name);
            continue;
        end

        fprintf('  Movie status: camera movie available.\n');
        fprintf('  Movie file  : %s\n',filepath);

        % =========================================================
        % 3c) Motion energy
        % =========================================================
        fprintf('\nMotion energy\n');

        if ~motion_field_has_value(data,'motion_energy_group',m)

            if is_load_only

                % LOAD ONLY = execution non interactive.
                % Si la motion energy manque, la calculer directement sur
                % cam_crop.tif sans ouvrir Fiji et sans poser de question.
                motion_strategy_current = struct( ...
                    'open_in_fiji', false, ...
                    'compute_direct', true, ...
                    'skip', false);

                fprintf([ ...
                    '  LOAD ONLY: motion energy missing -> ' ...
                    'direct calculation.\n']);

            else

                % INTERACTIVE = demander une seule fois la strategie a
                % appliquer aux acquisitions dont la motion energy manque.
                if ~motion_strategy_initialized
                    motion_strategy = ask_motion_energy_strategy_once();
                    motion_strategy_initialized = true;
                end

                motion_strategy_current = motion_strategy;
            end

            motion_energy = compute_motion_energy_with_strategy( ...
                filepath,fijiPath,motion_strategy_current);

            data.motion.motion_energy_group{m} = motion_energy;
            presence_m = mark_motion_presence( ...
                presence_m,fields_motion,'motion_energy_group');

            if isempty(motion_energy)
                data.motion.motion_energy_status{m} = 'skipped';

                if is_load_only
                    needs_processing = true;
                    fprintf([ ...
                        '  Result: direct motion energy calculation ' ...
                        'returned no data.\n']);
                else
                    fprintf('  Result: motion energy calculation skipped.\n');
                end
            else
                data.motion.motion_energy_status{m} = 'processing';
                fprintf('  Result: motion energy calculated.\n');
                fprintf('  Frames: %d\n',numel(motion_energy));
            end

            presence_m = mark_motion_presence( ...
                presence_m,fields_motion,'motion_energy_status');
            has_new_data_for_acquisition = true;
        else
            motion_energy = data.motion.motion_energy_group{m};
            fprintf('  Status: existing motion energy reused.\n');
            fprintf('  Frames: %d\n',numel(motion_energy));

            if ~motion_status_exists(data,m) || ...
                    isempty(data.motion.motion_energy_status{m})
                data.motion.motion_energy_status{m} = 'processing';
                presence_m = mark_motion_presence( ...
                    presence_m,fields_motion,'motion_energy_status');
                has_new_data_for_acquisition = true;
            end
        end

        if isempty(motion_energy)
            data = assign_empty_binary_motion_fields_if_missing(data,m);
            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath,data,fields_motion,m, ...
                has_new_data_for_acquisition,tseries_name);
            continue;
        end

        % =========================================================
        % 3d) Temporal averaging + smoothing
        %
        % La moyenne temporelle et le lissage ne sont recalcules que si
        % motion_energy_smooth_group manque reellement.
        % =========================================================
        fprintf('\nMotion smoothing\n');

        if ~motion_field_has_value(data,'motion_energy_smooth_group',m)

            avg_motion_energy = ...
                average_frames( ...
                    motion_energy, ...
                    avg_block);

            fprintf('  Temporal averaging required.\n');
            fprintf('  Input frames : %d\n',numel(motion_energy));
            fprintf('  Block size   : %d\n',avg_block);
            fprintf('  Output points: %d\n',numel(avg_motion_energy));

            motion_energy_smooth = ...
                smooth_savgol( ...
                    avg_motion_energy, ...
                    3, ...
                    11);

            data.motion.motion_energy_smooth_group{m} = ...
                motion_energy_smooth;

            presence_m = ...
                mark_motion_presence( ...
                    presence_m, ...
                    fields_motion, ...
                    'motion_energy_smooth_group');

            has_new_data_for_acquisition = true;

            fprintf('  Status: smoothed motion signal calculated.\n');

        else

            motion_energy_smooth = ...
                data.motion.motion_energy_smooth_group{m};

            fprintf([ ...
                '  Status: existing smoothed signal reused; ' ...
                'temporal averaging skipped.\n']);
        end

        if isempty(motion_energy_smooth)
            data = assign_empty_binary_motion_fields_if_missing(data,m);
            has_new_data_for_acquisition = true;
            save_motion_fields_if_needed( ...
                savePath,data,fields_motion,m, ...
                has_new_data_for_acquisition,tseries_name);
            continue;
        end

        % =========================================================
        % 3e) Motion state detection
        % =========================================================
        % Les tableaux onset/offset peuvent etre legitimement vides.
        % Pour eux, l'existence du champ sauvegarde suffit. speed_active,
        % en revanche, doit contenir un vecteur reel.
        event_fields = { ...
            'avg_active_motion_onsets_group', ...
            'avg_active_motion_offsets_group', ...
            'active_motion_onsets_group', ...
            'active_motion_offsets_group'};

        events_complete = true;

        for event_idx = 1:numel(event_fields)
            events_complete = ...
                events_complete && ...
                motion_field_present_in_acquisition( ...
                    fields_motion, ...
                    presence_m, ...
                    event_fields{event_idx});
        end

        need_bin = ...
            ~events_complete || ...
            ~motion_field_has_value( ...
                data, ...
                'speed_active_group', ...
                m);

        fprintf('\nMotion state detection\n');

        if need_bin
            [~,thr_li,~] = compute_thresholds_for_bin_state_detection( ...
                motion_energy_smooth,false);

            [bin_sig,~,~,~] = binarise_motion( ...
                motion_energy_smooth,thr_li,sampling_rate_motion_m, ...
                avg_block,3.0,5);

            avg_onsets = get_onsets(bin_sig);
            avg_offsets = get_offsets(bin_sig);

            if ~isempty(bin_sig)
                if bin_sig(1) == 1
                    avg_onsets = [1; avg_onsets(:)];
                end
                if bin_sig(end) == 1
                    avg_offsets = [avg_offsets(:); numel(bin_sig)];
                end
            end

            N_frames = numel(motion_energy);
            onsets_frames = max(1,(avg_onsets-1)*avg_block+1);
            offsets_frames = min(N_frames,avg_offsets*avg_block);

            speed_active = repelem(bin_sig(:),avg_block);
            if isempty(speed_active)
                speed_active = zeros(N_frames,1);
            elseif numel(speed_active) < N_frames
                speed_active(end+1:N_frames) = speed_active(end);
            else
                speed_active = speed_active(1:N_frames);
            end

            data.motion.avg_active_motion_onsets_group{m} = avg_onsets;
            data.motion.avg_active_motion_offsets_group{m} = avg_offsets;
            data.motion.active_motion_onsets_group{m} = onsets_frames;
            data.motion.active_motion_offsets_group{m} = offsets_frames;
            data.motion.speed_active_group{m} = speed_active;

            for fn = { ...
                    'avg_active_motion_onsets_group', ...
                    'avg_active_motion_offsets_group', ...
                    'active_motion_onsets_group', ...
                    'active_motion_offsets_group', ...
                    'speed_active_group'}
                presence_m = mark_motion_presence( ...
                    presence_m,fields_motion,fn{1});
            end

            has_new_data_for_acquisition = true;
            fprintf('  Status         : motion states calculated.\n');
            fprintf('  Threshold      : %.6f\n',thr_li);
            fprintf('  Motion periods : %d\n', ...
                min(numel(avg_onsets),numel(avg_offsets)));
        else
            avg_onsets = data.motion.avg_active_motion_onsets_group{m};
            avg_offsets = data.motion.avg_active_motion_offsets_group{m};
            fprintf('  Status         : existing motion states reused.\n');
            fprintf('  Motion periods : %d\n', ...
                min(numel(avg_onsets),numel(avg_offsets)));
        end

        % "done" signifie que la branche camera a atteint la detection
        % d'etat. Les artefacts Suite2p sont geres independamment ci-dessus.
        if ~motion_status_exists(data,m) || ...
                ~strcmp(string(data.motion.motion_energy_status{m}),"done")
            data.motion.motion_energy_status{m} = 'done';
            presence_m = mark_motion_presence( ...
                presence_m,fields_motion,'motion_energy_status');
            has_new_data_for_acquisition = true;
        end

        save_motion_fields_if_needed( ...
            savePath,data,fields_motion,m, ...
            has_new_data_for_acquisition,tseries_name);

        if ~is_load_only
            save_motion_figure_if_missing( ...
                root_folder_m,data,m,animal, ...
                tseries_name,sampling_rate_motion_m,avg_block);
        end
    end

    fprintf('\n============================================================\n');
    fprintf('MOTION PROCESSING COMPLETED\n');
    fprintf('Animal      : %s\n',animal);
    fprintf('Acquisitions: %d\n',numAcquisitions);
    fprintf('============================================================\n');

    motion = data.motion;
end


% =====================================================================
% Suite2p motion-artifact analysis
% =====================================================================

function [data,presence_m,changed] = ensure_suite2p_motion_artifacts( ...
    data,m,fields_motion,presence_m,tseries_name)

    changed = false;

    nPlanes = get_suite2p_motion_plan_count(data,m);

    if nPlanes < 1
        warning('load_or_process_motion:MissingPlanes', ...
            ['%s | impossible de calculer les artefacts Suite2p : ' ...
             'aucun plan disponible dans data.'], ...
            tseries_name);
        return;
    end

    % Les deux champs Suite2p persistants sont stockes PAR PLAN :
    %
    %   data.motion.deviation_group{m}{p}
    %   data.motion.bad_segs_group{m}{p}
    %
    % bad_segs_group est l'unique representation persistante des
    % mauvaises frames.
    suite2p_fields = { ...
        'deviation_group', ...
        'bad_segs_group'};

    old_plan_presence = struct();

    for k = 1:numel(suite2p_fields)
        fn = suite2p_fields{k};

        old_plan_presence.(fn) = false(nPlanes,1);

        if motion_field_slot_exists(data,fn,m)
            value = data.motion.(fn){m};

            if iscell(value)
                nStored = min(numel(value),nPlanes);
                if nStored > 0
                    old_plan_presence.(fn)(1:nStored) = true;
                end
            end
        end

        data.motion.(fn){m} = ensure_plane_cell( ...
            get_motion_group_value(data,fn,m), ...
            nPlanes);
    end

    for p = 1:nPlanes

        deviation = [];

        if old_plan_presence.deviation_group(p) && ...
                ~isempty(data.motion.deviation_group{m}{p})

            deviation = ...
                double(data.motion.deviation_group{m}{p}(:));
        end

        deviation_changed = false;

        if isempty(deviation)

            ops_ref = ...
                get_suite2p_motion_ops( ...
                    data,m,p);

            if isempty(ops_ref) || ...
                    ~isstruct(ops_ref) || ...
                    ~isfield(ops_ref,'corrXY') || ...
                    isempty(ops_ref.corrXY)

                warning( ...
                    'load_or_process_motion:MissingCorrXY', ...
                    ['%s | plane %d | impossible de calculer ' ...
                     'deviation_group : ops.corrXY manquant.'], ...
                    tseries_name, ...
                    p - 1);

                continue;
            end

            corrXY = ...
                double(ops_ref.corrXY(:));

            rolling_median = ...
                movmedian(corrXY,300);

            deviation = ...
                corrXY - rolling_median;

            data.motion.deviation_group{m}{p} = ...
                deviation(:).';

            deviation_changed = true;
            changed = true;
        end

        % Un plan sans artefact a legitimement bad_segs = [].
        bad_segs_present = ...
            old_plan_presence.bad_segs_group(p);

        if deviation_changed || ...
                ~bad_segs_present

            sigma_dev = ...
                std( ...
                    deviation(deviation < 0), ...
                    'omitnan');

            if isempty(sigma_dev) || ...
                    ~isfinite(sigma_dev) || ...
                    sigma_dev <= 0

                bad_logical = ...
                    false(size(deviation));

            else

                seuil_bad = ...
                    -3 * sigma_dev;

                bad_logical = ...
                    deviation < seuil_bad;

                bad_logical = ...
                    conv( ...
                        double(bad_logical), ...
                        [1 1 1], ...
                        'same') > 0;
            end

            bad_segs = ...
                badmask_to_segments( ...
                    bad_logical, ...
                    numel(deviation));

            data.motion.bad_segs_group{m}{p} = ...
                bad_segs;

            changed = true;

            fprintf('\nSuite2p motion artifacts - plane %d\n',p-1);
            fprintf('  deviation_group : %d frames\n',numel(deviation));
            fprintf('  bad samples     : %d (derivees, non sauvegardees)\n', ...
                nnz(bad_logical));
            fprintf('  bad segments    : %d\n',size(bad_segs,1));
        end
    end

    for k = 1:numel(suite2p_fields)
        presence_m = mark_motion_presence( ...
            presence_m, ...
            fields_motion, ...
            suite2p_fields{k});
    end
end


function nPlanes = get_suite2p_motion_plan_count(data,m)

    nPlanes = 0;

    % Priorite aux plans GCaMP : ce sont les plans utilises par
    % run_gcamp_peak_detection. Combined est un fallback equivalent.
    % Electroporated n'est utilise qu'en dernier recours.
    candidate_groups = { ...
        { ...
            'gcamp_plane', 'ops_suite2p_by_plane'; ...
            'gcamp_plane', 'F_gcamp_by_plane' ...
        }, ...
        { ...
            'combined_plane', 'F_combined_by_plane' ...
        }, ...
        { ...
            'electroporated_plane', 'ops_suite2p_electroporated_by_plane'; ...
            'electroporated_plane', 'F_electroporated_by_plane' ...
        } ...
    };

    for g = 1:numel(candidate_groups)

        candidates = ...
            candidate_groups{g};

        nGroup = 0;

        for c = 1:size(candidates,1)

            branch = ...
                candidates{c,1};

            fieldName = ...
                candidates{c,2};

            if ~isfield(data,branch) || ...
                    ~isstruct(data.(branch)) || ...
                    ~isfield(data.(branch),fieldName) || ...
                    ~iscell(data.(branch).(fieldName)) || ...
                    numel(data.(branch).(fieldName)) < m

                continue;
            end

            value = ...
                data.(branch).(fieldName){m};

            if iscell(value)
                nGroup = max(nGroup,numel(value));
            elseif isstruct(value)
                nGroup = max(nGroup,numel(value));
            elseif ~isempty(value)
                nGroup = max(nGroup,1);
            end
        end

        if nGroup > 0
            nPlanes = nGroup;
            return;
        end
    end
end


function ops_ref = get_suite2p_motion_ops(data,m,p)

    ops_ref = [];

    % Motion Suite2p = reference GCaMP uniquement.
    % Chaque plan utilise son propre ops.
    % Aucun fallback vers un autre plan ni vers le canal electropore.
    if ~isfield(data,'gcamp_plane') || ...
            ~isstruct(data.gcamp_plane) || ...
            ~isfield(data.gcamp_plane,'ops_suite2p_by_plane') || ...
            ~iscell(data.gcamp_plane.ops_suite2p_by_plane) || ...
            numel(data.gcamp_plane.ops_suite2p_by_plane) < m

        return;
    end

    value = ...
        data.gcamp_plane.ops_suite2p_by_plane{m};

    if iscell(value)

        if numel(value) < p || ...
                ~isstruct(value{p})

            return;
        end

        candidate = ...
            value{p};

    elseif isstruct(value) && ...
            numel(value) >= p

        candidate = ...
            value(p);

    else

        return;
    end

    if ops_has_corrxy(candidate)
        ops_ref = candidate;
    end
end


function tf = ops_has_corrxy(ops_value)

    tf = ...
        ~isempty(ops_value) && ...
        isstruct(ops_value) && ...
        isfield(ops_value,'corrXY') && ...
        ~isempty(ops_value.corrXY);
end


function value = get_motion_group_value(data,fieldName,m)

    value = [];

    if motion_field_slot_exists(data,fieldName,m)
        value = data.motion.(fieldName){m};
    end
end


function out = ensure_plane_cell(value,nPlanes)

    out = cell(nPlanes,1);

    if ~iscell(value)
        return;
    end

    nCopy = min(numel(value),nPlanes);

    if nCopy > 0
        out(1:nCopy) = value(1:nCopy);
    end
end


function tf = suite2p_motion_field_complete( ...
    data,fieldName,m,nPlanes,require_nonempty)

    if nargin < 5
        require_nonempty = false;
    end

    tf = false;

    if nPlanes < 1 || ...
            ~motion_field_slot_exists(data,fieldName,m)

        return;
    end

    value = ...
        data.motion.(fieldName){m};

    if ~iscell(value) || ...
            numel(value) < nPlanes

        return;
    end

    if require_nonempty

        for p = 1:nPlanes

            if isempty(value{p})
                return;
            end
        end
    end

    tf = true;
end


function tf = suite2p_motion_complete(data,m)

    nPlanes = ...
        get_suite2p_motion_plan_count( ...
            data,m);

    tf = ...
        nPlanes >= 1 && ...
        suite2p_motion_field_complete( ...
            data,'deviation_group',m,nPlanes,true) && ...
        suite2p_motion_field_complete( ...
            data,'bad_segs_group',m,nPlanes,false);
end


function segs = badmask_to_segments(bad_mask,T)

    if isempty(bad_mask) || T <= 0
        segs = zeros(0,2);
        return;
    end

    bad_mask = logical(bad_mask(:).');

    if numel(bad_mask) > T
        bad_mask = bad_mask(1:T);
    elseif numel(bad_mask) < T
        bad_mask(end+1:T) = false;
    end

    idx = find(bad_mask);

    if isempty(idx)
        segs = zeros(0,2);
        return;
    end

    d = diff(idx);
    cuts = [1 find(d > 1)+1 numel(idx)+1];
    segs = zeros(numel(cuts)-1,2);

    for k = 1:numel(cuts)-1
        segs(k,:) = [idx(cuts(k)) idx(cuts(k+1)-1)];
    end
end


% =====================================================================
% Selective loading / completeness
% =====================================================================

function presence = capture_motion_field_presence(data,fieldNames,numAcquisitions)

    presence = false(numel(fieldNames),numAcquisitions);

    if isempty(data) || ~isstruct(data) || ...
            ~isfield(data,'motion') || ~isstruct(data.motion)
        return;
    end

    for f = 1:numel(fieldNames)
        fn = fieldNames{f};
        if ~isfield(data.motion,fn) || ~iscell(data.motion.(fn))
            continue;
        end
        nStored = min(numel(data.motion.(fn)),numAcquisitions);
        if nStored > 0
            presence(f,1:nStored) = true;
        end
    end
end


function fields_to_load = get_motion_fields_to_load( ...
    data,fields_motion,presence_m,m,is_load_only)

    if nargin < 5 || isempty(is_load_only)
        is_load_only = false;
    end

    fields_to_load = {};
    status = "";

    if motion_status_exists(data,m) && ...
            ~isempty(data.motion.motion_energy_status{m})

        status = ...
            string( ...
                data.motion.motion_energy_status{m});
    end

    % -------------------------------------------------------------
    % Champs camera : par acquisition.
    % -------------------------------------------------------------
    camera_fields = { ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group'};

    if strlength(status) == 0

        for k = 1:numel(camera_fields)

            fn = ...
                camera_fields{k};

            idx = ...
                find( ...
                    strcmp(fields_motion,fn), ...
                    1);

            if isempty(idx) || ...
                    ~presence_m(idx) || ...
                    (motion_field_requires_nonempty(fn) && ...
                     ~motion_field_has_value(data,fn,m))

                fields_to_load{end+1} = fn; %#ok<AGROW>
            end
        end

        status_idx = ...
            find( ...
                strcmp(fields_motion,'motion_energy_status'), ...
                1);

        if isempty(status_idx) || ...
                ~presence_m(status_idx)

            fields_to_load{end+1} = ...
                'motion_energy_status'; %#ok<AGROW>
        end

    else

        switch status

            case "done"

                required_nonempty = { ...
                    'motion_energy_group', ...
                    'motion_energy_smooth_group', ...
                    'speed_active_group'};

                for k = 1:numel(required_nonempty)

                    fn = ...
                        required_nonempty{k};

                    if ~motion_field_has_value(data,fn,m)

                        fields_to_load{end+1} = ...
                            fn; %#ok<AGROW>
                    end
                end

                % Ces tableaux peuvent etre vides mais leur variable doit
                % reellement avoir existe.
                presence_required = { ...
                    'avg_active_motion_onsets_group', ...
                    'avg_active_motion_offsets_group', ...
                    'active_motion_onsets_group', ...
                    'active_motion_offsets_group'};

                for k = 1:numel(presence_required)

                    fn = ...
                        presence_required{k};

                    idx = ...
                        find( ...
                            strcmp(fields_motion,fn), ...
                            1);

                    if isempty(idx) || ...
                            ~presence_m(idx)

                        fields_to_load{end+1} = ...
                            fn; %#ok<AGROW>
                    end
                end

            case "skipped"

                if is_load_only
                    % En load_only, recharger d'abord tout champ camera
                    % reellement sauvegarde avant d'envisager un calcul.
                    % Si le MAT ne le contient pas, la suite du pipeline
                    % produira uniquement ce qui manque.
                    for k = 1:numel(camera_fields)

                        fn = ...
                            camera_fields{k};

                        idx = ...
                            find( ...
                                strcmp(fields_motion,fn), ...
                                1);

                        if isempty(idx) || ...
                                ~presence_m(idx) || ...
                                (motion_field_requires_nonempty(fn) && ...
                                 ~motion_field_has_value(data,fn,m))

                            fields_to_load{end+1} = ... %#ok<AGROW>
                                fn;
                        end
                    end
                else
                    % En interactive, respecter le choix utilisateur skip.
                end

            case {"no_camera","no_motion"}

                % Le filesystem sera recontrole. Ne pas ressusciter
                % d'anciennes donnees camera.

            otherwise

                for k = 1:numel(camera_fields)

                    fn = ...
                        camera_fields{k};

                    idx = ...
                        find( ...
                            strcmp(fields_motion,fn), ...
                            1);

                    if isempty(idx) || ...
                            ~presence_m(idx) || ...
                            (motion_field_requires_nonempty(fn) && ...
                             ~motion_field_has_value(data,fn,m))

                        fields_to_load{end+1} = ...
                            fn; %#ok<AGROW>
                    end
                end
        end
    end

    % -------------------------------------------------------------
    % Artefacts Suite2p : par plan.
    %
    % On ne demande au MAT que les champs dont au moins un plan est
    % incomplet. bad_segs peut contenir [] pour un plan :
    % l'existence du slot cellulaire suffit dans ce cas.
    % -------------------------------------------------------------
    suite2p_missing = ...
        missing_suite2p_motion_fields( ...
            data,m);

    fields_to_load = ...
        unique( ...
            [ ...
                fields_to_load(:); ...
                suite2p_missing(:) ...
            ], ...
            'stable');
end


function fields = missing_suite2p_motion_fields(data,m)

    fields = {};

    nPlanes = ...
        get_suite2p_motion_plan_count( ...
            data,m);

    if nPlanes < 1

        fields = { ...
            'deviation_group'; ...
            'bad_segs_group'};

        return;
    end

    if ~suite2p_motion_field_complete( ...
            data,'deviation_group',m,nPlanes,true)

        fields{end+1} = ...
            'deviation_group'; %#ok<AGROW>
    end

    if ~suite2p_motion_field_complete( ...
            data,'bad_segs_group',m,nPlanes,false)

        fields{end+1} = ...
            'bad_segs_group'; %#ok<AGROW>
    end
end


function tf = motion_field_requires_nonempty(fieldName)

    tf = ...
        ismember( ...
            fieldName, ...
            { ...
                'motion_energy_group', ...
                'motion_energy_smooth_group', ...
                'speed_active_group' ...
            });
end


function tf = motion_field_present_in_acquisition( ...
    fields_motion,presence_m,fieldName)

    tf = false;

    idx = ...
        find( ...
            strcmp(fields_motion,fieldName), ...
            1, ...
            'first');

    if isempty(idx) || ...
            idx > numel(presence_m)
        return;
    end

    tf = ...
        logical( ...
            presence_m(idx));
end


function tf = motion_already_complete(data,m,fields_motion,presence_m,is_load_only)

    if nargin < 5 || isempty(is_load_only)
        is_load_only = false;
    end

    tf = false;

    if ~motion_status_exists(data,m) || ...
            isempty(data.motion.motion_energy_status{m})

        return;
    end

    suite2p_complete = ...
        suite2p_motion_complete( ...
            data,m);

    status = ...
        string( ...
            data.motion.motion_energy_status{m});

    switch status

        case "done"

            event_fields = { ...
                'avg_active_motion_onsets_group', ...
                'avg_active_motion_offsets_group', ...
                'active_motion_onsets_group', ...
                'active_motion_offsets_group'};

            events_complete = true;

            for event_idx = 1:numel(event_fields)
                events_complete = ...
                    events_complete && ...
                    motion_field_present_in_acquisition( ...
                        fields_motion, ...
                        presence_m, ...
                        event_fields{event_idx});
            end

            tf = ...
                suite2p_complete && ...
                events_complete && ...
                motion_field_has_value( ...
                    data,'motion_energy_group',m) && ...
                motion_field_has_value( ...
                    data,'motion_energy_smooth_group',m) && ...
                motion_field_has_value( ...
                    data,'speed_active_group',m);

        case "skipped"

            if is_load_only
                % En load_only, un ancien choix "skipped" ne bloque pas
                % la completion automatique. Si cam_crop.tif existe, la
                % motion energy manquante sera calculee directement.
                tf = false;
            else
                % En interactive, respecter le choix utilisateur precedent.
                tf = ...
                    suite2p_complete;
            end

        case {"no_camera","no_motion"}

            % Le filesystem est volontairement recontrole a chaque run.
            tf = false;

        otherwise

            tf = false;
    end
end


function fields = get_cropped_motion_fields_to_restore(data,savePath,m)

    fields = {};

    if isempty(savePath) || ...
            exist(savePath,'file') ~= 2

        return;
    end

    info = ...
        whos( ...
            '-file', ...
            savePath);

    if isempty(info)
        return;
    end

    names = ...
        {info.name};

    % -------------------------------------------------------------
    % Camera motion : champs vectoriels par acquisition.
    % -------------------------------------------------------------
    camera_core = { ...
        'motion_energy_group', ...
        'speed_active_group'};

    camera_cropped = false;

    for k = 1:numel(camera_core)

        fn = ...
            camera_core{k};

        idx = ...
            find( ...
                strcmp(names,fn), ...
                1);

        if isempty(idx)
            continue;
        end

        source_n = ...
            prod( ...
                double(info(idx).size));

        if source_n <= 0
            continue;
        end

        current_n = 0;

        if motion_field_slot_exists(data,fn,m) && ...
                ~isempty(data.motion.(fn){m})

            current_n = ...
                numel(data.motion.(fn){m});
        end

        if current_n > 0 && ...
                current_n < source_n

            camera_cropped = true;
            break;
        end
    end

    if camera_cropped

        camera_fields = { ...
            'motion_energy_group', ...
            'speed_active_group'};

        fields = ...
            [ ...
                fields(:); ...
                camera_fields( ...
                    ismember(camera_fields,names)).' ...
            ];
    end

    % -------------------------------------------------------------
    % Suite2p motion : champs PAR PLAN.
    %
    % whos() ne donne que la taille du cell array sauvegarde, pas la
    % longueur de deviation pour chaque plan. Charger uniquement
    % deviation_group pour comparer les longueurs plan par plan.
    % -------------------------------------------------------------
    if ismember('deviation_group',names) && ...
            motion_field_slot_exists( ...
                data,'deviation_group',m)

        try

            saved = ...
                load( ...
                    savePath, ...
                    'deviation_group');

            saved_dev = ...
                saved.deviation_group;

            current_dev = ...
                data.motion.deviation_group{m};

            suite2p_cropped = false;

            if iscell(saved_dev) && ...
                    iscell(current_dev)

                nCompare = ...
                    min( ...
                        numel(saved_dev), ...
                        numel(current_dev));

                for p = 1:nCompare

                    source_n = ...
                        numel(saved_dev{p});

                    current_n = ...
                        numel(current_dev{p});

                    if source_n > 0 && ...
                            current_n < source_n

                        suite2p_cropped = true;
                        break;
                    end
                end
            end

            if suite2p_cropped

                suite2p_fields = { ...
                    'deviation_group', ...
                    'bad_segs_group'};

                fields = ...
                    [ ...
                        fields(:); ...
                        suite2p_fields( ...
                            ismember(suite2p_fields,names)).' ...
                    ];
            end

        catch
            % Le chargement selectif normal gerera ensuite les champs
            % absents. Ne jamais bloquer le pipeline sur ce test de crop.
        end
    end

    fields = ...
        unique( ...
            fields, ...
            'stable');
end


function [data,presence_m] = merge_loaded_motion_into_data( ...
    data,loaded,fields_available,fields_motion,presence_m,m,force_fields)

    if nargin < 7 || ...
            isempty(force_fields)

        force_fields = {};
    end

    suite2p_fields = { ...
        'deviation_group', ...
        'bad_segs_group'};

    for k = 1:numel(fields_available)

        fn = ...
            fields_available{k};

        if ~isfield(loaded,fn)
            continue;
        end

        idx = ...
            find( ...
                strcmp(fields_motion,fn), ...
                1);

        % ---------------------------------------------------------
        % Les champs Suite2p sauvegardes dans results_motion.mat sont
        % deja des cell arrays par plan. Quand ils sont demandes, on
        % recharge le champ complet : cela restaure aussi proprement un
        % data.motion qui avait ete croppe.
        % ---------------------------------------------------------
        if ismember(fn,suite2p_fields)

            if iscell(loaded.(fn))
                data.motion.(fn){m} = loaded.(fn);
            end

        else

            should_assign = ...
                ismember(fn,force_fields) || ...
                isempty(idx) || ...
                ~presence_m(idx) || ...
                ~motion_field_has_value( ...
                    data,fn,m);

            if should_assign
                data.motion.(fn){m} = loaded.(fn);
            end
        end

        if ~isempty(idx)
            presence_m(idx) = true;
        end
    end
end


function presence_m = mark_motion_presence(presence_m,fields_motion,fieldName)
    idx = find(strcmp(fields_motion,fieldName),1);
    if ~isempty(idx)
        presence_m(idx) = true;
    end
end


% =====================================================================
% Camera folder
% =====================================================================

function [cam_folder_m,needs_save] = resolve_camera_folder( ...
    savePath,tseries_path_m,m,numAcquisitions,tseries_name)

    fprintf('\nCamera folder\n');

    cam_folder_m = [];
    needs_save = false;

    if exist(savePath,'file') == 2
        try
            info = whos('-file',savePath,'camFolders');
            if ~isempty(info)
                tmp = load(savePath,'camFolders');
                saved_cam = tmp.camFolders;
                if iscell(saved_cam)
                    if ~isempty(saved_cam)
                        cam_folder_m = saved_cam{1};
                    end
                else
                    cam_folder_m = saved_cam;
                end

                if ~isempty(cam_folder_m) && isfolder(cam_folder_m)
                    fprintf('  Status: saved camera folder reused.\n');
                    fprintf('  Folder: %s\n',cam_folder_m);
                else
                    cam_folder_m = [];
                end
            end
        catch ME
            warning('load_or_process_motion:CameraPathLoadFailed', ...
                ['Acquisition %d/%d | %s | unable to load ' ...
                 'camFolders from results_motion.mat: %s'], ...
                m,numAcquisitions,tseries_name,ME.message);
        end
    end

    if isempty(cam_folder_m)
        camPath = fullfile(tseries_path_m,'cam','Concatenated');
        cameraPath = fullfile(tseries_path_m,'camera','Concatenated');

        if isfolder(camPath)
            cam_folder_m = camPath;
            needs_save = true;
        elseif isfolder(cameraPath)
            cam_folder_m = cameraPath;
            needs_save = true;
        else
            cam_folder_m = [];
            if exist(savePath,'file') == 2
                try
                    info = whos('-file',savePath,'camFolders');
                    needs_save = isempty(info);
                catch
                end
            end
        end

        if isempty(cam_folder_m)
            fprintf('  Status: no camera folder found.\n');
        else
            fprintf('  Status: camera folder found.\n');
            fprintf('  Folder: %s\n',cam_folder_m);
        end
    end
end


% =====================================================================
% Data structure helpers
% =====================================================================

function data = init_motion_data_struct_if_needed(data,numAcquisitions,fieldNames)

    if nargin < 1 || isempty(data)
        data = struct();
    end
    if ~isfield(data,'motion') || ~isstruct(data.motion)
        data.motion = struct();
    end

    for i = 1:numel(fieldNames)
        fn = fieldNames{i};
        if ~isfield(data.motion,fn) || ~iscell(data.motion.(fn))
            data.motion.(fn) = cell(numAcquisitions,1);
        elseif numel(data.motion.(fn)) < numAcquisitions
            old = data.motion.(fn);
            tmp = cell(numAcquisitions,1);
            tmp(1:numel(old)) = old(:);
            data.motion.(fn) = tmp;
        end
    end
end


function data = ensure_motion_entry_exists(data,fieldNames,numAcquisitions,m)
    data = init_motion_data_struct_if_needed( ...
        data,numAcquisitions,fieldNames);
    for i = 1:numel(fieldNames)
        fn = fieldNames{i};
        if numel(data.motion.(fn)) < m
            tmp = cell(numAcquisitions,1);
            tmp(1:numel(data.motion.(fn))) = data.motion.(fn)(:);
            data.motion.(fn) = tmp;
        end
    end
end


function tf = motion_field_slot_exists(data,fieldName,m)
    tf = isfield(data,'motion') && isstruct(data.motion) && ...
        isfield(data.motion,fieldName) && ...
        iscell(data.motion.(fieldName)) && ...
        numel(data.motion.(fieldName)) >= m;
end


function tf = motion_field_has_value(data,fieldName,m)
    tf = motion_field_slot_exists(data,fieldName,m) && ...
        ~isempty(data.motion.(fieldName){m});
end


function tf = motion_status_exists(data,m)
    tf = motion_field_slot_exists(data,'motion_energy_status',m);
end


function data = assign_empty_camera_motion_fields_if_missing(data,m)
    fields = { ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group'};
    for k = 1:numel(fields)
        fn = fields{k};
        if ~motion_field_slot_exists(data,fn,m) || ...
                isempty(data.motion.(fn){m})
            data.motion.(fn){m} = [];
        end
    end
end


function data = assign_empty_binary_motion_fields_if_missing(data,m)
    fields = { ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group'};
    for k = 1:numel(fields)
        fn = fields{k};
        if ~motion_field_slot_exists(data,fn,m) || ...
                isempty(data.motion.(fn){m})
            data.motion.(fn){m} = [];
        end
    end
end


% =====================================================================
% Save
% =====================================================================

function save_motion_fields_if_needed( ...
    savePath,data,fields_motion,m,has_new_data,tseries_name)

    if ~has_new_data
        fprintf('\nMotion results\n');
        fprintf('  TSeries: %s\n',tseries_name);
        fprintf('  Status : no new data; results_motion.mat unchanged.\n');
        return;
    end

    saveStruct = struct();
    for f = 1:numel(fields_motion)
        fn = fields_motion{f};
        if isfield(data,'motion') && isfield(data.motion,fn) && ...
                iscell(data.motion.(fn)) && ...
                numel(data.motion.(fn)) >= m
            saveStruct.(fn) = data.motion.(fn){m};
        end
    end

    if isempty(fieldnames(saveStruct))
        return;
    end

    try
        if exist(savePath,'file') == 2
            save(savePath,'-struct','saveStruct','-append');
        else
            save(savePath,'-struct','saveStruct');
        end
        fprintf('\nMotion results\n');
        fprintf('  TSeries: %s\n',tseries_name);
        fprintf('  Status : results_motion.mat updated.\n');
        fprintf('  File   : %s\n',savePath);
    catch ME
        warning('load_or_process_motion:SaveFailed', ...
            'TSeries %s | unable to save motion results: %s', ...
            tseries_name,ME.message);
    end
end


% =====================================================================
% Existing camera-motion calculations
% =====================================================================

function strategy = ask_motion_energy_strategy_once()
    strategy = struct('open_in_fiji',false,'compute_direct',false,'skip',false);

    fprintf('\n============================================================\n');
    fprintf('MOTION ENERGY STRATEGY\n');
    fprintf('============================================================\n');

    choice = input([ ...
        'Open the camera movie in Fiji for cropping?\n' ...
        '  1 = Yes\n' ...
        '  2 = No\n' ...
        'Choice: '],'s');

    if strcmpi(choice,'1')
        strategy.open_in_fiji = true;
        return;
    end

    subchoice = input([ ...
        'Calculate motion energy on the current movie?\n' ...
        '  1 = Calculate directly\n' ...
        '  2 = Skip motion energy\n' ...
        'Choice: '],'s');

    if strcmpi(subchoice,'1')
        strategy.compute_direct = true;
    else
        strategy.skip = true;
    end
end


function motion_energy = compute_motion_energy_with_strategy(filepath,fijiPath,strategy)
    if strategy.open_in_fiji
        system(sprintf('"%s" "%s"',fijiPath,filepath));
        motion_energy = compute_motion_energy(filepath);
    elseif strategy.compute_direct
        motion_energy = compute_motion_energy(filepath);
    else
        motion_energy = [];
    end
end


function y = smooth_savgol(x,order,framelen_target)
    x = x(:);
    N = numel(x);
    framelen = min(framelen_target,N);
    if mod(framelen,2) == 0
        framelen = framelen - 1;
    end
    if framelen <= order
        framelen = order + 2;
        if mod(framelen,2) == 0
            framelen = framelen + 1;
        end
    end
    if N < framelen || framelen < 3
        y = x;
        return;
    end
    y = sgolayfilt(x,order,framelen);
end


function onsets = get_onsets(bin_motion)
    bin_motion = bin_motion(:);
    onsets = find(bin_motion(2:end)==1 & bin_motion(1:end-1)==0)+1;
end


function offsets = get_offsets(bin_motion)
    bin_motion = bin_motion(:);
    offsets = find(bin_motion(2:end)==0 & bin_motion(1:end-1)==1)+1;
end


% =====================================================================
% Figure
% =====================================================================

function save_motion_figure_if_missing( ...
    root_folder_m,data,m,animal,tseries_name, ...
    sampling_rate_motion_m,avg_block)

    png_filename = fullfile(root_folder_m,'binary_motion_energy.png');
    if isfile(png_filename)
        return;
    end

    if ~motion_field_has_value(data,'motion_energy_smooth_group',m)
        return;
    end

    y = data.motion.motion_energy_smooth_group{m};
    if isempty(y)
        return;
    end

    avg_onsets = [];
    avg_offsets = [];
    if motion_field_slot_exists(data,'avg_active_motion_onsets_group',m)
        avg_onsets = data.motion.avg_active_motion_onsets_group{m};
    end
    if motion_field_slot_exists(data,'avg_active_motion_offsets_group',m)
        avg_offsets = data.motion.avg_active_motion_offsets_group{m};
    end

    try
        [~,thr_li,~] = compute_thresholds_for_bin_state_detection(y,false);
        [bin_sig,~,~,~] = binarise_motion( ...
            y,thr_li,sampling_rate_motion_m,avg_block,3.0,5);

        fig = figure('Visible','off','Color','w');
        hold on;

        dt = avg_block / sampling_rate_motion_m;
        time_axis = (0:numel(y)-1)*dt;
        yl = [min(y),max(y)];
        if yl(1) == yl(2)
            yl = yl + [-1 1]*eps;
        end

        n = min(numel(avg_onsets),numel(avg_offsets));
        for k = 1:n
            a = round(avg_onsets(k));
            b = round(avg_offsets(k));
            if a < 1 || b < 1 || a > numel(time_axis) || b > numel(time_axis)
                continue;
            end
            patch([time_axis(a) time_axis(b) time_axis(b) time_axis(a)], ...
                [yl(1) yl(1) yl(2) yl(2)],[1 0.8 0.8], ...
                'EdgeColor','none','FaceAlpha',0.4);
        end

        plot(time_axis,bin_sig(:)'*yl(2),'Color',[1 0.5 0],'LineWidth',2);
        yline(thr_li,'--r','LineWidth',1);
        plot(time_axis,y,'Color',[0 0 1],'LineWidth',2);
        title(sprintf('Binary motion energy - %s - %s', ...
            animal,tseries_name), ...
            'Interpreter','none');
        xlabel('Time (s)');
        ylabel('Motion energy');
        grid on;
        hold off;
        saveas(fig,png_filename);
        close(fig);
    catch ME
        if exist('fig','var') && isgraphics(fig)
            close(fig);
        end
        warning('load_or_process_motion:FigureFailed', ...
            '%s | unable to create motion figure: %s', ...
            tseries_name,ME.message);
    end
end


% =====================================================================
% Misc helpers
% =====================================================================

function status_name = get_motion_status_name(data,m)
    status_name = 'unknown';
    if ~motion_status_exists(data,m) || ...
            isempty(data.motion.motion_energy_status{m})
        return;
    end
    raw = string(data.motion.motion_energy_status{m});
    switch raw
        case "done", status_name = 'completed';
        case "processing", status_name = 'partial processing';
        case "skipped", status_name = 'calculation skipped';
        case "no_camera", status_name = 'no camera data';
        case "no_motion", status_name = 'camera movie missing';
        otherwise, status_name = char(raw);
    end
end


% =====================================================================
% Metadata for one recording
% =====================================================================

function metadata_m = get_metadata_for_record(metadata, idx)

    metadata_m = struct();

    if isempty(metadata) || ...
            ~isstruct(metadata)
        return;
    end

    fields = fieldnames(metadata);

    for f = 1:numel(fields)

        field = fields{f};
        value = metadata.(field);

        if isstruct(value)

            metadata_m.(field) = ...
                get_metadata_for_record( ...
                    value, ...
                    idx);

        elseif iscell(value)

            if numel(value) >= idx

                metadata_m.(field) = ...
                    value{idx};

            else

                metadata_m.(field) = [];
            end

        else

            metadata_m.(field) = ...
                value;
        end
    end
end
