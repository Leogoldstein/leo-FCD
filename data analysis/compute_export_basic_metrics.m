function compute_export_basic_metrics(current_animal_group, data, gcamp_output_folders, current_env_group, current_gcamp_folders_names_group, current_ages_group, pathexcel, animal_type, daytime)

    % ---------------------------------------------------------------------
    % Initialisation de la structure de sortie (ajout Daytime)
    results_analysis = struct(...
        'current_animal_group', [], ...
        'TseriesFolder', [], ...
        'Age', [], ...
        'Daytime', [], ...  % <-- NOUVELLE COLONNE
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
        'MeanSCEsduration_ms', []);

    % ---------------------------------------------------------------------
    % Récupération infos enregistrement
    [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(gcamp_output_folders, current_env_group);

    % ---------------------------------------------------------------------
    % Boucle sur les groupes
    for m = 1:length(gcamp_output_folders)
        try
            % Extraction des données gcamp
            DF_gcamp = data.DF_gcamp{m};
            Acttmp2_gcamp = data.Acttmp2_gcamp{m};
            Raster_gcamp = data.Raster_gcamp{m};
            sampling_rate = data.sampling_rate{m};

            % Vérification dimensions
            if size(DF_gcamp,1) ~= size(Raster_gcamp,1)
                warning('Mismatch in neurons count (group %d). Adjusting.', m);
                min_cells = min(size(DF_gcamp,1), size(Raster_gcamp,1));
                DF_gcamp = DF_gcamp(1:min_cells,:);
                Raster_gcamp = Raster_gcamp(1:min_cells,:);
            end
            if size(DF_gcamp,2) ~= size(Raster_gcamp,2)
                warning('Mismatch in frames count (group %d). Adjusting.', m);
                min_frames = min(size(DF_gcamp,2), size(Raster_gcamp,2));
                DF_gcamp = DF_gcamp(:,1:min_frames);
                Raster_gcamp = Raster_gcamp(:,1:min_frames);
            end

            % Nombre de neurones
            [num_cells, Nframes] = size(Raster_gcamp);

            % Fréquences gcamp
            frequency_per_minute = zeros(1, num_cells);
            for i = 1:num_cells
                frequency_per_minute(i) = numel(Acttmp2_gcamp{i}) / Nframes * sampling_rate * 60;
            end
            mean_freq = mean(frequency_per_minute,'omitnan');
            std_freq = std(frequency_per_minute,'omitnan');

            % Canal bleu
            num_cells_blue = NaN;
            mean_freq_blue = NaN;
            std_freq_blue = NaN;
            if isfield(data,'Raster_blue') && ~isempty(data.Raster_blue{m})
                Raster_blue = data.Raster_blue{m};
                Acttmp2_blue = data.Acttmp2_blue{m};

                [num_cells_blue, Nframes] = size(Raster_blue);
                freq_minute_blue = zeros(1, num_cells_blue);
                for i = 1:num_cells_blue
                    freq_minute_blue(i) = numel(Acttmp2_blue{i}) / Nframes * sampling_rate * 60;
                end
                mean_freq_blue = mean(freq_minute_blue,'omitnan');
                std_freq_blue = std(freq_minute_blue,'omitnan');
            end

            % Corrélations
            mean_corr = NaN; 
            mean_corr_blue = NaN; 
            if isfield(data,'max_corr_gcamp_gcamp') && ~isempty(data.max_corr_gcamp_gcamp{m})
                mean_corr = mean(mean(data.max_corr_gcamp_gcamp{m},'omitnan'));
            end
            if isfield(data,'max_corr_mtor_mtor') && ~isempty(data.max_corr_mtor_mtor{m})
                mean_corr_blue = mean(mean(data.max_corr_mtor_mtor{m},'omitnan'));
            end

            % SCEs metrics
            num_sces = NaN; sce_frequency_hz = NaN;
            avg_pourcent_cells_sces = NaN; avg_duration_ms = NaN;
            try
                TRace_gcamp = data.TRace_gcamp{m}; 
                TRace_gcamp = TRace_gcamp(:);
                num_sces = numel(TRace_gcamp);

                Raster_gcamp = data.Raster_gcamp{m};
                nb_seconds = numel(Raster_gcamp) / sampling_rate;
                sce_frequency_hz = num_sces / nb_seconds;

                RasterRace_gcamp = data.RasterRace_gcamp{m};
                NCell = size(RasterRace_gcamp,1);
                pourcentageActif = zeros(length(TRace_gcamp),1);
                for i = 1:length(TRace_gcamp)
                    nbActives = sum(RasterRace_gcamp(:,TRace_gcamp(i)) == 1);
                    pourcentageActif(i) = 100 * nbActives / NCell;
                end
                avg_pourcent_cells_sces = mean(pourcentageActif);

                sces_distances_gcamp = data.sces_distances_gcamp{m};
                frame_duration_ms = 1000 / sampling_rate;
                durations_ms = sces_distances_gcamp(:,2) * frame_duration_ms;
                avg_duration_ms = mean(durations_ms,'omitnan');
            catch
                fprintf('SCEs data missing for group %d\n',m);
            end

            % Stockage
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

        catch ME
            fprintf('Error processing group %d: %s\n', m, ME.message);
        end
    end

    % ---------------------------------------------------------------------
    % Écriture dans Excel
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
