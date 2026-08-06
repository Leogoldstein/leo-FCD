function [selected_groups, results_table] = ...
    compute_DF(selected_groups, include_electroporated)

    % ============================================================
    % Vérification des entrées
    % ============================================================
    results_table = table();

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2 || isempty(include_electroporated)
        include_electroporated = '1';
    end

    include_electroporated = char(string(include_electroporated));

    type_names = fieldnames(selected_groups);

    % ============================================================
    % Boucle sur les types animaux
    % ============================================================
    for t = 1:numel(type_names)

        current_type = type_names{t};

        if ~isstruct(selected_groups.(current_type))
            continue;
        end

        % ========================================================
        % Boucle sur les animaux
        % ========================================================
        for k = 1:numel(selected_groups.(current_type))

            animal_struct = ...
                selected_groups.(current_type)(k);

            % ====================================================
            % Informations générales
            % ====================================================
            current_line = '';

            if isfield(animal_struct, 'line') && ...
                    ~isempty(animal_struct.line)

                current_line = char(string( ...
                    animal_struct.line));
            end

            current_animal = sprintf('Animal_%d', k);

            if isfield(animal_struct, 'animal') && ...
                    ~isempty(animal_struct.animal)

                current_animal = char(string( ...
                    animal_struct.animal));
            end

            current_ages = {};

            if isfield(animal_struct, 'ages') && ...
                    ~isempty(animal_struct.ages)

                current_ages = animal_struct.ages;
            end

            fprintf('\n==============================\n');
            fprintf('Compute data\n');
            fprintf('Type: %s\n', current_type);
            fprintf('Line: %s\n', current_line);
            fprintf('Animal %d / %d: %s\n', ...
                k, ...
                numel(selected_groups.(current_type)), ...
                current_animal);
            fprintf('==============================\n');

            % ====================================================
            % Récupération des données nécessaires
            % ====================================================
            if ~isfield(animal_struct, 'paths') || ...
                    isempty(animal_struct.paths)

                warning( ...
                    'Paths missing for type %s, animal %s.', ...
                    current_type, ...
                    current_animal);

                continue;
            end

            paths = animal_struct.paths;

            if isfield(animal_struct, 'metadata') && ...
                    ~isempty(animal_struct.metadata)

                metadata = animal_struct.metadata;
            else
                metadata = struct();
            end

            if isfield(animal_struct, 'data') && ...
                    ~isempty(animal_struct.data)

                data = animal_struct.data;
            else
                data = struct();
            end

            % ====================================================
            % Extraction des chemins utilisés
            % ====================================================
            gcamp_root_folders = {};

            if isfield(paths, 'gcamp_root')
                gcamp_root_folders = paths.gcamp_root;
            end

            date_group_paths = {};

            if isfield(paths, 'date')
                date_group_paths = paths.date;
            end

            % ====================================================
            % Sampling rate
            % ====================================================
            if ~isfield(metadata, 'SamplingRatePlane') || ...
                    isempty(metadata.SamplingRatePlane)

                warning( ...
                    ['SamplingRatePlane missing for type %s, ', ...
                     'animal %s.'], ...
                    current_type, ...
                    current_animal);

                continue;
            end

            sampling_rate_group = ...
                metadata.SamplingRatePlane;

            synchronous_frames_group = ...
                cell(size(sampling_rate_group));

            % ====================================================
            % Fenêtre de synchronie : 200 ms
            % ====================================================
            for m = 1:numel(sampling_rate_group)

                sampling_rate = ...
                    parse_sampling_rate_compute_DF( ...
                        sampling_rate_group, ...
                        m);

                if isempty(sampling_rate) || ...
                        ~isfinite(sampling_rate) || ...
                        sampling_rate <= 0

                    warning( ...
                        ['Sampling rate invalid for type %s, ', ...
                         'line %s, animal %s, recording %d.'], ...
                        current_type, ...
                        current_line, ...
                        current_animal, ...
                        m);

                    synchronous_frames_group{m} = [];
                    continue;
                end

                synchronous_frames_group{m} = ...
                    max(1, round(0.2 * sampling_rate));
            end

            % ====================================================
            % Calcul des résultats détaillés et de la table
            % ====================================================
            try
                [results_analysis, results_table_animal] = ...
                    compute_export_basic_metrics( ...
                        current_type, ...
                        current_animal, ...
                        current_ages, ...
                        gcamp_root_folders, ...
                        date_group_paths, ...
                        synchronous_frames_group, ...
                        data, ...
                        metadata, ...
                        include_electroporated);

            catch ME

                warning( ...
                    'Error for type %s, line %s, animal %s: %s', ...
                    current_type, ...
                    current_line, ...
                    current_animal, ...
                    ME.message);

                if ~isempty(ME.stack)
                    fprintf('Function: %s\n', ...
                        ME.stack(1).name);

                    fprintf('Line: %d\n', ...
                        ME.stack(1).line);
                end

                continue;
            end

            % ====================================================
            % Sauvegarde des résultats détaillés
            % ====================================================
            selected_groups.(current_type)(k).results_analysis = ...
                results_analysis;

            % ====================================================
            % Ajout à la table globale
            % ====================================================
            if ~isempty(results_table_animal)

                if isempty(results_table)

                    results_table = ...
                        results_table_animal;

                else

                    results_table = [ ...
                        results_table; ...
                        results_table_animal]; %#ok<AGROW>
                end
            end
        end
    end

    % ============================================================
    % Nettoyage final
    % ============================================================
    if ~isempty(results_table)

        % --------------------------------------------------------
        % Suppression des valeurs non finies
        % --------------------------------------------------------
        if ismember( ...
                'Value', ...
                results_table.Properties.VariableNames)

            value_column = results_table.Value;

            if isnumeric(value_column)

                results_table = ...
                    results_table(isfinite(value_column), :);
            end
        end

        % --------------------------------------------------------
        % Tri de la table
        % --------------------------------------------------------
        sorting_variables = { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'AgeNumber', ...
            'RecordingIndex', ...
            'Plane', ...
            'Branch', ...
            'Metric'};

        sorting_variables = ...
            sorting_variables(ismember( ...
                sorting_variables, ...
                results_table.Properties.VariableNames));

        if ~isempty(sorting_variables)

            results_table = sortrows( ...
                results_table, ...
                sorting_variables);
        end
    end

    fprintf('\n==============================\n');
    fprintf('Computation completed\n');
    fprintf('Results table: %d rows\n', ...
        height(results_table));
    fprintf('==============================\n');
end


function sampling_rate = ...
    parse_sampling_rate_compute_DF( ...
        sampling_rate_group, m)

    sampling_rate = [];

    if isempty(sampling_rate_group)
        return;
    end

    % ============================================================
    % Valeur correspondant à l'enregistrement m
    % ============================================================
    if iscell(sampling_rate_group)

        if numel(sampling_rate_group) < m
            return;
        end

        value = sampling_rate_group{m};

    elseif numel(sampling_rate_group) >= m

        value = sampling_rate_group(m);

    else
        return;
    end

    if isempty(value)
        return;
    end

    % ============================================================
    % Conversion numérique
    % ============================================================
    if isnumeric(value) || islogical(value)

        value = double(value(:));
        value = value(isfinite(value));

        if ~isempty(value)
            sampling_rate = value(1);
        end

    elseif ischar(value) || isstring(value)

        converted_value = ...
            str2double(string(value));

        converted_value = ...
            converted_value(isfinite(converted_value));

        if ~isempty(converted_value)
            sampling_rate = ...
                double(converted_value(1));
        end
    end
end