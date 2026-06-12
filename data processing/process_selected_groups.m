function selected_groups = process_selected_groups(selected_groups, include_blue_cells)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2
        include_blue_cells = true;
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            fprintf('\n==============================\n');
            fprintf('Process selected group\n');
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
            current_xml_group     = paths.xml;
            date_group_paths      = paths.date;

            data = selected_groups.(current_type)(k).data;

            %======================================================
            % Sampling rate + synchronous frames depuis metadata
            %======================================================
            metadata = selected_groups.(current_type)(k).metadata;
            
            sampling_rate_group = metadata.SamplingRatePlane;
            
            %======================================================
            % Mean images
            %======================================================
            meanImgs_gcamp = save_mean_images( ...
                'GCaMP', ...
                current_animal_group, ...
                current_ages_group, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1));

            meanImgs_blue = save_mean_images( ...
                'Electroporated', ...
                current_animal_group, ...
                current_ages_group, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 3));

            data.meanImgs_gcamp = meanImgs_gcamp;
            data.meanImgs_blue  = meanImgs_blue;

            %======================================================
            % Motion energy
            %======================================================
            avg_block = 5;

            motion = load_or_process_movie( ...
                current_TSeries_group(:, 1), ...
                gcamp_output_folders, ...
                avg_block, ...
                sampling_rate_group, ...
                current_animal_group, ...
                data);

            data.motion = motion;

            %======================================================
            % Whisker stims
            %======================================================
            data = load_or_process_stims( ...
                date_group_paths, ...
                current_TSeries_group(:, 1), ...
                data);

            %======================================================
            % GCaMP cells
            %======================================================
            gcamp_plane = process_gcamp_cells( ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1), ...
                meanImgs_gcamp, ...
                data);

            data.gcamp_plane = gcamp_plane;

            %======================================================
            % Blue cells
            %======================================================
            blue_plane = process_blue_cells( ...
                gcamp_output_folders, ...
                include_blue_cells, ...
                date_group_paths, ...
                current_TSeries_group(:, 3), ...
                current_suite2p_group(:, 1), ...
                current_suite2p_group(:, 2), ...
                current_suite2p_group(:, 3), ...
                current_suite2p_group(:, 4), ...
                meanImgs_gcamp, ...
                data);

            data.blue_plane = blue_plane;

            %======================================================
            % Combined GCaMP + blue
            %======================================================
            combined_plane = combined_gcamp_blue_cells( ...
                gcamp_output_folders, ...
                data);

            data.combined_plane = combined_plane;

            %======================================================
            % Save back
            %======================================================
            selected_groups.(current_type)(k).data = data;
        end
    end
end