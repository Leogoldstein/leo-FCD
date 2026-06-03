function selected_groups = compute_DF(selected_groups)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            fprintf('\n==============================\n');
            fprintf('Compute data\n');
            fprintf('Type: %s\n', current_type);
            fprintf('Animal %d / %d: %s\n', ...
                k, numel(selected_groups.(current_type)), ...
                char(string(selected_groups.(current_type)(k).animal_group)));
            fprintf('==============================\n');

            paths    = selected_groups.(current_type)(k).paths;
            metadata = selected_groups.(current_type)(k).metadata;
            data     = selected_groups.(current_type)(k).data;

            gcamp_root_folders = paths.gcamp_root;
            date_group_paths   = paths.date;
            current_xml_group  = paths.xml;

            current_animal_group = selected_groups.(current_type)(k).animal_group;

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
            % Pairwise correlation
            %======================================================
            data = load_or_process_corr_data( ...
                gcamp_root_folders, ...
                data);

            %======================================================
            % SCEs
            %======================================================
            data = load_or_process_sce_data( ...
                current_animal_group, ...
                date_group_paths, ...
                gcamp_root_folders, ...
                synchronous_frames_group, ...
                data);

            %======================================================
            % Basic metrics
            %======================================================
            results_analysis = compute_export_basic_metrics( ...
                gcamp_root_folders, ...
                date_group_paths, ...
                data, ...
                sampling_rate_group, ...
                current_xml_group);

            %======================================================
            % Save back
            %======================================================
            selected_groups.(current_type)(k).data = data;
            selected_groups.(current_type)(k).results_analysis = results_analysis;
        end
    end
end