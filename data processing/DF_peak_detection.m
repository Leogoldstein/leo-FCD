function selected_groups = DF_peak_detection(selected_groups)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            fprintf('\n==============================\n');
            fprintf('DF peak detection\n');
            fprintf('Type: %s\n', current_type);
            fprintf('Animal %d / %d: %s\n', ...
                k, numel(selected_groups.(current_type)), ...
                char(string(selected_groups.(current_type)(k).animal_group)));
            fprintf('==============================\n');

            paths = selected_groups.(current_type)(k).paths;

            gcamp_root_folders   = paths.gcamp_root;
            gcamp_output_folders = paths.gcamp_output;

            current_animal_group = selected_groups.(current_type)(k).animal_group;
            current_ages_group   = selected_groups.(current_type)(k).ages;

            current_suite2p_group = paths.suite2p;
            current_TSeries_group = paths.TSeries;

            metadata = selected_groups.(current_type)(k).metadata;
            data     = selected_groups.(current_type)(k).data;

            animal_path = '';

            if isfield(paths,'date') && ~isempty(paths.date)
            
                if iscell(paths.date)
                    animal_path = fileparts(paths.date{1});
                else
                    animal_path = fileparts(paths.date);
                end
            
            end

            %======================================================
            % Sampling rate + synchronous frames depuis metadata
            %======================================================
            sampling_rate_group = metadata.SamplingRatePlane;

            synchronous_frames_group = cell(size(sampling_rate_group));
            
            for m = 1:numel(sampling_rate_group)
                synchronous_frames_group{m} = ...
                    round(0.2 * sampling_rate_group{m});
            end

            %======================================================
            % Mean images
            %======================================================
            meanImgs_gcamp = save_mean_images( ...
                'GCaMP', ...
                current_animal_group, ...
                current_ages_group, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1));

            data.meanImgs_gcamp = meanImgs_gcamp;

            %======================================================
            % DF processing and peak detection
            %======================================================
            data = run_gcamp_peak_detection( ...
                gcamp_output_folders, ...
                metadata, ...
                sampling_rate_group, ...
                synchronous_frames_group, ...
                data, ...
                meanImgs_gcamp, ...
                current_TSeries_group(:, 1), ...
                current_animal_group);

            selected_groups.(current_type)(k).data = data;

            %======================================================
            % Rasterplots
            %======================================================
            build_rasterplot_DF( ...
                data, ...
                gcamp_output_folders, ...
                gcamp_root_folders, ...
                animal_path, ...
                current_animal_group, ...
                current_ages_group, ...
                sampling_rate_group);

            build_rasterplot_peaks( ...
                data, ...
                gcamp_output_folders, ...
                gcamp_root_folders, ...
                animal_path, ...
                current_animal_group, ...
                current_ages_group, ...
                sampling_rate_group);
        end
    end
end