function results_analysis = compute_export_basic_metrics(current_animal_group, data, gcamp_output_folders, current_env_group, current_gcamp_folders_names_group, current_ages_group, pathexcel, animal_type, daytime)

    % ---------------------------------------------------------------------
    % Initialisation de la structure de sortie (ajout Daytime + nouveautés)
    results_analysis = struct( ...
        'current_animal_group', [], ...
        'TseriesFolder', [], ...
        'Age', [], ...
        'Daytime', [], ...
        'RecordingTime', [], ...
        'OpticalZoom', [], ...
        'Depth_um', [], ...
        'RecordingDuration_minutes', [], ...
        'NumFrames', [], ...
        'ActiveCellsNumber', [], ...
        'ActiveCellsNumberBlue', [], ...
        'MeanFrequencyMinutes', [], ...
        'MeanFrequencyMinutesBlue', [], ...
        'StdFrequencyMinutes', [], ...
        'StdFrequencyMinutesBlue', [], ...
        'MeanMaxPairwiseCorr', [], ...
        'MeanMaxPairwiseCorrBlue', [], ...
        'SCEsThreshold', [], ...
        'SCEsNumber', [], ...
        'SCEsFrequencyHz', [], ...
        'PercentageActiveCellsSCEs', [], ...
        'MeanSCEsduration_ms', [], ...
        'MeanPeakAmplitudeNorm', [], ...
        'MeanPeakAmplitudeNormBlue', [], ...
        'FractionEventsBursts', [], ...
        'FractionEventsBurstsBlue', [] ...
    );

    % ---------------------------------------------------------------------
    % Infos enregistrement
    [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = ...
        find_recording_infos(gcamp_output_folders, current_env_group);

    % ---------------------------------------------------------------------
    % Boucle principale
    for m = 1:length(gcamp_output_folders)
        try
            % --- Données GCaMP ---
            DF_gcamp      = data.DF_gcamp{m};
            Acttmp2_gcamp = data.Acttmp2_gcamp{m};
            Raster_gcamp  = data.Raster_gcamp{m};
            sampling_rate = data.sampling_rate{m};

            % Vérif dimensions
            [DF_gcamp, Raster_gcamp] = align_data(DF_gcamp, Raster_gcamp);
            [num_cells, Nframes] = size(Raster_gcamp);

            % --- Fréquence ---
            freq = compute_frequency(Acttmp2_gcamp, Nframes, sampling_rate);
            mean_freq = mean(freq, 'omitnan');
            std_freq  = std(freq, 'omitnan');

            % --- Données BLUE ---
            num_cells_blue = NaN;
            mean_freq_blue = NaN;
            std_freq_blue  = NaN;
            if isfield(data, 'Raster_blue') && ~isempty(data.Raster_blue{m})
                DF_blue      = data.DF_blue{m};
                Raster_blue  = data.Raster_blue{m};
                Acttmp2_blue = data.Acttmp2_blue{m};
                [DF_blue, Raster_blue] = align_data(DF_blue, Raster_blue);
                [num_cells_blue, Nframes_blue] = size(Raster_blue);

                freq_blue = compute_frequency(Acttmp2_blue, Nframes_blue, sampling_rate);
                mean_freq_blue = mean(freq_blue, 'omitnan');
                std_freq_blue  = std(freq_blue, 'omitnan');
            end

            % --- Corrélations ---
            mean_corr = NaN;
            mean_corr_blue = NaN;
            if isfield(data,'max_corr_gcamp_gcamp') && ~isempty(data.max_corr_gcamp_gcamp{m})
                mean_corr = mean(mean(data.max_corr_gcamp_gcamp{m},'omitnan'));
            end
            if isfield(data,'max_corr_mtor_mtor') && ~isempty(data.max_corr_mtor_mtor{m})
                mean_corr_blue = mean(mean(data.max_corr_mtor_mtor{m},'omitnan'));
            end

            % --- SCEs ---
            [num_sces, sce_frequency_hz, avg_pourcent_cells_sces, avg_duration_ms] = ...
                compute_sces_metrics(data, m, sampling_rate);

            %%% ============================================================
            %%% NEW 1 : Amplitude moyenne normalisée des pics (ΔF/F₀)
            %%% ============================================================
            mean_peak_amplitude_norm = compute_normalized_amplitude( ...
                DF_gcamp, Acttmp2_gcamp, data, m, 'gcamp');

            mean_peak_amplitude_norm_blue = NaN;
            if isfield(data,'DF_blue') && ~isempty(data.DF_blue{m})
                mean_peak_amplitude_norm_blue = compute_normalized_amplitude( ...
                    data.DF_blue{m}, data.Acttmp2_blue{m}, data, m, 'blue');
            end

            %%% ============================================================
            %%% NEW 2 : Fraction d’événements en bursts (P_burst)
            %%% ============================================================
            P_burst = compute_fraction_bursts(Raster_gcamp);
            P_burst_blue = NaN;
            if isfield(data,'Raster_blue') && ~isempty(data.Raster_blue{m})
                P_burst_blue = compute_fraction_bursts(data.Raster_blue{m});
            end

            %%% ============================================================
            %%% Enregistrement
            %%% ============================================================
            results_analysis(m).current_animal_group     = current_animal_group;
            results_analysis(m).TseriesFolder            = current_gcamp_folders_names_group{m};
            results_analysis(m).Age                      = current_ages_group{m};
            results_analysis(m).Daytime                  = daytime;
            results_analysis(m).RecordingTime            = all_recording_time{m};
            results_analysis(m).OpticalZoom              = all_optical_zoom{m};
            results_analysis(m).Depth_um                 = all_position{m};
            results_analysis(m).RecordingDuration_minutes= all_time_minutes{m};
            results_analysis(m).NumFrames                = Nframes;
            results_analysis(m).ActiveCellsNumber        = num_cells;
            results_analysis(m).ActiveCellsNumberBlue    = num_cells_blue;
            results_analysis(m).MeanFrequencyMinutes     = mean_freq;
            results_analysis(m).MeanFrequencyMinutesBlue = mean_freq_blue;
            results_analysis(m).StdFrequencyMinutes      = std_freq;
            results_analysis(m).StdFrequencyMinutesBlue  = std_freq_blue;
            results_analysis(m).MeanMaxPairwiseCorr      = mean_corr;
            results_analysis(m).MeanMaxPairwiseCorrBlue  = mean_corr_blue;
            results_analysis(m).SCEsThreshold            = data.sce_n_cells_threshold{m};
            results_analysis(m).SCEsNumber               = num_sces;
            results_analysis(m).SCEsFrequencyHz          = sce_frequency_hz;
            results_analysis(m).PercentageActiveCellsSCEs= avg_pourcent_cells_sces;
            results_analysis(m).MeanSCEsduration_ms      = avg_duration_ms;
            %%% NEW METRICS
            results_analysis(m).MeanPeakAmplitudeNorm    = mean_peak_amplitude_norm;
            results_analysis(m).MeanPeakAmplitudeNormBlue= mean_peak_amplitude_norm_blue;
            results_analysis(m).FractionEventsBursts     = P_burst;
            results_analysis(m).FractionEventsBurstsBlue = P_burst_blue;

        catch ME
            fprintf('Error processing group %d: %s\n', m, ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % Écriture Excel
    all_headers = fieldnames(results_analysis)';  
    if isfile(pathexcel)
        [~, sheet_names] = xlsfinfo(pathexcel);
    else
        sheet_names = {};
    end

    if ~any(strcmp(sheet_names, animal_type))
        writecell(all_headers, pathexcel, 'Sheet', animal_type, 'WriteMode', 'overwrite');
        existing_data = [all_headers; cell(0, numel(all_headers))];
    else
        existing_data = readcell(pathexcel, 'Sheet', animal_type);
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

            new_row = struct2cell(results_analysis(m))';

            if row_to_update ~= -1
                existing_data(row_to_update, :) = new_row;
            else
                existing_data = [existing_data; new_row];
            end
        catch ME
            disp(['Error exportation group at index ', num2str(m), ': ', ME.message]);
        end
    end

    existing_data = clean_data(existing_data);
    writecell(existing_data, pathexcel, 'Sheet', animal_type, 'WriteMode', 'overwrite');
end

% =====================================================================
% === SOUS-FONCTIONS ==================================================
% =====================================================================

function [DF, Raster] = align_data(DF, Raster)
    min_cells = min(size(DF,1), size(Raster,1));
    min_frames = min(size(DF,2), size(Raster,2));
    DF = DF(1:min_cells,1:min_frames);
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

function mean_peak_amplitude = compute_normalized_amplitude(DF, Acttmp2, data, m, channel)
    % Calcule la moyenne d'amplitude des pics (ΔF/F), sans normalisation par baseline.
    %
    % Entrées :
    %   DF : matrice ΔF/F (neurones x frames)
    %   Acttmp2 : indices de pics (cell array ou matrice logique)
    %   data, m, channel : conservés pour compatibilité
    %
    % Sortie :
    %   mean_peak_amplitude : moyenne des amplitudes pendant les frames d'activité

    if isempty(DF) || isempty(Acttmp2)
        mean_peak_amplitude = NaN;
        return;
    end

    % Convertir les indices de pics si nécessaire
    if iscell(Acttmp2)
        peak_frames = unique(cell2mat(Acttmp2(:)'));
    elseif isnumeric(Acttmp2) && any(Acttmp2(:))
        % Cas binaire ou logique
        if size(Acttmp2,2) == size(DF,2)
            peak_frames = find(any(Acttmp2,1));
        else
            peak_frames = Acttmp2(:)';
        end
    else
        mean_peak_amplitude = NaN;
        return;
    end

    % Vérifier la validité
    if isempty(peak_frames) || max(peak_frames) > size(DF,2)
        mean_peak_amplitude = NaN;
        return;
    end

    % Moyenne de DF pendant les frames de pics
    mean_peak_F = mean(DF(:, peak_frames), 2, 'omitnan');

    % Moyenne globale sur tous les neurones
    mean_peak_amplitude = mean(mean_peak_F, 'omitnan');
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

function [num_sces, sce_frequency_hz, avg_pourcent_cells_sces, avg_duration_ms] = compute_sces_metrics(data, m, sampling_rate)
    num_sces = NaN; sce_frequency_hz = NaN; avg_pourcent_cells_sces = NaN; avg_duration_ms = NaN;
    try
        TRace = data.TRace_gcamp{m};
        Raster = data.Raster_gcamp{m};
        nb_seconds = numel(Raster) / sampling_rate;
        num_sces = numel(TRace);
        sce_frequency_hz = num_sces / nb_seconds;
        RasterRace = data.RasterRace_gcamp{m};
        NCell = size(RasterRace,1);
        pourcentageActif = zeros(length(TRace),1);
        for i = 1:length(TRace)
            nbActives = sum(RasterRace(:,TRace(i)) == 1);
            pourcentageActif(i) = 100 * nbActives / NCell;
        end
        avg_pourcent_cells_sces = mean(pourcentageActif);
        sces_distances = data.sces_distances_gcamp{m};
        frame_duration_ms = 1000 / sampling_rate;
        durations_ms = sces_distances(:,2) * frame_duration_ms;
        avg_duration_ms = mean(durations_ms,'omitnan');
    catch
        % ignore missing SCEs data
    end
end

% -------------------------------------------------------------------------
function row = find_row_for_update(current_animal_group, tseries_folder, age, existing_data)
    row = -1;
    for i = 2:size(existing_data, 1) % Ignorer la ligne des en-têtes
        if isequal(existing_data{i, 1}, current_animal_group) && ...
           isequal(existing_data{i, 2}, tseries_folder) && ...
           isequal(existing_data{i, 3}, age)
            row = i;
            return;
        end
    end
end

% -------------------------------------------------------------------------
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

