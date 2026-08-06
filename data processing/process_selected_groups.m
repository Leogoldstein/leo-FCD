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
                metadata.SamplingRatePlane;

            %% -----------------------------------------------------
            % Mean images
            % ------------------------------------------------------

            meanImgs_gcamp = save_mean_images( ...
                'GCaMP', ...
                current_animal, ...
                current_ages, ...
                current_dates, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1));

            meanImgs_red = save_mean_images( ...
                'Red', ...
                current_animal, ...
                current_ages, ...
                current_dates, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 1));

            meanImgs_blue = save_mean_images( ...
                'Blue', ...
                current_animal, ...
                current_ages, ...
                current_dates, ...
                gcamp_output_folders, ...
                current_suite2p_group(:, 3));       

            data.meanImgs_gcamp = ...
                meanImgs_gcamp;

            data.meanImgs_red = ...
                meanImgs_red;

            data.meanImgs_blue = ...
                meanImgs_blue;

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
                data.meanImgs_gcamp;
        
            [processing_cache{k}, data] = ...
                process_electroporated_pass1( ...
                    paths.gcamp_output, ...
                    include_electroporated, ...
                    paths.date, ...
                    paths.TSeries, ...
                    paths.suite2p, ...
                    data);
                    
            % alignedImgs_blue = extract_aligned_blue_images( ...
            %     processing_cache{k});
            %
            % data.alignedImgs_blue = ...
            %     alignedImgs_blue;
            % 
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
                    data.meanImgs_gcamp, ...
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

function alignedImgs_blue = extract_aligned_blue_images( ...
    processing_cache)

%EXTRACT_ALIGNED_BLUE_IMAGES
%
% Extrait les images bleues alignées depuis processing_cache.
%
% Structure de sortie :
%
%   alignedImgs_blue{m}{p}
%
% où :
%   m = acquisition
%   p = plan
%
% L'image est récupérée depuis :
%
%   processing_cache{m}.planes{p}.aligned_image

    num_acquisitions = numel(processing_cache);

    alignedImgs_blue = cell( ...
        num_acquisitions, ...
        1);

    for m = 1:num_acquisitions

        alignedImgs_blue{m} = {};

        if isempty(processing_cache{m}) || ...
                ~isstruct(processing_cache{m})

            continue;
        end

        cache_m = processing_cache{m};

        if ~isfield(cache_m, 'planes') || ...
                isempty(cache_m.planes)

            continue;
        end

        num_planes = numel(cache_m.planes);

        alignedImgs_blue{m} = cell( ...
            num_planes, ...
            1);

        for p = 1:num_planes

            alignedImgs_blue{m}{p} = [];

            if isempty(cache_m.planes{p}) || ...
                    ~isstruct(cache_m.planes{p})

                continue;
            end

            if ~isfield( ...
                    cache_m.planes{p}, ...
                    'aligned_image')

                continue;
            end

            aligned_image = ...
                cache_m.planes{p}.aligned_image;

            if isempty(aligned_image)
                continue;
            end

            alignedImgs_blue{m}{p} = ...
                aligned_image;
        end
    end
end