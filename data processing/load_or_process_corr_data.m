function data = load_or_process_corr_data(gcamp_output_folders, data, current_ages_group, animal_name)
% load_or_process_corr_data
% - Sorties au format "par session" -> {m} = cell(1,nPlanes), chaque {p} = matrice/vecteur
% - Lit/écrit results_corr.mat dans chaque dossier session
% - compute_pairwise_corr est utilisé uniquement comme fonction de calcul brut
% - Trace directement les figures combinées des corrélations
% - Remplit aussi data.max_corr_gcamp_gcamp_by_plane, data.max_corr_gcamp_mtor_by_plane,
%   data.max_corr_mtor_mtor_by_plane

    numFolders = numel(gcamp_output_folders);

    max_corr_gcamp_gcamp_by_plane = cell(numFolders, 1);
    max_corr_gcamp_mtor_by_plane  = cell(numFolders, 1);
    max_corr_mtor_mtor_by_plane   = cell(numFolders, 1);

    for m = 1:numFolders
        filePath = fullfile(gcamp_output_folders{m}, 'results_corr.mat');
        disp(filePath);

        has_combined_by_plane = isfield(data,'DF_combined_by_plane') && ...
                                numel(data.DF_combined_by_plane) >= m && ...
                                ~isempty(data.DF_combined_by_plane{m});
        use_combined = has_combined_by_plane;

        DFg_planes = get_planes_or_error(data, m, 'DF_gcamp_by_plane');
        nPlanes = numel(DFg_planes);

        if nPlanes < 1
            error('Session %d: aucun plan dans DF_gcamp_by_plane{%d}.', m, m);
        end

        DFc_planes = [];
        blue_idx_planes = [];
        if use_combined
            DFc_planes = get_planes_or_error(data, m, 'DF_combined_by_plane');

            if ~isfield(data,'blue_indices_combined_by_plane') || ...
               numel(data.blue_indices_combined_by_plane) < m || ...
               isempty(data.blue_indices_combined_by_plane{m})
                error('Session %d: blue_indices_combined_by_plane{%d} manquant/vide.', m, m);
            end

            blue_idx_planes = data.blue_indices_combined_by_plane{m};

            if ~iscell(blue_idx_planes)
                error('Session %d: blue_indices_combined_by_plane{%d} doit être une cell par plan.', m, m);
            end

            if numel(DFc_planes) ~= nPlanes
                error('Session %d: mismatch #plans DF_gcamp(%d) vs DF_combined(%d).', ...
                    m, nPlanes, numel(DFc_planes));
            end

            if numel(blue_idx_planes) ~= nPlanes
                error('Session %d: mismatch #plans DF_gcamp(%d) vs blue_indices(%d).', ...
                    m, nPlanes, numel(blue_idx_planes));
            end
        end

        mc_gg_planes = cell(1, nPlanes);
        mc_gm_planes = cell(1, nPlanes);
        mc_mm_planes = cell(1, nPlanes);

        % ==================================================
        % 1) Chargement si déjà présent
        % ==================================================
        if exist(filePath, 'file') == 2
            loaded = load(filePath);

            mc_gg_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane', mc_gg_planes);
            mc_gm_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane',  mc_gm_planes);
            mc_mm_planes = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane',   mc_mm_planes);

            % fallback ancien format
            mc_gg_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane_file', mc_gg_planes);
            mc_gm_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane_file',  mc_gm_planes);
            mc_mm_planes = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane_file',   mc_mm_planes);

            % fallback encore plus ancien
            mc_gg_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane_s', mc_gg_planes);
            mc_gm_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane_s',  mc_gm_planes);
            mc_mm_planes = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane_s',   mc_mm_planes);

            if ~iscell(mc_gg_planes), mc_gg_planes = cell(1,nPlanes); end
            if ~iscell(mc_gm_planes), mc_gm_planes = cell(1,nPlanes); end
            if ~iscell(mc_mm_planes), mc_mm_planes = cell(1,nPlanes); end

            mc_gg_planes = ensure_plane_cell(mc_gg_planes, nPlanes);
            mc_gm_planes = ensure_plane_cell(mc_gm_planes, nPlanes);
            mc_mm_planes = ensure_plane_cell(mc_mm_planes, nPlanes);

        else
            % ==================================================
            % 2) Calcul brut par plan
            % ==================================================
            disp(['Computing pairwise correlations (BY PLANE) for folder ', num2str(m)]);

            for p = 1:nPlanes
                DFg = DFg_planes{p};

                if isempty(DFg)
                    mc_gg_planes{p} = [];
                    mc_gm_planes{p} = [];
                    mc_mm_planes{p} = [];
                    continue;
                end

                if use_combined
                    DFc = DFc_planes{p};
                    blue_idx = blue_idx_planes{p};

                    [mc_gg, mc_gm, mc_mm] = compute_pairwise_corr( ...
                        DFg, gcamp_output_folders{m}, DFc, blue_idx);
                else
                    [mc_gg, mc_gm, mc_mm] = compute_pairwise_corr( ...
                        DFg, gcamp_output_folders{m});
                end

                mc_gg_planes{p} = mc_gg;
                mc_gm_planes{p} = mc_gm;
                mc_mm_planes{p} = mc_mm;
            end

            % ==================================================
            % 3) Sauvegarde avec noms cohérents
            % ==================================================
            saveStruct = struct();
            saveStruct.max_corr_gcamp_gcamp_by_plane = mc_gg_planes;
            saveStruct.max_corr_gcamp_mtor_by_plane  = mc_gm_planes;
            saveStruct.max_corr_mtor_mtor_by_plane   = mc_mm_planes;

            save(filePath, '-struct', 'saveStruct');
        end

        % ==================================================
        % 4) Sorties
        % ==================================================
        max_corr_gcamp_gcamp_by_plane{m} = mc_gg_planes;
        max_corr_gcamp_mtor_by_plane{m}  = mc_gm_planes;
        max_corr_mtor_mtor_by_plane{m}   = mc_mm_planes;
    end

    % ==================================================
    % 5) Injecter dans data
    % ==================================================
    data.max_corr_gcamp_gcamp_by_plane = max_corr_gcamp_gcamp_by_plane;
    data.max_corr_gcamp_mtor_by_plane  = max_corr_gcamp_mtor_by_plane;
    data.max_corr_mtor_mtor_by_plane   = max_corr_mtor_mtor_by_plane;
end

% ========================= utilities =========================

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

function c = ensure_plane_cell(c, nPlanes)
    if isempty(c)
        c = cell(1,nPlanes);
        return;
    end

    if ~iscell(c)
        c = cell(1,nPlanes);
        return;
    end

    c = c(:).';
    if numel(c) > nPlanes
        c = c(1:nPlanes);
    elseif numel(c) < nPlanes
        c = [c, cell(1, nPlanes-numel(c))];
    end
end

