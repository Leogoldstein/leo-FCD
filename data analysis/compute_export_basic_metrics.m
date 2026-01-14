function [results_analysis, plots_data] = compute_export_basic_metrics(selected_groups, k)

    % -------------------------------
    % Infos groupe courant
    % -------------------------------
    current_animal_group     = selected_groups(k).animal_group;
    animal_type              = selected_groups(k).animal_type;
    current_ani_path_group   = selected_groups(k).path;
    current_dates_group      = selected_groups(k).dates;
    current_ages_group       = selected_groups(k).ages;
    gcamp_output_folders     = selected_groups(k).gcamp_output_folders;
    data                     = selected_groups(k).data;
    current_xml_group        = selected_groups(k).xml;

    % Excel path (dossier racine)
    pathexcel = fileparts(fileparts(current_ani_path_group));

    % -------------------------------
    % Schema: ordre champs + headers Excel
    % -------------------------------
    [field_order, excel_headers] = get_results_analysis_schema();

    % -------------------------------
    % Init results_analysis + plots_data
    % -------------------------------
    nRec = numel(gcamp_output_folders);

    results_analysis = repmat( ...
        cell2struct(repmat({[]}, 1, numel(field_order)), field_order, 2), ...
        nRec, 1);

    plots_data = repmat(struct( ...
        'folder_name', [], ...
        'freq_gcamp', [], ...
        'freq_blue', [], ...
        'amp_gcamp', [], ...
        'amp_blue', [], ...
        'dur_non', [], ...
        'dur_ele', []), nRec, 1);

    % -------------------------------
    % Infos enregistrement
    % -------------------------------
    [~, all_optical_zoom, all_position, all_time_minutes] = ...
        find_recording_infos(gcamp_output_folders, current_xml_group); %#ok<ASGLU>

    % Noms de dossiers (fallback)
    if isfield(selected_groups(k), 'gcamp_folders_names') && ~isempty(selected_groups(k).gcamp_folders_names)
        current_gcamp_folders_names_group = selected_groups(k).gcamp_folders_names;
    else
        current_gcamp_folders_names_group = cell(nRec,1);
        for m = 1:nRec
            [~, current_gcamp_folders_names_group{m}] = fileparts(gcamp_output_folders{m});
        end
    end

    % ---------------------------------------------------------------------
    % Boucle principale
    % ---------------------------------------------------------------------
    for m = 1:nRec
        try
            %==========================================================
            % 0) Déterminer COMBINED vs GCaMP-only (BY-PLANE ONLY)
            %==========================================================
            has_combined_by_plane = isfield(data,'DF_combined_by_plane') && ...
                numel(data.DF_combined_by_plane) >= m && ...
                ~isempty(data.DF_combined_by_plane{m});
            use_combined = has_combined_by_plane;

            sampling_rate = data.sampling_rate{m};

            %==========================================================
            % 1) GCaMP : concat tous les plans
            %==========================================================
            DF_gcamp      = concat_planes(data, m, 'DF_gcamp_by_plane');
            Raster_gcamp  = concat_planes(data, m, 'Raster_gcamp_by_plane');
            Acttmp2_gcamp  = concat_acttmp2_planes(data, m, 'Acttmp2_gcamp_by_plane'); % cell par cellule
            StartEnd_gcamp = concat_startend_planes(data, m, 'StartEnd_gcamp_by_plane'); % cell par cellule

            if isempty(DF_gcamp) || isempty(Raster_gcamp)
                warning('Skipping rec %d (%s) — DF/Raster GCaMP vide.', m, gcamp_output_folders{m});
                continue;
            end

            % Vérif dimensions
            [DF_gcamp, Raster_gcamp] = align_data(DF_gcamp, Raster_gcamp);
            [num_cells, Nframes] = size(Raster_gcamp);

            % --- Fréquence GCaMP ---
            freq_gcamp = compute_frequency(Acttmp2_gcamp, Nframes, sampling_rate);
            mean_freq = mean(freq_gcamp, 'omitnan');
            std_freq  = std(freq_gcamp, 'omitnan');

            % --- Amplitude GCaMP ---
            amp_gcamp = compute_normalized_amplitude_per_cell(DF_gcamp, Acttmp2_gcamp);

            % --- Durée moyenne transitoires GCaMP ---
            dur_cell_non = extract_mean_duration_per_cell(StartEnd_gcamp, sampling_rate);

            %==========================================================
            % 2) BLUE : seulement si COMBINED
            %==========================================================
            num_cells_blue = NaN;
            mean_freq_blue = NaN;
            std_freq_blue  = NaN;
            freq_blue = [];
            amp_blue  = [];
            dur_cell_ele = [];

            DF_blue = [];
            Raster_blue = [];
            Acttmp2_blue = [];
            StartEnd_blue = [];

            if use_combined
                % On attend des champs *_blue_by_plane
                DF_blue      = concat_planes(data, m, 'DF_blue_by_plane');
                Raster_blue  = concat_planes(data, m, 'Raster_blue_by_plane');
                Acttmp2_blue = concat_acttmp2_planes(data, m, 'Acttmp2_blue_by_plane');
                StartEnd_blue= concat_startend_planes(data, m, 'StartEnd_blue_by_plane');

                if ~isempty(Raster_blue) && ~isempty(DF_blue)
                    [DF_blue, Raster_blue] = align_data(DF_blue, Raster_blue);
                    [num_cells_blue, Nframes_blue] = size(Raster_blue);

                    freq_blue = compute_frequency(Acttmp2_blue, Nframes_blue, sampling_rate);
                    mean_freq_blue = mean(freq_blue, 'omitnan');
                    std_freq_blue  = std(freq_blue, 'omitnan');

                    amp_blue  = compute_normalized_amplitude_per_cell(DF_blue, Acttmp2_blue);

                    dur_cell_ele = extract_mean_duration_per_cell(StartEnd_blue, sampling_rate);
                end
            end

            %==========================================================
            % 3) Corrélations (BY-PLANE ONLY : utiliser *_by_plane)
            %    Ici tu veux un "mean global" -> max sur plans puis moyenne
            %==========================================================
            mean_corr = NaN;
            mean_corr_blue = NaN;

            if isfield(data,'max_corr_gcamp_gcamp_by_plane') && ...
                    numel(data.max_corr_gcamp_gcamp_by_plane) >= m && ...
                    ~isempty(data.max_corr_gcamp_gcamp_by_plane{m})

                mean_corr = mean_flatten_cellplanes(data.max_corr_gcamp_gcamp_by_plane{m});
            end

            if use_combined && isfield(data,'max_corr_mtor_mtor_by_plane') && ...
                    numel(data.max_corr_mtor_mtor_by_plane) >= m && ...
                    ~isempty(data.max_corr_mtor_mtor_by_plane{m})

                mean_corr_blue = mean_flatten_cellplanes(data.max_corr_mtor_mtor_by_plane{m});
            end

            %==========================================================
            % 4) SCEs (tu as choisi CONCAT ALL PLANES, donc champs globaux)
            %==========================================================
            [num_sces, sce_frequency_hz, avg_pourcent_cells_sces, avg_duration_ms] = ...
                compute_sces_metrics(data, m, sampling_rate);

            % Seuil SCE
            sce_thr = NaN;
            if isfield(data,'sce_n_cells_threshold') && numel(data.sce_n_cells_threshold) >= m && ~isempty(data.sce_n_cells_threshold{m})
                sce_thr = data.sce_n_cells_threshold{m};
            end

            % --- Amplitude moyenne normalisée ---
            mean_peak_amplitude_norm = mean(amp_gcamp, 'omitnan');

            mean_peak_amplitude_norm_blue = NaN;
            if ~isempty(amp_blue)
                mean_peak_amplitude_norm_blue = mean(amp_blue, 'omitnan');
            end

            % --- Fraction d’événements en bursts ---
            P_burst = compute_fraction_bursts(Raster_gcamp);

            P_burst_blue = NaN;
            if ~isempty(Raster_blue)
                P_burst_blue = compute_fraction_bursts(Raster_blue);
            end

            % =======================
            % Stockage résultats
            % =======================
            results_analysis(m).current_animal_group            = current_animal_group;
            results_analysis(m).TseriesFolder                   = current_gcamp_folders_names_group{m};
            results_analysis(m).Age                             = current_ages_group{m};
            results_analysis(m).OpticalZoom                     = all_optical_zoom{m};
            results_analysis(m).Depth_um                        = all_position{m};
            results_analysis(m).RecordingDuration_minutes       = all_time_minutes{m};

            results_analysis(m).NumFrames                       = Nframes;
            results_analysis(m).ActiveCellsNumber               = num_cells;
            results_analysis(m).ActiveCellsNumberBlue           = num_cells_blue;

            results_analysis(m).MeanFrequencyMinutes            = mean_freq;
            results_analysis(m).MeanFrequencyMinutesBlue        = mean_freq_blue;
            results_analysis(m).StdFrequencyMinutes             = std_freq;
            results_analysis(m).StdFrequencyMinutesBlue         = std_freq_blue;

            results_analysis(m).MeanMaxPairwiseCorr             = mean_corr;
            results_analysis(m).MeanMaxPairwiseCorrBlue         = mean_corr_blue;

            results_analysis(m).SCEsThreshold                   = sce_thr;
            results_analysis(m).SCEsNumber                      = num_sces;
            results_analysis(m).SCEsFrequencyHz                 = sce_frequency_hz;
            results_analysis(m).PercentageActiveCellsSCEs       = avg_pourcent_cells_sces;
            results_analysis(m).MeanSCEsduration_ms             = avg_duration_ms;

            results_analysis(m).MeanTranscientAmplitudeNorm     = mean_peak_amplitude_norm;
            results_analysis(m).MeanTranscientAmplitudeNormBlue = mean_peak_amplitude_norm_blue;

            results_analysis(m).FractionEventsBursts            = P_burst;
            results_analysis(m).FractionEventsBurstsBlue        = P_burst_blue;

            % =======================
            % Stockage plots
            % =======================
            plots_data(m).folder_name = current_gcamp_folders_names_group{m};
            plots_data(m).freq_gcamp  = freq_gcamp;
            plots_data(m).freq_blue   = freq_blue;
            plots_data(m).amp_gcamp   = amp_gcamp;
            plots_data(m).amp_blue    = amp_blue;
            plots_data(m).dur_non     = dur_cell_non;
            plots_data(m).dur_ele     = dur_cell_ele;

        catch ME
            fprintf('Error processing group %d: %s\n', m, ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % Écriture Excel (headers humains + ordre stable)
    % ---------------------------------------------------------------------
    all_headers = excel_headers;
    pathexcel_file = fullfile(pathexcel, 'results_basic_metrics.xlsx');

    if isfile(pathexcel_file)
        [~, sheet_names] = xlsfinfo(pathexcel_file);
    else
        sheet_names = {};
    end

    if ~any(strcmp(sheet_names, animal_type))
        writecell(all_headers, pathexcel_file, 'Sheet', animal_type, 'WriteMode', 'overwrite');
        existing_data = [all_headers; cell(0, numel(all_headers))];
    else
        existing_data = readcell(pathexcel_file, 'Sheet', animal_type);
        if isempty(existing_data)
            existing_data = [all_headers; cell(0, numel(all_headers))];
        end
    end

    for m = 1:numel(results_analysis)
        try
            row_to_update = find_row_for_update( ...
                results_analysis(m).current_animal_group, ...
                results_analysis(m).TseriesFolder, ...
                results_analysis(m).Age, ...
                existing_data);

            new_row = results_analysis_to_row(results_analysis(m), field_order);

            if row_to_update ~= -1
                existing_data(row_to_update, :) = new_row;
            else
                existing_data = [existing_data; new_row]; %#ok<AGROW>
            end
        catch ME
            disp(['Error exportation group at index ', num2str(m), ': ', ME.message]);
        end
    end

    existing_data = clean_data(existing_data);
    writecell(existing_data, pathexcel_file, 'Sheet', animal_type, 'WriteMode', 'overwrite');
end

% =====================================================================
% === HELPERS : concat Acttmp2 / StartEnd ==============================
% =====================================================================

function Act_all = concat_acttmp2_planes(data, m, fieldName)
% Concatène Acttmp2_by_plane{m}{p} en une seule cell (une entrée par cellule)
    Act_all = {};
    if ~isfield(data, fieldName) || numel(data.(fieldName)) < m || isempty(data.(fieldName){m})
        return;
    end
    planes = data.(fieldName){m};
    for p = 1:numel(planes)
        A = planes{p};
        if isempty(A), continue; end
        if ~iscell(A)
            % Si jamais c'est une matrice logique/num -> on garde tel quel en bloc
            % mais dans ton pipeline Acttmp2 est généralement une cell.
            A = num2cell(A, 2);
        end
        Act_all = [Act_all; A(:)]; %#ok<AGROW>
    end
end

function SE_all = concat_startend_planes(data, m, fieldName)
% Concatène StartEnd_by_plane{m}{p} en une seule cell (une entrée par cellule)
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

function mval = mean_flatten_cellplanes(cell_by_plane)
% Calcule une moyenne globale d'une mesure stockée par plan (matrice/vecteur)
% cell_by_plane{p} = matrice/vecteur numeric
    vals = [];
    for p = 1:numel(cell_by_plane)
        X = cell_by_plane{p};
        if isempty(X), continue; end
        if isnumeric(X) || islogical(X)
            vals = [vals; X(:)]; %#ok<AGROW>
        end
    end
    if isempty(vals)
        mval = NaN;
    else
        mval = mean(vals, 'omitnan');
    end
end

% =====================================================================
% === SCHEMA EXPORT ====================================================
% =====================================================================

function [field_order, excel_headers] = get_results_analysis_schema()
field_order = { ...
    'current_animal_group', ...
    'TseriesFolder', ...
    'Age', ...
    'OpticalZoom', ...
    'Depth_um', ...
    'RecordingDuration_minutes', ...
    'NumFrames', ...
    'ActiveCellsNumber', ...
    'ActiveCellsNumberBlue', ...
    'MeanFrequencyMinutes', ...
    'MeanFrequencyMinutesBlue', ...
    'StdFrequencyMinutes', ...
    'StdFrequencyMinutesBlue', ...
    'MeanMaxPairwiseCorr', ...
    'MeanMaxPairwiseCorrBlue', ...
    'SCEsThreshold', ...
    'SCEsNumber', ...
    'SCEsFrequencyHz', ...
    'PercentageActiveCellsSCEs', ...
    'MeanSCEsduration_ms', ...
    'MeanTranscientAmplitudeNorm', ...
    'MeanTranscientAmplitudeNormBlue', ...
    'FractionEventsBursts', ...
    'FractionEventsBurstsBlue' ...
};

excel_headers = { ...
    'current_animal_group', ...
    'TseriesFolder', ...
    'Age', ...
    'OpticalZoom', ...
    'Depth_um', ...
    'Recording duration (minutes)', ...
    'Number of frames', ...
    'Number of active cells', ...
    'Number of electroporated active cells', ...
    'Mean frequency (/minutes)', ...
    'Mean frequency of electroporated active cells', ...
    'Std frequency (/minutes)', ...
    'Std frequency of electroporated active cells', ...
    'Mean of maximum pairwise correlation', ...
    'Mean of maximum pairwise correlation of electroporated active cells', ...
    'SCEs threshold', ...
    'SCEs number', ...
    'SCEs frequency (Hz)', ...
    'Percentage of active cells participating in SCEs', ...
    'Mean duration of SCEs (ms)', ...
    'Mean amplitude of calcium transients', ...
    'Mean amplitude of electroporated active cells calcium transients', ...
    'Fraction of events in bursts', ...
    'Fraction of events in bursts (electroporated)' ...
};
end

function row = results_analysis_to_row(s, field_order)
row = cell(1, numel(field_order));
for i = 1:numel(field_order)
    fn = field_order{i};
    if isfield(s, fn)
        row{i} = s.(fn);
    else
        row{i} = [];
    end
end
end

% =====================================================================
% === SOUS-FONCTIONS (tes versions) ====================================
% =====================================================================

function [DF, Raster] = align_data(DF, Raster)
min_cells  = min(size(DF,1), size(Raster,1));
min_frames = min(size(DF,2), size(Raster,2));
DF     = DF(1:min_cells,1:min_frames);
Raster = Raster(1:min_cells,1:min_frames);
end

function freq = compute_frequency(Acttmp2, Nframes, sampling_rate)
if iscell(Acttmp2)
    freq = cellfun(@(x) numel(x)/Nframes*sampling_rate*60, Acttmp2);
elseif isnumeric(Acttmp2)
    if isempty(Acttmp2)
        freq = nan;
    elseif size(Acttmp2,2) == Nframes
        freq = sum(Acttmp2,2)/Nframes*sampling_rate*60;
    else
        freq = nan;
    end
else
    freq = nan;
end
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
        amp(c) = NaN;
        continue;
    end
    amp(c) = mean(DF(c,frames), 'omitnan');
end
end

function mean_durations = extract_mean_duration_per_cell(StartEnd, sampling_rate)
if isempty(StartEnd)
    mean_durations = [];
    return;
end
mean_durations = nan(numel(StartEnd),1);
for c = 1:numel(StartEnd)
    if ~isempty(StartEnd{c})
        intervals = StartEnd{c};
        ev_dur = (intervals(:,2) - intervals(:,1)) / sampling_rate; % seconds
        mean_durations(c) = mean(ev_dur,'omitnan');
    end
end
mean_durations = mean_durations(~isnan(mean_durations));
end

function P_burst = compute_fraction_bursts(Raster)
if isempty(Raster)
    P_burst = NaN;
    return;
end
pop_counts = sum(Raster,1);
g = exp(-((-18:18).^2)/(2*3^2)); g = g/sum(g);
smooth_pop = conv(pop_counts,g,'same');
thr = mean(smooth_pop)+3*std(smooth_pop);
inBurstFrames = smooth_pop>thr;
totalEvents = sum(Raster(:));
if totalEvents > 0
    P_burst = sum(Raster(:,inBurstFrames),'all') / totalEvents;
else
    P_burst = NaN;
end
end

function [num_sces, sce_frequency_hz, avg_pourcent_cells_sces, avg_duration_ms] = ...
    compute_sces_metrics(data, m, sampling_rate)

    % Defaults
    num_sces = NaN;
    sce_frequency_hz = NaN;
    avg_pourcent_cells_sces = NaN;
    avg_duration_ms = NaN;

    try
        % ---- TRace (frames SCE) ----
        if ~isfield(data,'TRace_gcamp') || numel(data.TRace_gcamp) < m || isempty(data.TRace_gcamp{m})
            return;
        end
        TRace = data.TRace_gcamp{m};
        num_sces = numel(TRace);
        if num_sces == 0
            sce_frequency_hz = 0;
            avg_pourcent_cells_sces = NaN;
            avg_duration_ms = NaN;
            return;
        end

        % ---- Raster global (concat local) ----
        Raster = concat_planes(data, m, 'Raster_gcamp_by_plane');

        if isempty(Raster)
            return;
        end

        % IMPORTANT : durée = nb_frames / sampling_rate
        Nframes = size(Raster, 2);
        nb_seconds = Nframes / sampling_rate;

        % ---- fréquence SCE (Hz) ----
        sce_frequency_hz = num_sces / nb_seconds;

        % ---- % cellules actives participant (à partir de RasterRace) ----
        if isfield(data,'RasterRace_gcamp') && numel(data.RasterRace_gcamp) >= m && ~isempty(data.RasterRace_gcamp{m})
            RasterRace = data.RasterRace_gcamp{m};
            NCell = size(RasterRace, 1);

            pourcentageActif = nan(num_sces,1);
            for i = 1:num_sces
                f = TRace(i);
                if f >= 1 && f <= size(RasterRace,2)
                    nbActives = sum(RasterRace(:, f) ~= 0);
                    pourcentageActif(i) = 100 * nbActives / NCell;
                end
            end
            avg_pourcent_cells_sces = mean(pourcentageActif, 'omitnan');
        end

        % ---- durée moyenne SCE (ms) ----
        if isfield(data,'sces_distances_gcamp') && numel(data.sces_distances_gcamp) >= m && ~isempty(data.sces_distances_gcamp{m})
            sces_distances = data.sces_distances_gcamp{m};
            frame_duration_ms = 1000 / sampling_rate;

            % sces_distances(:,2) = durée en frames (selon ton code)
            durations_ms = sces_distances(:,2) * frame_duration_ms;
            avg_duration_ms = mean(durations_ms, 'omitnan');
        end

    catch ME
        % Au lieu de tout masquer (sinon tu ne vois jamais l’erreur)
        warning('compute_sces_metrics session %d: %s', m, ME.message);
    end
end


function row = find_row_for_update(current_animal_group, tseries_folder, age, existing_data)
row = -1;
for i = 2:size(existing_data, 1)
    if isequal(existing_data{i, 1}, current_animal_group) && ...
       isequal(existing_data{i, 2}, tseries_folder) && ...
       isequal(existing_data{i, 3}, age)
        row = i;
        return;
    end
end
end

function cleaned_data = clean_data(data)
for i = 1:size(data, 1)
    for j = 1:size(data, 2)
        if ismissing(data{i, j})
            data{i, j} = '';
        end
    end
end
cleaned_data = data;
end
