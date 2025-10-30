function results_analysis = compute_export_basic_metrics(current_animal_group, data, gcamp_output_folders, current_env_group, current_gcamp_folders_names_group, current_ages_group, pathexcel, animal_type, daytime)

    % ---------------------------------------------------------------------
    % Initialisation de la structure de sortie
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
        'MeanTranscientAmplitudeNorm', [], ...
        'MeanTranscientAmplitudeNormBlue', [], ...
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

            % --- Fréquence GCaMP ---
            freq = compute_frequency(Acttmp2_gcamp, Nframes, sampling_rate);
            mean_freq = mean(freq, 'omitnan');
            std_freq  = std(freq, 'omitnan');

            amp_gcamp = compute_normalized_amplitude_per_cell(DF_gcamp, Acttmp2_gcamp);

            % --- Données BLUE ---
            num_cells_blue = NaN;
            mean_freq_blue = NaN;
            std_freq_blue  = NaN;
            freq_blue = [];

            if isfield(data, 'Raster_blue') && ~isempty(data.Raster_blue{m})
                DF_blue      = data.DF_blue{m};
                Raster_blue  = data.Raster_blue{m};
                Acttmp2_blue = data.Acttmp2_blue{m};
                [DF_blue, Raster_blue] = align_data(DF_blue, Raster_blue);
                [num_cells_blue, Nframes_blue] = size(Raster_blue);

                freq_blue = compute_frequency(Acttmp2_blue, Nframes_blue, sampling_rate);
                mean_freq_blue = mean(freq_blue, 'omitnan');
                std_freq_blue  = std(freq_blue, 'omitnan');
                
                amp_blue  = compute_normalized_amplitude_per_cell(DF_blue, Acttmp2_blue);
            end

            plot_frequency_scatter(freq, freq_blue, current_gcamp_folders_names_group{m}, gcamp_output_folders{m});
            plot_amplitude_scatter(amp_gcamp, amp_blue, current_gcamp_folders_names_group{m}, gcamp_output_folders{m});

            % --- Mean transient duration per cell --- %
            dur_cell_non = extract_mean_duration_per_cell(data.StartEnd_gcamp{m}, sampling_rate);
            dur_cell_ele = [];
            if isfield(data,'StartEnd_blue') && ~isempty(data.StartEnd_blue{m})
                dur_cell_ele = extract_mean_duration_per_cell(data.StartEnd_blue{m}, sampling_rate);
            end
            
            if ~isempty(dur_cell_non) || ~isempty(dur_cell_ele)
                plot_duration_per_cell_boxplot(dur_cell_non, dur_cell_ele, current_gcamp_folders_names_group{m});
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

            % --- Amplitude moyenne normalisée des pics (ΔF/F₀) ---
            mean_peak_amplitude_norm = mean(amp_gcamp, 'omitnan');

            mean_peak_amplitude_norm_blue = NaN;
            if isfield(data,'DF_blue') && ~isempty(data.DF_blue{m})
                mean_peak_amplitude_norm_blue = mean(amp_blue, 'omitnan');
            end

            % --- Fraction d’événements en bursts ---
            P_burst = compute_fraction_bursts(Raster_gcamp);
            P_burst_blue = NaN;
            if isfield(data,'Raster_blue') && ~isempty(data.Raster_blue{m})
                P_burst_blue = compute_fraction_bursts(data.Raster_blue{m});
            end

            % --- Enregistrement des résultats ---
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
            results_analysis(m).MeanTranscientAmplitudeNorm    = mean_peak_amplitude_norm;
            results_analysis(m).MeanTranscientAmplitudeNormBlue= mean_peak_amplitude_norm_blue;
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


function plot_frequency_scatter(freq_non, freq_ele, folder_name, output_path)

freq_non = freq_non(~isnan(freq_non));
freq_ele = freq_ele(~isnan(freq_ele));

if isempty(freq_non) && isempty(freq_ele)
    return;
end

% Positions centrées
pos_non = -0.2;
pos_ele =  0.2;

data = [freq_non; freq_ele];
group = [ones(size(freq_non)); 2*ones(size(freq_ele))];

fig = figure('Name', ['Frequency - ' folder_name], 'Color','w'); hold on;

% Boxplots centrés
boxplot(data, group, 'Positions', [pos_non pos_ele], ...
        'Labels', {'Non-electroporated','Electroporated'}, ...
        'Colors', 'k')

% Jitter points
scatter(pos_non + randn(size(freq_non))*0.02, freq_non, 25, [0 0.7 0], 'filled')
scatter(pos_ele + randn(size(freq_ele))*0.02, freq_ele, 25, [0 0 1], 'filled')

ylabel('Frequency (events/min)')
title(['Activity distribution - ' folder_name], 'Interpreter','none')
xlim([-0.5 0.5])
grid on; box on;
hold off;

end


function amp = compute_normalized_amplitude_per_cell(DF, Acttmp2)
% Compute peak ΔF/F amplitude per cell
% Works for logical matrices or cell arrays of event indices

if isempty(DF) || isempty(Acttmp2)
    amp = NaN(size(DF,1),1);
    return;
end

[nCells, nFrames] = size(DF);
amp = nan(nCells,1);

for c = 1:nCells

    % --- Récupérer les frames de pics ---
    if iscell(Acttmp2)
        frames = Acttmp2{c};
    elseif isnumeric(Acttmp2) && size(Acttmp2,2) == nFrames
        frames = find(Acttmp2(c,:) > 0);
    else
        frames = [];
    end

    % --- Si pas de pics -> NaN ---
    if isempty(frames)
        amp(c) = NaN;
        continue;
    end

    % --- Moyenne des amplitudes ΔF/F pendant les pics ---
    amp(c) = mean(DF(c,frames), 'omitnan');
end

end

function plot_amplitude_scatter(amp_non, amp_ele, folder_name, output_path)

amp_non = amp_non(~isnan(amp_non));
amp_ele = amp_ele(~isnan(amp_ele));

if isempty(amp_non) && isempty(amp_ele)
    return;
end

pos_non = -0.2;
pos_ele =  0.2;

data = [amp_non; amp_ele];
group = [ones(size(amp_non)); 2*ones(size(amp_ele))];

fig = figure('Name', ['Amplitude - ' folder_name], 'Color','w'); hold on;

boxplot(data, group, 'Positions', [pos_non pos_ele], ...
        'Labels', {'Non-electroporated','Electroporated'}, ...
        'Colors', 'k')

scatter(pos_non + randn(size(amp_non))*0.02, amp_non, 25, [0 0.7 0], 'filled')
scatter(pos_ele + randn(size(amp_ele))*0.02, amp_ele, 25, [0  0  1], 'filled')

ylabel('Transicents ΔF/F amplitude')
title(['Transcient amplitudes - ' folder_name], 'Interpreter','none')
xlim([-0.5 0.5])
grid on; box on;
hold off;

end

function mean_durations = extract_mean_duration_per_cell(StartEnd, sampling_rate)
% StartEnd : cell array, each entry is [n_events × 2]
% Output: mean duration per cell, in ms

if isempty(StartEnd)
    mean_durations = [];
    return;
end

mean_durations = nan(numel(StartEnd),1);

for c = 1:numel(StartEnd)
    if ~isempty(StartEnd{c})
        intervals = StartEnd{c};
        % Frame → s
        ev_dur = (intervals(:,2) - intervals(:,1)) / sampling_rate;
        mean_durations(c) = mean(ev_dur,'omitnan');
    end
end

% Retire les NaN si aucune détection
mean_durations = mean_durations(~isnan(mean_durations));
end

function plot_duration_per_cell_boxplot(dur_non, dur_ele, folder_name)

dur_non = dur_non(~isnan(dur_non));
dur_ele = dur_ele(~isnan(dur_ele));

if isempty(dur_non) && isempty(dur_ele)
    return;
end

pos_non = -0.2;
pos_ele =  0.2;

data  = [dur_non; dur_ele];
group = [ones(size(dur_non)); 2*ones(size(dur_ele))];

fig = figure('Name', ['Mean duration per cell - ' folder_name], 'Color','w'); hold on;

% Boxplots
boxplot(data, group, 'Positions', [pos_non pos_ele], ...
    'Labels', {'Non-electroporated','Electroporated'}, ...
    'Colors', 'k');

% Jitter scatter
scatter(pos_non + randn(size(dur_non))*0.02, dur_non, 30, [0 0.7 0], 'filled')
scatter(pos_ele + randn(size(dur_ele))*0.02, dur_ele, 30, [0 0 1], 'filled')

ylabel('Mean transient duration per cell (sec)')
title(['Mean transient duration per cell - ' folder_name], 'Interpreter','none')
xlim([-0.5 0.5])
grid on; box on;
hold off;
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

