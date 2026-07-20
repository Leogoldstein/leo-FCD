function [selected_groups, results_table] = ...
    compute_DF(selected_groups, include_blue_cells)

    % ============================================================
    % Vérification des entrées
    % ============================================================
    results_table = table();

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    if nargin < 2 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end

    include_blue_cells = char(string(include_blue_cells));

    type_names = fieldnames(selected_groups);

    % ============================================================
    % Boucle sur les types animaux
    % ============================================================
    for t = 1:numel(type_names)

        current_type = type_names{t};

        % Sécurité si selected_groups contient un champ
        % qui n'est pas une structure d'animaux
        if ~isstruct(selected_groups.(current_type))
            continue;
        end

        % ========================================================
        % Boucle sur les animaux
        % ========================================================
        for k = 1:numel(selected_groups.(current_type))

            current_animal = ...
                selected_groups.(current_type)(k);

            fprintf('\n==============================\n');
            fprintf('Compute data\n');
            fprintf('Type: %s\n', current_type);
            fprintf('Animal %d / %d: %s\n', ...
                k, ...
                numel(selected_groups.(current_type)), ...
                char(string(current_animal.animal_group)));
            fprintf('==============================\n');

            % ====================================================
            % Récupération des données
            % ====================================================
            paths = current_animal.paths;
            metadata = current_animal.metadata;
            data = current_animal.data;

            gcamp_root_folders = paths.gcamp_root;
            date_group_paths = paths.date;

            current_animal_group = ...
                current_animal.animal_group;

            current_ages = current_animal.ages;

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
                        sampling_rate_group, m);

                if isempty(sampling_rate) || ...
                        ~isfinite(sampling_rate) || ...
                        sampling_rate <= 0

                    warning( ...
                        ['Sampling rate invalid for type %s, ', ...
                         'animal %s, recording %d.'], ...
                        current_type, ...
                        char(string(current_animal_group)), ...
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
                        current_animal_group, ...
                        current_ages, ...
                        gcamp_root_folders, ...
                        date_group_paths, ...
                        synchronous_frames_group, ...
                        data, ...
                        metadata, ...
                        include_blue_cells);

            catch ME
                warning( ...
                    'Error for type %s, animal %s: %s', ...
                    current_type, ...
                    char(string(current_animal_group)), ...
                    ME.message);

                fprintf('Function: %s\n', ME.stack(1).name);
                fprintf('Line: %d\n', ME.stack(1).line);

                continue;
            end

            % ====================================================
            % Sauvegarde des résultats détaillés dans selected_groups
            % ====================================================
            selected_groups.(current_type)(k).results_analysis = ...
                results_analysis;

            % ====================================================
            % Ajout à la table globale
            % ====================================================
            if ~isempty(results_table_animal)

                if isempty(results_table)
                    results_table = results_table_animal;
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

        % Supprime les lignes dont Value est non finie
        if ismember( ...
                'Value', ...
                results_table.Properties.VariableNames)

            value_column = results_table.Value;

            if isnumeric(value_column)
                valid_rows = isfinite(value_column);
                results_table = results_table(valid_rows, :);
            end
        end

        % Tri pour faciliter la lecture
        sorting_variables = { ...
            'Type', ...
            'Animal', ...
            'AgeNumber', ...
            'RecordingIndex', ...
            'Plane', ...
            'Branch', ...
            'Metric'};

        sorting_variables = sorting_variables( ...
            ismember( ...
                sorting_variables, ...
                results_table.Properties.VariableNames));

        if ~isempty(sorting_variables)
            results_table = sortrows( ...
                results_table, sorting_variables);
        end
    end

    fprintf('\n==============================\n');
    fprintf('Computation completed\n');
    fprintf('Results table: %d rows\n', height(results_table));
    fprintf('==============================\n');
end


function sampling_rate = ...
    parse_sampling_rate_compute_DF(sampling_rate_group, m)

    sampling_rate = [];

    if isempty(sampling_rate_group)
        return;
    end

    % ============================================================
    % Récupération de la valeur de l'enregistrement m
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

    % ============================================================
    % Conversion en valeur numérique
    % ============================================================
    if isnumeric(value)

        value = double(value(:));
        value = value(isfinite(value));

        if ~isempty(value)
            sampling_rate = value(1);
        end

    elseif ischar(value) || isstring(value)

        value = str2double(string(value));

        if isfinite(value)
            sampling_rate = double(value);
        end
    end
end