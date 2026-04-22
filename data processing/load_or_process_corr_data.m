function data = load_or_process_corr_data(gcamp_root_folders, data)
% load_or_process_corr_data
% - Sorties au format "par session" -> {m} = cell(1,nPlanes), chaque {p} = matrice/vecteur
% - Lit/écrit results_corr.mat dans chaque dossier session
% - compute_pairwise_corr est utilisé uniquement comme fonction de calcul brut
% - Remplit :
%       data.corr.max_corr_gcamp_gcamp_by_plane
%       data.corr.max_corr_gcamp_mtor_by_plane
%       data.corr.max_corr_mtor_mtor_by_plane
%
% Nouvelle structure attendue :
%   data.gcamp_plane.DF_gcamp_by_plane
%   data.combined_plane.DF_combined_by_plane
%   data.combined_plane.blue_indices_combined_by_plane

    numFolders = numel(gcamp_root_folders);

    data = init_corr_struct_if_needed(data, numFolders);

    max_corr_gcamp_gcamp_by_plane = data.corr.max_corr_gcamp_gcamp_by_plane;
    max_corr_gcamp_mtor_by_plane  = data.corr.max_corr_gcamp_mtor_by_plane;
    max_corr_mtor_mtor_by_plane   = data.corr.max_corr_mtor_mtor_by_plane;

    for m = 1:numFolders

        if isempty(gcamp_root_folders) || m > numel(gcamp_root_folders) || isempty(gcamp_root_folders{m})
            fprintf('Session %d: gcamp_root_folders vide, skip.\n', m);
            continue;
        end

        filePath = fullfile(gcamp_root_folders{m}, 'results_corr.mat');
        disp(filePath);

        has_combined_by_plane = ...
            isfield(data, 'combined_plane') && isstruct(data.combined_plane) && ...
            isfield(data.combined_plane, 'DF_combined_by_plane') && ...
            numel(data.combined_plane.DF_combined_by_plane) >= m && ...
            ~isempty(data.combined_plane.DF_combined_by_plane{m});

        use_combined = has_combined_by_plane;

        DFg_planes = get_planes_or_error_nested(data, 'gcamp_plane', m, 'DF_gcamp_by_plane');
        nPlanes = numel(DFg_planes);

        if nPlanes < 1
            error('Session %d: aucun plan dans data.gcamp_plane.DF_gcamp_by_plane{%d}.', m, m);
        end

        DFc_planes = [];
        blue_idx_planes = [];

        if use_combined
            DFc_planes = get_planes_or_error_nested(data, 'combined_plane', m, 'DF_combined_by_plane');

            if ~isfield(data, 'combined_plane') || ~isstruct(data.combined_plane) || ...
               ~isfield(data.combined_plane, 'blue_indices_combined_by_plane') || ...
               numel(data.combined_plane.blue_indices_combined_by_plane) < m || ...
               isempty(data.combined_plane.blue_indices_combined_by_plane{m})
                error('Session %d: data.combined_plane.blue_indices_combined_by_plane{%d} manquant/vide.', m, m);
            end

            blue_idx_planes = data.combined_plane.blue_indices_combined_by_plane{m};

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
                        DFg, gcamp_root_folders{m}, DFc, blue_idx);
                else
                    [mc_gg, mc_gm, mc_mm] = compute_pairwise_corr( ...
                        DFg, gcamp_root_folders{m});
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
    data.corr.max_corr_gcamp_gcamp_by_plane = max_corr_gcamp_gcamp_by_plane;
    data.corr.max_corr_gcamp_mtor_by_plane  = max_corr_gcamp_mtor_by_plane;
    data.corr.max_corr_mtor_mtor_by_plane   = max_corr_mtor_mtor_by_plane;
end


% ========================= utilities =========================

function data = init_corr_struct_if_needed(data, numFolders)

    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'corr') || ~isstruct(data.corr) || isempty(data.corr)
        data.corr = struct();
    end

    corr_fields = { ...
        'max_corr_gcamp_gcamp_by_plane', ...
        'max_corr_gcamp_mtor_by_plane', ...
        'max_corr_mtor_mtor_by_plane' ...
    };

    for i = 1:numel(corr_fields)
        fn = corr_fields{i};
        if ~isfield(data.corr, fn) || ~iscell(data.corr.(fn))
            data.corr.(fn) = cell(numFolders, 1);
        elseif numel(data.corr.(fn)) < numFolders
            oldv = data.corr.(fn);
            tmp = cell(numFolders,1);
            tmp(1:numel(oldv)) = oldv(:);
            data.corr.(fn) = tmp;
        end
    end
end

function planes = get_planes_or_error_nested(data, branchName, m, fieldName)

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        error('Session %d: branche "%s" manquante.', m, branchName);
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        error('Session %d: champ "%s.%s" manquant ou vide. (format by_plane requis)', ...
            m, branchName, fieldName);
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes) || isempty(planes)
        error('Session %d: "%s.%s{%d}" doit être une cell non vide de plans.', ...
            m, branchName, fieldName, m);
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