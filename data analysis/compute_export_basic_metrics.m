function results_analysis = compute_export_basic_metrics(selected_groups, k, sampling_rate_group)

    % -------------------------------
    % Infos groupe courant
    % -------------------------------
    current_animal_group     = selected_groups(k).animal_group;
    current_ages_group       = selected_groups(k).ages;
    gcamp_output_folders     = selected_groups(k).gcamp_output_folders;
    data                     = selected_groups(k).data;

    nRec = numel(gcamp_output_folders);

    % -------------------------------
    % results_analysis: store ALL values (vectors), not mean/std
    % -------------------------------
    field_order = { ...
        'current_animal_group', ...
        'TseriesFolder', ...
        'Age', ...
        'NumFrames', ...
        'ActiveCellsNumber', ...
        'ActiveCellsNumberBlue', ...
        'FrequencyPerCell_gcamp', ...
        'FrequencyPerCell_blue', ...
        'DurationPerCell_gcamp_s', ...
        'DurationPerCell_blue_s', ...
        'IEImeanPerCell_gcamp_s', ...
        'IEImeanPerCell_blue_s', ...
        'AmplitudePerCell_gcamp', ...
        'AmplitudePerCell_blue' ...
        };

    results_analysis = repmat( ...
        cell2struct(repmat({[]}, 1, numel(field_order)), field_order, 2), ...
        nRec, 1);

    % folder names
    current_gcamp_folders_names_group = cell(nRec,1);
    for m = 1:nRec
        [~, current_gcamp_folders_names_group{m}] = fileparts(gcamp_output_folders{m});
    end

    % ---------------------------------------------------------------------
    % Main loop
    % ---------------------------------------------------------------------
    for m = 1:nRec
        try
            % 0) combined?
            has_combined_by_plane = isfield(data,'DF_combined_by_plane') && ...
                numel(data.DF_combined_by_plane) >= m && ...
                ~isempty(data.DF_combined_by_plane{m});
            use_combined = has_combined_by_plane;

            sampling_rate = sampling_rate_group{m};

            %==========================================================
            % 1) GCaMP : concat tous les plans
            %==========================================================
            DF_gcamp       = concat_planes(data, m, 'DF_gcamp_by_plane');
            Raster_gcamp   = concat_planes(data, m, 'Raster_gcamp_by_plane');
            Acttmp2_gcamp  = concat_acttmp2_planes(data, m, 'Acttmp2_gcamp_by_plane');      % cell per cell
            StartEnd_gcamp = concat_startend_planes(data, m, 'StartEnd_gcamp_by_plane');    % cell per cell

            if isempty(DF_gcamp) || isempty(Raster_gcamp)
                warning('Skipping rec %d (%s) — DF/Raster GCaMP vide.', m, gcamp_output_folders{m});
                continue;
            end

            [DF_gcamp, Raster_gcamp] = align_data(DF_gcamp, Raster_gcamp);
            [num_cells, Nframes] = size(Raster_gcamp);

            % All freqs per cell (/min)
            freq_gcamp = compute_frequency_from_raster(Raster_gcamp, sampling_rate);

            % All amplitudes per cell
            amp_gcamp = compute_normalized_amplitude_per_cell(DF_gcamp, Acttmp2_gcamp);

            % All durations per cell (mean duration per cell, seconds)
            dur_cell_gcamp = extract_mean_duration_per_cell_full(StartEnd_gcamp, sampling_rate);

            % Inter-event interval per cell (mean IEI per cell, seconds)
            [iei_mean_gcamp, iei_all_gcamp] = compute_iei_per_cell(Acttmp2_gcamp, sampling_rate);

            %==========================================================
            % 2) BLUE : seulement si COMBINED
            %==========================================================
            num_cells_blue = NaN;
            freq_blue = [];
            amp_blue  = [];
            dur_cell_blue = [];
            iei_mean_blue = [];
            iei_all_blue  = {};

            if use_combined
                DF_blue       = concat_planes(data, m, 'DF_blue_by_plane');
                Raster_blue   = concat_planes(data, m, 'Raster_blue_by_plane');
                Acttmp2_blue  = concat_acttmp2_planes(data, m, 'Acttmp2_blue_by_plane');
                StartEnd_blue = concat_startend_planes(data, m, 'StartEnd_blue_by_plane');

                if ~isempty(DF_blue) && ~isempty(Raster_blue)
                    [DF_blue, Raster_blue] = align_data(DF_blue, Raster_blue);
                    [num_cells_blue, Nframes_blue] = size(Raster_blue);

                    freq_blue = compute_frequency_from_raster(Raster_blue, sampling_rate);
                    amp_blue  = compute_normalized_amplitude_per_cell(DF_blue, Acttmp2_blue);
                    dur_cell_blue = extract_mean_duration_per_cell_full(StartEnd_blue, sampling_rate);
                    [iei_mean_blue, iei_all_blue] = compute_iei_per_cell(Acttmp2_blue, sampling_rate);
                end
            end

            %==========================================================
            % Store in results_analysis (VECTEURS, pas moy/std)
            %==========================================================
            results_analysis(m).current_animal_group     = current_animal_group;
            results_analysis(m).TseriesFolder            = current_gcamp_folders_names_group{m};
            if numel(current_ages_group) >= m
                results_analysis(m).Age = current_ages_group{m};
            end

            results_analysis(m).NumFrames               = Nframes;
            results_analysis(m).ActiveCellsNumber       = num_cells;
            results_analysis(m).ActiveCellsNumberBlue   = num_cells_blue;

            results_analysis(m).FrequencyPerCell_gcamp     = freq_gcamp(:);
            results_analysis(m).AmplitudePerCell_gcamp     = amp_gcamp(:);
            results_analysis(m).DurationPerCell_gcamp_s    = dur_cell_gcamp(:);
            results_analysis(m).IEImeanPerCell_gcamp_s     = iei_mean_gcamp(:);

            results_analysis(m).FrequencyPerCell_blue      = freq_blue(:);
            results_analysis(m).AmplitudePerCell_blue      = amp_blue(:);
            results_analysis(m).DurationPerCell_blue_s     = dur_cell_blue(:);
            results_analysis(m).IEImeanPerCell_blue_s      = iei_mean_blue(:);

        catch ME
            fprintf('Error processing rec %d: %s\n', m, ME.message);
        end
    end
end

% =====================================================================
% HELPERS
% =====================================================================

function Act_all = concat_acttmp2_planes(data, m, fieldName)
    Act_all = {};
    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        return;
    end
    planes = data.(fieldName){m};
    for p = 1:numel(planes)
        A = planes{p};
        if isempty(A), continue; end
        if ~iscell(A)
            A = num2cell(A, 2);
        end
        Act_all = [Act_all; A(:)]; %#ok<AGROW>
    end
end

function SE_all = concat_startend_planes(data, m, fieldName)
    SE_all = {};
    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        return;
    end
    planes = data.(fieldName){m};
    for p = 1:numel(planes)
        SE = planes{p};
        if isempty(SE), continue; end
        if ~iscell(SE)
            error('StartEnd attendu en cell array (plan %d)', p);
        end
        SE_all = [SE_all; SE(:)]; %#ok<AGROW>
    end
end

function out = concat_planes(data, m, fieldName)
    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        out = [];
        return;
    end
    planes = data.(fieldName){m};
    if isempty(planes)
        out = [];
        return;
    end
    out = [];
    for p = 1:numel(planes)
        if ~isempty(planes{p})
            out = [out; planes{p}]; %#ok<AGROW>
        end
    end
end

function [DF, Raster] = align_data(DF, Raster)
    min_cells  = min(size(DF,1), size(Raster,1));
    min_frames = min(size(DF,2), size(Raster,2));
    DF     = DF(1:min_cells, 1:min_frames);
    Raster = Raster(1:min_cells, 1:min_frames);
end

function freq_per_cell_per_min = compute_frequency_from_raster(Raster, sampling_rate)
% Raster: nCells x nFrames, 0/1 avec 1 = pic (1 frame par événement)
% sampling_rate: Hz
% Retour: nCells x 1, événements/min

    if isempty(Raster) || sampling_rate <= 0
        freq_per_cell_per_min = [];
        return;
    end

    Raster = Raster ~= 0; % logique
    [nCells, nFrames] = size(Raster);

    duration_min = (nFrames / sampling_rate) / 60;
    if duration_min <= 0
        freq_per_cell_per_min = nan(nCells,1);
        return;
    end

    nEvents = sum(Raster, 2); % 1 frame = 1 événement
    freq_per_cell_per_min = nEvents ./ duration_min;
end

function amp = compute_normalized_amplitude_per_cell(DF, Acttmp2)
    if isempty(DF) || isempty(Acttmp2)
        amp = NaN(size(DF,1),1);
        return;
    end
    [nCells, nFrames] = size(DF);
    amp = nan(nCells,1);
    for c = 1:nCells
        if iscell(Acttmp2)
            frames = Acttmp2{c};
        elseif isnumeric(Acttmp2) && size(Acttmp2,2) == nFrames
            frames = find(Acttmp2(c,:) > 0);
        else
            frames = [];
        end
        if isempty(frames)
            continue;
        end
        amp(c) = mean(DF(c,frames), 'omitnan');
    end
end

function mean_durations_per_cell = extract_mean_duration_per_cell_full(StartEnd, sampling_rate)
% Retourne un vecteur Ncells×1 : durée moyenne des événements pour chaque cellule (s)
    if isempty(StartEnd)
        mean_durations_per_cell = [];
        return;
    end
    mean_durations_per_cell = nan(numel(StartEnd),1);
    for c = 1:numel(StartEnd)
        intervals = StartEnd{c};
        if isempty(intervals)
            continue;
        end
        ev_dur_s = (intervals(:,2) - intervals(:,1)) / sampling_rate;
        mean_durations_per_cell(c) = mean(ev_dur_s, 'omitnan');
    end
end

function [iei_mean_per_cell, iei_all_per_cell] = compute_iei_per_cell(Acttmp2, sampling_rate)
% Inter-event interval (IEI) entre transitoires: diff entre événements successifs
% - iei_all_per_cell{c} = vecteur des intervalles (s)
% - iei_mean_per_cell(c) = moyenne des intervalles (s), NaN si <2 events
    if isempty(Acttmp2)
        iei_mean_per_cell = [];
        iei_all_per_cell  = {};
        return;
    end

    if ~iscell(Acttmp2)
        % si Acttmp2 est un raster (nCells x nFrames)
        Acttmp2 = num2cell(Acttmp2, 2);
    end

    nCells = numel(Acttmp2);
    iei_mean_per_cell = nan(nCells,1);
    iei_all_per_cell  = cell(nCells,1);

    for c = 1:nCells
        frames = Acttmp2{c};
        if isempty(frames)
            iei_all_per_cell{c} = [];
            continue;
        end
        frames = frames(:);
        frames = frames(isfinite(frames));
        frames = sort(unique(frames));

        if numel(frames) < 2
            iei_all_per_cell{c} = [];
            continue;
        end

        iei_s = diff(frames) / sampling_rate;
        iei_all_per_cell{c} = iei_s;
        iei_mean_per_cell(c) = mean(iei_s, 'omitnan');
    end
end
