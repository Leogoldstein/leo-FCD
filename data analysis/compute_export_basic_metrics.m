function results_analysis = compute_export_basic_metrics(current_animal_group, current_ages_group,  gcamp_output_folders, data, sampling_rate_group)

    nRec = numel(gcamp_output_folders);

    % -------------------------------
    % results_analysis: store ALL values (vectors), not mean/std
    % -------------------------------
    field_order = { ...
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
        'AmplitudePerCell_blue', ...
        'SCEsThreshold', ...
        'SCEsNumber', ...
        'SCEsFrequencyHz', ...
        'PercentageActiveCellsSCEs', ...
        'MeanSCEsduration_ms' ...
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
            sampling_rate = sampling_rate_group{m};

            has_gcamp = has_nonempty_plane_field(data, 'DF_gcamp_by_plane', m) && ...
                        has_nonempty_plane_field(data, 'Raster_gcamp_by_plane', m);

            has_blue_direct = has_nonempty_plane_field(data, 'DF_blue_by_plane', m) && ...
                              has_nonempty_plane_field(data, 'Raster_blue_by_plane', m);

            has_combined = has_nonempty_plane_field(data, 'DF_combined_by_plane', m) && ...
                           has_nonempty_plane_field(data, 'Raster_combined_by_plane', m) && ...
                           has_nonempty_plane_field(data, 'blue_indices_combined_by_plane', m);

            % ==========================================================
            % 1) GCaMP : concat tous les plans
            % ==========================================================
            DF_gcamp       = concat_planes(data, m, 'DF_gcamp_by_plane');
            Raster_gcamp   = concat_planes(data, m, 'Raster_gcamp_by_plane');
            Acttmp2_gcamp  = concat_acttmp2_planes(data, m, 'Acttmp2_gcamp_by_plane');
            StartEnd_gcamp = concat_startend_planes(data, m, 'StartEnd_gcamp_by_plane');

            if ~has_gcamp || isempty(DF_gcamp) || isempty(Raster_gcamp)
                warning('Skipping rec %d (%s) — DF/Raster GCaMP vide.', m, gcamp_output_folders{m});
                continue;
            end

            [DF_gcamp, Raster_gcamp] = align_data(DF_gcamp, Raster_gcamp);
            [num_cells, Nframes] = size(Raster_gcamp);

            freq_gcamp = compute_frequency_from_raster(Raster_gcamp, sampling_rate);
            amp_gcamp = compute_normalized_amplitude_per_cell(DF_gcamp, Acttmp2_gcamp);
            dur_cell_gcamp = extract_mean_duration_per_cell_full(StartEnd_gcamp, sampling_rate);
            [iei_mean_gcamp, ~] = compute_iei_per_cell(Acttmp2_gcamp, sampling_rate);

            % ==========================================================
            % 2) BLUE
            %    priorité aux champs blue directs
            %    sinon reconstruction depuis combined
            % ==========================================================
            num_cells_blue = NaN;
            freq_blue = [];
            amp_blue  = [];
            dur_cell_blue = [];
            iei_mean_blue = [];

            if has_blue_direct
                DF_blue       = concat_planes(data, m, 'DF_blue_by_plane');
                Raster_blue   = concat_planes(data, m, 'Raster_blue_by_plane');
                Acttmp2_blue  = concat_acttmp2_planes(data, m, 'Acttmp2_blue_by_plane');
                StartEnd_blue = concat_startend_planes(data, m, 'StartEnd_blue_by_plane');

                if ~isempty(DF_blue) && ~isempty(Raster_blue)
                    [DF_blue, Raster_blue] = align_data(DF_blue, Raster_blue);
                    [num_cells_blue, ~] = size(Raster_blue);

                    freq_blue = compute_frequency_from_raster(Raster_blue, sampling_rate);
                    amp_blue  = compute_normalized_amplitude_per_cell(DF_blue, Acttmp2_blue);
                    dur_cell_blue = extract_mean_duration_per_cell_full(StartEnd_blue, sampling_rate);
                    [iei_mean_blue, ~] = compute_iei_per_cell(Acttmp2_blue, sampling_rate);
                end

            elseif has_combined
                [DF_blue, Raster_blue, Acttmp2_blue, StartEnd_blue] = ...
                    reconstruct_blue_from_combined(data, m);

                if ~isempty(DF_blue) && ~isempty(Raster_blue)
                    [DF_blue, Raster_blue] = align_data(DF_blue, Raster_blue);
                    [num_cells_blue, ~] = size(Raster_blue);

                    freq_blue = compute_frequency_from_raster(Raster_blue, sampling_rate);
                    amp_blue  = compute_normalized_amplitude_per_cell(DF_blue, Acttmp2_blue);
                    dur_cell_blue = extract_mean_duration_per_cell_full(StartEnd_blue, sampling_rate);
                    [iei_mean_blue, ~] = compute_iei_per_cell(Acttmp2_blue, sampling_rate);
                end
            end

            % ==========================================================
            % 3) SCE metrics
            % ==========================================================
            sce_threshold = NaN;
            num_sces = NaN;
            sce_frequency_hz = NaN;
            avg_pourcent_cells_sces = NaN;
            avg_duration_ms = NaN;

            try
                if isfield(data, 'sce_n_cells_threshold') && ...
                   numel(data.sce_n_cells_threshold) >= m && ...
                   ~isempty(data.sce_n_cells_threshold{m})
                    sce_threshold = data.sce_n_cells_threshold{m};
                end

                if isfield(data, 'TRace_gcamp') && ...
                   numel(data.TRace_gcamp) >= m && ...
                   ~isempty(data.TRace_gcamp{m})

                    TRace_gcamp = data.TRace_gcamp{m};
                    TRace_gcamp = TRace_gcamp(:);
                    num_sces = numel(TRace_gcamp);

                    nb_seconds = Nframes / sampling_rate;
                    if nb_seconds > 0
                        sce_frequency_hz = num_sces / nb_seconds;
                    end

                    if isfield(data, 'RasterRace_gcamp') && ...
                       numel(data.RasterRace_gcamp) >= m && ...
                       ~isempty(data.RasterRace_gcamp{m})

                        RasterRace_gcamp = data.RasterRace_gcamp{m};
                        NCell_sce = size(RasterRace_gcamp,1);

                        if NCell_sce > 0 && ~isempty(TRace_gcamp)
                            pourcentageActif = nan(numel(TRace_gcamp),1);

                            valid_TRace = TRace_gcamp(TRace_gcamp >= 1 & TRace_gcamp <= size(RasterRace_gcamp,2));

                            for i = 1:numel(valid_TRace)
                                nbActives = sum(RasterRace_gcamp(:, valid_TRace(i)) == 1);
                                pourcentageActif(i) = 100 * nbActives / NCell_sce;
                            end

                            avg_pourcent_cells_sces = mean(pourcentageActif, 'omitnan');
                        end
                    end

                    if isfield(data, 'sces_distances_gcamp') && ...
                       numel(data.sces_distances_gcamp) >= m && ...
                       ~isempty(data.sces_distances_gcamp{m})

                        sces_distances_gcamp = data.sces_distances_gcamp{m};

                        if size(sces_distances_gcamp,2) >= 2
                            frame_duration_ms = 1000 / sampling_rate;
                            durations_ms = sces_distances_gcamp(:,2) * frame_duration_ms;
                            avg_duration_ms = mean(durations_ms, 'omitnan');
                        end
                    end
                end

            catch
                fprintf('SCEs data missing for rec %d\n', m);
            end

            % ==========================================================
            % Store in results_analysis
            % ==========================================================
            results_analysis(m).NumFrames             = Nframes;
            results_analysis(m).ActiveCellsNumber     = num_cells;
            results_analysis(m).ActiveCellsNumberBlue = num_cells_blue;

            results_analysis(m).FrequencyPerCell_gcamp  = freq_gcamp(:);
            results_analysis(m).AmplitudePerCell_gcamp  = amp_gcamp(:);
            results_analysis(m).DurationPerCell_gcamp_s = dur_cell_gcamp(:);
            results_analysis(m).IEImeanPerCell_gcamp_s  = iei_mean_gcamp(:);

            results_analysis(m).FrequencyPerCell_blue   = freq_blue(:);
            results_analysis(m).AmplitudePerCell_blue   = amp_blue(:);
            results_analysis(m).DurationPerCell_blue_s  = dur_cell_blue(:);
            results_analysis(m).IEImeanPerCell_blue_s   = iei_mean_blue(:);

            results_analysis(m).SCEsThreshold             = sce_threshold;
            results_analysis(m).SCEsNumber                = num_sces;
            results_analysis(m).SCEsFrequencyHz           = sce_frequency_hz;
            results_analysis(m).PercentageActiveCellsSCEs = avg_pourcent_cells_sces;
            results_analysis(m).MeanSCEsduration_ms       = avg_duration_ms;

        catch ME
            fprintf('Error processing rec %d: %s\n', m, ME.message);
        end
    end
end

% =====================================================================
% HELPERS
% =====================================================================

function tf = has_nonempty_plane_field(data, fieldName, m)
    tf = false;

    if ~isfield(data, fieldName)
        return;
    end
    if numel(data.(fieldName)) < m
        return;
    end
    if isempty(data.(fieldName){m})
        return;
    end
    if ~iscell(data.(fieldName){m})
        tf = ~isempty(data.(fieldName){m});
        return;
    end

    planes = data.(fieldName){m};
    for p = 1:numel(planes)
        if ~isempty(planes{p})
            tf = true;
            return;
        end
    end
end

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

function [DF_blue, Raster_blue, Acttmp2_blue, StartEnd_blue] = reconstruct_blue_from_combined(data, m)

    DF_blue = [];
    Raster_blue = [];
    Acttmp2_blue = {};
    StartEnd_blue = {};

    if ~isfield(data, 'DF_combined_by_plane') || numel(data.DF_combined_by_plane) < m || isempty(data.DF_combined_by_plane{m})
        return;
    end
    if ~isfield(data, 'Raster_combined_by_plane') || numel(data.Raster_combined_by_plane) < m || isempty(data.Raster_combined_by_plane{m})
        return;
    end
    if ~isfield(data, 'Acttmp2_combined_by_plane') || numel(data.Acttmp2_combined_by_plane) < m || isempty(data.Acttmp2_combined_by_plane{m})
        return;
    end
    if ~isfield(data, 'StartEnd_combined_by_plane') || numel(data.StartEnd_combined_by_plane) < m || isempty(data.StartEnd_combined_by_plane{m})
        return;
    end
    if ~isfield(data, 'blue_indices_combined_by_plane') || numel(data.blue_indices_combined_by_plane) < m || isempty(data.blue_indices_combined_by_plane{m})
        return;
    end

    DF_planes       = data.DF_combined_by_plane{m};
    Raster_planes   = data.Raster_combined_by_plane{m};
    Acttmp2_planes  = data.Acttmp2_combined_by_plane{m};
    StartEnd_planes = data.StartEnd_combined_by_plane{m};
    blue_idx_planes = data.blue_indices_combined_by_plane{m};

    nPlanes = max([numel(DF_planes), numel(Raster_planes), numel(Acttmp2_planes), ...
                   numel(StartEnd_planes), numel(blue_idx_planes)]);

    for p = 1:nPlanes
        DFp = get_cell_or_empty(DF_planes, p);
        Rp  = get_cell_or_empty(Raster_planes, p);
        Ap  = get_cell_or_empty(Acttmp2_planes, p);
        Sp  = get_cell_or_empty(StartEnd_planes, p);
        Ib  = get_cell_or_empty(blue_idx_planes, p);

        if isempty(Ib)
            continue;
        end

        Ib = Ib(:);
        Ib = Ib(isfinite(Ib));
        Ib = unique(round(Ib));

        if isempty(Ib)
            continue;
        end

        if ~isempty(DFp)
            Ib_df = Ib(Ib >= 1 & Ib <= size(DFp,1));
            DF_blue = [DF_blue; DFp(Ib_df,:)]; %#ok<AGROW>
        end

        if ~isempty(Rp)
            Ib_r = Ib(Ib >= 1 & Ib <= size(Rp,1));
            Raster_blue = [Raster_blue; Rp(Ib_r,:)]; %#ok<AGROW>
        end

        if ~isempty(Ap) && iscell(Ap)
            Ib_a = Ib(Ib >= 1 & Ib <= numel(Ap));
            Acttmp2_blue = [Acttmp2_blue; Ap(Ib_a)]; %#ok<AGROW>
        end

        if ~isempty(Sp) && iscell(Sp)
            Ib_s = Ib(Ib >= 1 & Ib <= numel(Sp));
            StartEnd_blue = [StartEnd_blue; Sp(Ib_s)]; %#ok<AGROW>
        end
    end
end

function v = get_cell_or_empty(C, idx)
    v = [];
    if isempty(C)
        return;
    end
    if ~iscell(C)
        if idx == 1
            v = C;
        end
        return;
    end
    if idx <= numel(C)
        v = C{idx};
    end
end

function [DF, Raster] = align_data(DF, Raster)
    min_cells  = min(size(DF,1), size(Raster,1));
    min_frames = min(size(DF,2), size(Raster,2));
    DF     = DF(1:min_cells, 1:min_frames);
    Raster = Raster(1:min_cells, 1:min_frames);
end

function freq_per_cell_per_min = compute_frequency_from_raster(Raster, sampling_rate)

    if isempty(Raster) || sampling_rate <= 0
        freq_per_cell_per_min = [];
        return;
    end

    Raster = Raster ~= 0;
    [nCells, nFrames] = size(Raster);

    duration_min = (nFrames / sampling_rate) / 60;
    if duration_min <= 0
        freq_per_cell_per_min = nan(nCells,1);
        return;
    end

    nEvents = sum(Raster, 2);
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
        if c > numel(Acttmp2)
            continue;
        end

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

        frames = frames(:);
        frames = frames(frames >= 1 & frames <= nFrames);

        if isempty(frames)
            continue;
        end

        amp(c) = mean(DF(c,frames), 'omitnan');
    end
end

function mean_durations_per_cell = extract_mean_duration_per_cell_full(StartEnd, sampling_rate)

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

    if isempty(Acttmp2)
        iei_mean_per_cell = [];
        iei_all_per_cell  = {};
        return;
    end

    if ~iscell(Acttmp2)
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