function selected_groups = process_selected_groups( ...
        selected_groups, include_electroporated)

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2
        include_electroporated = true;
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};
        numSelectedGroups = ...
            numel(selected_groups.(current_type));

        fprintf('\n');
        fprintf('============================================================\n');
        fprintf('PROCESSING TYPE: %s\n', current_type);
        fprintf('NUMBER OF ANIMALS: %d\n', numSelectedGroups);
        fprintf('============================================================\n');

        %% =========================================================
        % General processing for all animals
        % ==========================================================

        for k = 1:numSelectedGroups

            current_animal = ...
                selected_groups.(current_type)(k).animal;
            
            current_line = ...
                selected_groups.(current_type)(k).line;

            current_dates = ...
                selected_groups.(current_type)(k).dates;

            fprintf('\n');
            fprintf('------------------------------------------------------------\n');
            fprintf('Animal %d/%d\n', k, numSelectedGroups);
            fprintf('Type  : %s\n', current_type);
            fprintf('Animal: %s\n', ...
                char(string(current_animal)));
            fprintf('------------------------------------------------------------\n');

            paths = ...
                selected_groups.(current_type)(k).paths;

            gcamp_output_folders = ...
                paths.gcamp_output;
            
            gcamp_root_folders = ...
                paths.gcamp_root;

            current_ages = ...
                selected_groups.(current_type)(k).ages;

            current_suite2p_group = ...
                paths.suite2p;

            current_TSeries_group = ...
                paths.TSeries;

            date_group_paths = ...
                paths.date;

            data = ...
                selected_groups.(current_type)(k).data;

            metadata = ...
                selected_groups.(current_type)(k).metadata;

            sampling_rate_group = ...
                metadata.gcamp_plane.SamplingRatePlane;

            %% -----------------------------------------------------
            % Mean images
            % ------------------------------------------------------
            
            % ======================================================
            % GCaMP : toujours colonne 1
            % ======================================================
            
            meanImgs_gcamp = save_mean_images( ...
                'GCaMP', ...
                current_animal, ...
                current_ages, ...
                current_dates, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1));
            
            data.gcamp_plane.meanImgs_gcamp = ...
                meanImgs_gcamp;            
            
            % ======================================================
            % Electroporated : choisir automatiquement colonne 2 ou 3
            % ======================================================
            
            electroporated_column = [];
            
            for c = [2 3]
            
                if c > size(current_suite2p_group, 2)
                    continue;
                end
            
                current_column = ...
                    current_suite2p_group(:, c);
            
                has_electroporated_data = ...
                    any(cellfun( ...
                        @(x) ~isempty(x) && ...
                              (~ischar(x) || ~isempty(strtrim(x))), ...
                        current_column));
            
                if has_electroporated_data
            
                    electroporated_column = c;
                    break;
                end
            end
            
            % ======================================================
            % Mean image electroporated
            % ======================================================
            
            if ~isempty(electroporated_column)
            
                if electroporated_column == 2
                    channel_name = 'Red';
                else
                    channel_name = 'Blue';
                end
            
                meanImgs_electroporated = save_mean_images( ...
                    channel_name, ...
                    current_animal, ...
                    current_ages, ...
                    current_dates, ...
                    gcamp_output_folders, ...
                    current_suite2p_group(:, electroporated_column));
            
            else
            
                meanImgs_electroporated = {};
            
            end
            
            data.electroporated_plane.meanImgs_electroporated = ...
                meanImgs_electroporated;
            %% -----------------------------------------------------
            % Motion energy
            % ------------------------------------------------------

            avg_block = 5;

            motion = load_or_process_movie( ...
                current_TSeries_group(:, 1), ...
                gcamp_output_folders, ...
                avg_block, ...
                sampling_rate_group, ...
                current_animal, ...
                data);

            data.motion = motion;

            %% -----------------------------------------------------
            % Whisker stimulation
            % ------------------------------------------------------

            data = load_or_process_stims( ...
                date_group_paths, ...
                current_TSeries_group(:, 1), ...
                data);

            %% -----------------------------------------------------
            % GCaMP cells
            % ------------------------------------------------------

            gcamp_plane = process_gcamp_cells( ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1), ...
                meanImgs_gcamp, ...
                data);

            data.gcamp_plane = ...
                gcamp_plane;

            %% -----------------------------------------------------
            % Save current animal data
            % ------------------------------------------------------

            selected_groups.(current_type)(k).data = ...
                data;
        end

        %% =========================================================
        % Cellpose preparation for all animals
        % ==========================================================
        
        processing_cache = ...
            cell(numSelectedGroups, 1);
        
        for k = 1:numSelectedGroups
        
            current_animal = ...
                selected_groups.(current_type)(k).animal;
        
            current_line = ...
                selected_groups.(current_type)(k).line;

            current_dates = ...
                selected_groups.(current_type)(k).dates;
        
            current_ages = ...
                selected_groups.(current_type)(k).ages;
        
            fprintf('\n');
            fprintf('------------------------------------------------------------\n');
            fprintf('Cellpose preparation\n');
            fprintf('Type  : %s\n', current_type);
            fprintf('Animal: %s (%d/%d)\n', ...
                char(string(current_animal)), ...
                k, ...
                numSelectedGroups);
            fprintf('------------------------------------------------------------\n');
        
            paths = ...
                selected_groups.(current_type)(k).paths;
        
            gcamp_root_folders = ...
                paths.gcamp_root;
        
            data = ...
                selected_groups.(current_type)(k).data;
        
            meanImgs_gcamp = ...
                data.gcamp_plane.meanImgs_gcamp;
        
            [processing_cache{k}, data] = ...
                process_electroporated_pass1( ...
                    paths.gcamp_output, ...
                    include_electroporated, ...
                    paths.date, ...
                    paths.TSeries, ...
                    paths.suite2p, ...
                    metadata, ...
                    data);
                    
            selected_groups.(current_type)(k).data = ...
                data;
        end
        
        %% =========================================================
        % Blue ROI extraction for all animals
        % ==========================================================

        for k = 1:numSelectedGroups

            current_animal = ...
                selected_groups.(current_type)(k).animal;

            fprintf('\n');
            fprintf('------------------------------------------------------------\n');
            fprintf('Electroporated ROI extraction\n');
            fprintf('Type  : %s\n', current_type);
            fprintf('Animal: %s (%d/%d)\n', ...
                char(string(current_animal)), ...
                k, ...
                numSelectedGroups);
            fprintf('------------------------------------------------------------\n');

            paths = ...
                selected_groups.(current_type)(k).paths;

            data = ...
                selected_groups.(current_type)(k).data;

            [electroporated_plane, data] = ...
                process_electroporated_pass2( ...
                    processing_cache{k}, ...
                    paths.gcamp_output, ...
                    data.gcamp_plane.meanImgs_gcamp, ...
                    data);

            data.electroporated_plane = ...
                electroporated_plane;

            %% -----------------------------------------------------
            % Combined GCaMP + electroporated cells
            % ------------------------------------------------------

            combined_plane = ...
                combined_gcamp_electroporated_cells( ...
                    paths.gcamp_output, ...
                    data, ...
                    include_electroporated);

            data.combined_plane = ...
                combined_plane;
    
            %% -----------------------------------------------------
            % Save current animal data
            % ------------------------------------------------------

            selected_groups.(current_type)(k).data = ...
                data;
        end
    end
end