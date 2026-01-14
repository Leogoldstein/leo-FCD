function data = load_or_process_corr_data(gcamp_output_folders, data)
    % BY-PLANE ONLY.
    % - COMBINED uniquement si DF_combined_by_plane{m} existe (jamais DF_combined{m})
    % - GCaMP-only sinon
    % - blue_indices_combined_by_plane est supposé déjà extrait (on ne crée/remplit pas)

    numFolders = numel(gcamp_output_folders);

    % Champs résultats (by-plane)
    out_fields = { ...
        'max_corr_gcamp_gcamp_by_plane', ...
        'max_corr_gcamp_mtor_by_plane', ...
        'max_corr_mtor_mtor_by_plane'};

    % Init si manquants
    for i = 1:numel(out_fields)
        if ~isfield(data, out_fields{i})
            data.(out_fields{i}) = cell(numFolders, 1);
            [data.(out_fields{i}){:}] = deal([]);
        end
    end

    for m = 1:numFolders
        filePath = fullfile(gcamp_output_folders{m}, 'results_corrs.mat');
        disp(filePath);

        %----------------------------------------------------------
        % 1) Déterminer COMBINED vs GCaMP-only (BY-PLANE ONLY)
        %----------------------------------------------------------
        has_combined_by_plane = isfield(data,'DF_combined_by_plane') && ...
                                numel(data.DF_combined_by_plane) >= m && ...
                                ~isempty(data.DF_combined_by_plane{m});
        use_combined = has_combined_by_plane;

        %----------------------------------------------------------
        % 2) DF GCaMP par plan : requis
        %----------------------------------------------------------
        DFg_planes = get_planes_or_error(data, m, 'DF_gcamp_by_plane');
        nPlanes = numel(DFg_planes);
        if nPlanes < 1
            error('Session %d: aucun plan trouvé dans DF_gcamp_by_plane{%d}.', m, m);
        end

        %----------------------------------------------------------
        % 3) En COMBINED : DF_combined_by_plane + blue indices requis
        %----------------------------------------------------------
        DFc_planes = [];
        blue_idx_planes = [];

        if use_combined
            DFc_planes = get_planes_or_error(data, m, 'DF_combined_by_plane');

            if ~isfield(data,'blue_indices_combined_by_plane') || ...
               numel(data.blue_indices_combined_by_plane) < m || ...
               isempty(data.blue_indices_combined_by_plane{m})
                error('Session %d: blue_indices_combined_by_plane{%d} manquant/vide (COMBINED).', m, m);
            end
            blue_idx_planes = data.blue_indices_combined_by_plane{m};

            if ~iscell(blue_idx_planes)
                error('Session %d: blue_indices_combined_by_plane{%d} doit être une cell par plan.', m, m);
            end

            % Sanity: alignement des plans
            if numel(DFc_planes) ~= nPlanes
                error('Session %d: mismatch #plans DF_gcamp(%d) vs DF_combined(%d).', ...
                      m, nPlanes, numel(DFc_planes));
            end
            if numel(blue_idx_planes) ~= nPlanes
                error('Session %d: mismatch #plans DF_gcamp(%d) vs blue_indices(%d).', ...
                      m, nPlanes, numel(blue_idx_planes));
            end
        end

        %----------------------------------------------------------
        % 4) Charger si existe, sinon calculer/sauver
        %----------------------------------------------------------
        if exist(filePath, 'file') == 2
            loaded = load(filePath);

            data.max_corr_gcamp_gcamp_by_plane{m} = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane', []);
            data.max_corr_gcamp_mtor_by_plane{m}  = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane', []);
            data.max_corr_mtor_mtor_by_plane{m}   = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane', []);

            assert(iscell(data.max_corr_gcamp_gcamp_by_plane{m}), ...
                'Session %d: max_corr_gcamp_gcamp_by_plane n''est pas une cell.', m);
            assert(iscell(data.max_corr_gcamp_mtor_by_plane{m}), ...
                'Session %d: max_corr_gcamp_mtor_by_plane n''est pas une cell.', m);
            assert(iscell(data.max_corr_mtor_mtor_by_plane{m}), ...
                'Session %d: max_corr_mtor_mtor_by_plane n''est pas une cell.', m);

        else
            disp(['Computing and saving pairwise correlations (BY PLANE) for folder ', num2str(m)]);

            max_corr_gcamp_gcamp_by_plane = cell(nPlanes, 1);
            max_corr_gcamp_mtor_by_plane  = cell(nPlanes, 1);
            max_corr_mtor_mtor_by_plane   = cell(nPlanes, 1);

            for p = 1:nPlanes
                DFg = DFg_planes{p};

                if isempty(DFg)
                    max_corr_gcamp_gcamp_by_plane{p} = [];
                    max_corr_gcamp_mtor_by_plane{p}  = [];
                    max_corr_mtor_mtor_by_plane{p}   = [];
                    continue;
                end

                if use_combined
                    DFc = DFc_planes{p};
                    blue_idx = blue_idx_planes{p};

                    [mc_gg, mc_gm, mc_mm] = compute_pairwise_corr( ...
                        DFg, gcamp_output_folders{m}, DFc, blue_idx);

                    max_corr_gcamp_gcamp_by_plane{p} = mc_gg;
                    max_corr_gcamp_mtor_by_plane{p}  = mc_gm;
                    max_corr_mtor_mtor_by_plane{p}   = mc_mm;

                else
                    % GCaMP-only : uniquement gcamp-gcamp
                    [mc_gg, ~, ~] = compute_pairwise_corr( ...
                        DFg, gcamp_output_folders{m}, [], []);

                    max_corr_gcamp_gcamp_by_plane{p} = mc_gg;
                    max_corr_gcamp_mtor_by_plane{p}  = [];
                    max_corr_mtor_mtor_by_plane{p}   = [];
                end
            end

            % Stocker + sauver (nouveau format uniquement)
            data.max_corr_gcamp_gcamp_by_plane{m} = max_corr_gcamp_gcamp_by_plane;
            data.max_corr_gcamp_mtor_by_plane{m}  = max_corr_gcamp_mtor_by_plane;
            data.max_corr_mtor_mtor_by_plane{m}   = max_corr_mtor_mtor_by_plane;

            save(filePath, ...
                'max_corr_gcamp_gcamp_by_plane', ...
                'max_corr_gcamp_mtor_by_plane', ...
                'max_corr_mtor_mtor_by_plane');
        end
    end
end

% ---------------- utilities ----------------

function planes = get_planes_or_error(data, m, fieldName)
    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        error('Session %d: champ "%s" manquant ou vide. (format by_plane requis)', m, fieldName);
    end
    planes = data.(fieldName){m};
    if ~iscell(planes) || isempty(planes)
        error('Session %d: "%s{%d}" doit être une cell non vide de plans.', m, fieldName, m);
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end
