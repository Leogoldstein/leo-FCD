function selected_groups = process_selected_groups( ...
        selected_groups, ...
        include_electroporated, ...
        automatic_selection, ...
        processing_mode)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2
        include_electroporated = true;
    end

    if nargin < 4 || isempty(processing_mode)
        processing_mode = 'interactive';
    end

    processing_mode = ...
        char(string(processing_mode));

    if ~ismember( ...
            lower(processing_mode), ...
            {'load_only', 'interactive'})

        error( ...
            'processing_mode must be ''load_only'' or ''interactive''.');
    end

    %% ============================================================
    % Flatten all animals from all types into one job list.
    %
    % This avoids processing each type with a separate PARFOR and therefore
    % keeps the worker pool busy even when a type contains only 1-2 animals.
    % =============================================================

    type_names = ...
        fieldnames(selected_groups);

    job_types = {};
    job_indices = [];
    job_groups = {};
    job_automatic_selection = {};

    for t = 1:numel(type_names)

        current_type = ...
            type_names{t};

        groups = ...
            selected_groups.(current_type);

        current_automatic_selection = ...
            automatic_selection.(current_type);

        for k = 1:numel(groups)

            job_types{end + 1, 1} = ... %#ok<AGROW>
                current_type;

            job_indices(end + 1, 1) = ... %#ok<AGROW>
                k;

            job_groups{end + 1, 1} = ... %#ok<AGROW>
                groups(k);

            job_automatic_selection{end + 1, 1} = ... %#ok<AGROW>
                current_automatic_selection;
        end
    end

    numJobs = ...
        numel(job_groups);

    if numJobs == 0
        return;
    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('SELECTED GROUP PROCESSING\n');
    fprintf('Animals: %d\n', numJobs);
    fprintf('Mode   : %s\n', processing_mode);
    fprintf('============================================================\n');

    %% ============================================================
    % LOAD ONLY: un seul passage. Aucune interface et aucun fallback.
    % Un masque final manquant est ignore plan par plan, les autres plans
    % peuvent tout de meme terminer leur PASS 2 et leur finalisation.
    % =============================================================

    if strcmpi(processing_mode, 'load_only')

        pool = ...
            gcp('nocreate');

        if numJobs > 1 && isempty(pool)
            pool = parpool;
        end

        if numJobs > 1 && ~isempty(pool)
            parfor_workers = min(pool.NumWorkers, numJobs);
        else
            parfor_workers = 0;
        end

        processed_groups = ...
            cell(numJobs, 1);

        skipped_counts = ...
            zeros(numJobs, 1);

        parfor (j = 1:numJobs, parfor_workers)

            [current_group, processing_cache] = ...
                process_single_animal_base( ...
                    job_groups{j}, ...
                    include_electroporated, ...
                    job_automatic_selection{j}, ...
                    'load_only');

            % La granularite est bien acquisition + plan, pas animal.
            skip_planes = ...
                cell(numel(processing_cache), 1);

            skipped_j = 0;

            for m = 1:numel(processing_cache)

                cache = processing_cache{m};

                if isempty(cache) || ~isstruct(cache)
                    skip_planes{m} = [];
                    continue;
                end

                skip_m = ...
                    false(cache.nPlanes, 1);

                if isfield(cache, 'skip_group') && ...
                        cache.skip_group && ...
                        isequal(include_electroporated, 1)

                    skip_m(:) = true;

                elseif isfield(cache, 'skip_plane_by_plane') && ...
                        ~isempty(cache.skip_plane_by_plane)

                    raw = logical(cache.skip_plane_by_plane(:));
                    n = min(numel(raw), cache.nPlanes);
                    skip_m(1:n) = raw(1:n);
                end

                skip_planes{m} = skip_m;
                skipped_j = skipped_j + nnz(skip_m);
            end

            % Combined ignore seulement les plans manquants ; overview
            % reste disponible pour les autres acquisitions/plans.
            current_group = ...
                finalize_single_animal_processing( ...
                    current_group, ...
                    include_electroporated, ...
                    job_automatic_selection{j}, ...
                    skip_planes);

            processed_groups{j} = ...
                current_group;

            skipped_counts(j) = ...
                skipped_j;
        end

        fprintf( ...
            '\nLOAD_ONLY completed: %d plane(s) skipped (no UI launched).\n', ...
            sum(skipped_counts));

    else

        %% ========================================================
        % INTERACTIVE
        %
        % The whole animal remains sequential because ZSeries, motion and
        % Cellpose can all display UI / request user input.
        % =========================================================

        processed_groups = ...
            cell(numJobs, 1);

        for j = 1:numJobs

            current_group = ...
                job_groups{j};

            current_automatic_selection = ...
                job_automatic_selection{j};

            fprintf('\n');
            fprintf('============================================================\n');
            fprintf('INTERACTIVE ANIMAL %d/%d\n', j, numJobs);
            fprintf('Type  : %s\n', job_types{j});
            fprintf('Animal: %s\n', ...
                char(string(current_group.animal)));
            fprintf('============================================================\n');

            [ ...
                current_group, ...
                processing_cache ...
            ] = ...
                process_single_animal_base( ...
                    current_group, ...
                    include_electroporated, ...
                    current_automatic_selection, ...
                    'interactive');

            paths = ...
                current_group.paths;

            data = ...
                current_group.data;

            [electroporated_plane, data] = ...
                process_electroporated_pass2( ...
                    processing_cache, ...
                    paths.gcamp_output, ...
                    data.gcamp_plane.meanImgs_gcamp, ...
                    data);

            data.electroporated_plane = ...
                electroporated_plane;

            current_group.data = ...
                data;

            current_group = ...
                finalize_single_animal_processing( ...
                    current_group, ...
                    include_electroporated, ...
                    current_automatic_selection);

            processed_groups{j} = ...
                current_group;
        end
    end

    %% ============================================================
    % Reinsert into selected_groups
    % =============================================================

    for j = 1:numJobs

        current_type = ...
            job_types{j};

        current_index = ...
            job_indices(j);

        selected_groups.(current_type)(current_index) = ...
            processed_groups{j};
    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('SELECTED GROUP PROCESSING COMPLETED\n');
    fprintf('Animals: %d\n', numJobs);
    fprintf('============================================================\n');
end
