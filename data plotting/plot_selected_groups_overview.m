function [figs, day_table, animal_table, legend_table] = ...
    plot_selected_groups_overview( ...
        selected_groups, include_blue_cells, ...
        automatic_selection, output_folders)

% PLOT_SELECTED_GROUPS_OVERVIEW
%
% Crée et sauvegarde, pour une sélection automatique :
%   figs.overview : âges enregistrés et nombre moyen de cellules par animal ;
%   figs.layers   : profondeur des plans et couches corticales ;
%   figs.legend   : légende commune des couleurs attribuées aux animaux.
%
% Les mêmes couleurs animales sont utilisées dans tous les graphiques.
%
% Sorties :
%   figs         : handles des figures overview, layers et legend.
%   day_table    : une ligne par animal, recording, branche et plan.
%   animal_table : résumé par animal et par branche.
%   legend_table : correspondance animal/couleur/âges.

    %==============================================================%
    % Initialize outputs
    %==============================================================%
    figs = struct( ...
        'overview', struct(), ...
        'layers',   struct(), ...
        'legend',   []);

    day_table = initialize_day_table();
    animal_table = initialize_animal_table();
    legend_table = initialize_legend_table();

    %==============================================================%
    % Input checks
    %==============================================================%
    if nargin < 1 || isempty(selected_groups)
        error('selected_groups is empty.');
    end

    if nargin < 2 || isempty(include_blue_cells)
        include_blue_cells = false;
    end

    if nargin < 3 || isempty(automatic_selection)
        automatic_selection = false;
    end

    if nargin < 4 || isempty(output_folders)

        type_names = fieldnames(selected_groups);
    
        output_folders = cell(numel(type_names),1);
    
        for t = 1:numel(type_names)
            output_folders{t} = pwd;
        end
    end
    
    if ~iscell(output_folders)
        output_folders = {output_folders};
    end

    include_blue_cells = parse_logical_flag(include_blue_cells);
    automatic_selection = parse_logical_flag(automatic_selection);

    % Cette synthèse globale n'est produite que pour la sélection automatique.
    if ~automatic_selection
        fprintf('[OVERVIEW] Manual selection: overview plots skipped.\n');
        return;
    end

    %==============================================================%
    % Extract data
    %==============================================================%
    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};
        current_groups = selected_groups.(current_type);

        if isempty(current_groups)
            continue;
        end

        for g = 1:numel(current_groups)

            current_group = current_groups(g);

            animal_id = get_animal_id( ...
                current_group, current_type, g);

            line_id = get_line_id(current_group);

            ages = get_group_ages(current_group);
            dates = get_group_dates(current_group);
            metadata = get_group_metadata(current_group);

            if ~isfield(current_group, 'data') || ...
                    isempty(current_group.data) || ...
                    ~isstruct(current_group.data)

                fprintf('[OVERVIEW] No data for %s - %s\n', ...
                    current_type, animal_id);
                continue;
            end

            data = current_group.data;

            day_table = extract_branch_counts( ...
                day_table, current_type, line_id, animal_id, ...
                ages, dates, metadata, data, 'gcamp_plane');

            if include_blue_cells
                day_table = extract_branch_counts( ...
                    day_table, current_type, line_id, animal_id, ...
                    ages, dates, metadata, data, 'blue_plane');
            end
        end
    end

    %==============================================================%
    % Check extracted data
    %==============================================================%
    if isempty(day_table)
        warning('No valid cell counts were found in selected_groups.');
        return;
    end

    %==============================================================%
    % Summaries and shared legend
    %==============================================================%
    animal_table = build_animal_summary(day_table);
    legend_table = build_animal_legend_table(day_table);

    %==============================================================%
    % Types réellement présents dans les données extraites
    %==============================================================%
    plotted_types = unique( ...
        string(day_table.Type), ...
        'stable');

    plotted_types = plotted_types( ...
        strlength(plotted_types) > 0);

    if isempty(plotted_types)
        warning('No valid experimental type was found in day_table.');
        return;
    end

    % Préfixe commun utilisé uniquement pour la légende partagée.
    shared_prefix = char(strjoin(plotted_types, '_'));

    %==============================================================%
    % Create one overview and one layer figure per type
    %==============================================================%
    for t = 1:numel(plotted_types)
        
        output_folder = output_folders{t};

        if exist(output_folder,'dir') ~= 7
            mkdir(output_folder);
        end

        current_type = plotted_types(t);
        current_field = matlab.lang.makeValidName(char(current_type));

        current_day_table = day_table( ...
            strcmpi(string(day_table.Type), current_type), :);

        current_animal_table = animal_table( ...
            strcmpi(string(animal_table.Type), current_type), :);

        overview_filename = sprintf( ...
            '%s_overview.png', ...
            char(current_type));

        layers_filename = sprintf( ...
            '%s_layers.png', ...
            char(current_type));

        overview_figure_path = fullfile( ...
            output_folder, ...
            overview_filename);

        layers_figure_path = fullfile( ...
            output_folder, ...
            layers_filename);

        %----------------------------------------------------------%
        % Overview figure for current type
        %----------------------------------------------------------%
        if exist(overview_figure_path, 'file') == 2

            fprintf([ ...
                '[OVERVIEW] Figure already exists, ', ...
                'generation skipped:\n%s\n'], ...
                overview_figure_path);

            figs.overview.(current_field) = [];

        else

            figs.overview.(current_field) = plot_combined_overview( ...
                current_day_table, ...
                current_animal_table, ...
                legend_table, ...
                include_blue_cells, ...
                current_type);

            save_overview_figure( ...
                figs.overview.(current_field), ...
                output_folder, ...
                overview_filename, ...
                true);
        end

        %----------------------------------------------------------%
        % Cortical-layer figure for current type
        %----------------------------------------------------------%
        if exist(layers_figure_path, 'file') == 2

            fprintf([ ...
                '[OVERVIEW] Layers figure already exists, ', ...
                'generation skipped:\n%s\n'], ...
                layers_figure_path);

            figs.layers.(current_field) = [];

        else

            figs.layers.(current_field) = plot_selected_groups_layers( ...
                current_day_table, ...
                legend_table, ...
                current_type);

            save_overview_figure( ...
                figs.layers.(current_field), ...
                output_folder, ...
                layers_filename, ...
                true);
        end
    end

    %==============================================================%
    % Create one shared animal legend for every selected type
    %==============================================================%
    legend_filename = sprintf( ...
        '%s_legend.png', ...
        shared_prefix);

    legend_table_filename = sprintf( ...
        '%s_legend_table.csv', ...
        shared_prefix);

    legend_figure_path = fullfile( ...
        output_folder, ...
        legend_filename);

    legend_table_path = fullfile( ...
        output_folder, ...
        legend_table_filename);

    if exist(legend_figure_path, 'file') == 2

        fprintf([ ...
            '[OVERVIEW] Shared legend already exists, ', ...
            'generation skipped:\n%s\n'], ...
            legend_figure_path);

        figs.legend = [];

    else

        figs.legend = plot_selected_groups_legend( ...
            legend_table);

        save_overview_figure( ...
            figs.legend, ...
            output_folder, ...
            legend_filename, ...
            false);
    end

    %==============================================================%
    % Save shared legend table
    %==============================================================%
    if exist(legend_table_path, 'file') == 2

        fprintf([ ...
            '[OVERVIEW] Shared legend table already exists, ', ...
            'file kept unchanged:\n%s\n'], ...
            legend_table_path);

    else

        writetable( ...
            legend_table, ...
            legend_table_path);

        fprintf( ...
            'Legend table saved:\n%s\n', ...
            legend_table_path);
    end

    close all
end

%% ========================================================================
% Extract cell counts for one branch
% =========================================================================
function day_table = extract_branch_counts( ...
        day_table, current_type, line_id, animal_id, ages, dates, ...
        metadata, data, branch_name)

    [planes_by_recording, source_field] = ...
        get_branch_planes(data, branch_name);

    if isempty(planes_by_recording)
        fprintf('[OVERVIEW] No %s data for %s - %s\n', ...
            branch_name, current_type, animal_id);
        return;
    end

    n_recordings = numel(planes_by_recording);

    for m = 1:n_recordings

        current_planes = planes_by_recording{m};

        if isempty(current_planes)
            continue;
        end

        if ~iscell(current_planes)
            current_planes = {current_planes};
        end

        age_label = get_age_for_recording_local(ages, m);
        age_number = extract_age_number_local(age_label);
        date_name = get_date_for_recording(dates, m);

        n_planes = numel(current_planes);
        cells_by_plane = nan(1, n_planes);
        position_z_by_plane = nan(1, n_planes);

        for p = 1:n_planes
            current_data = current_planes{p};
            n_cells = count_cells_in_plane(current_data);

            if isfinite(n_cells)
                cells_by_plane(p) = n_cells;
            end

            position_z_by_plane(p) = ...
                get_position_z_for_plane(metadata, m, p);
        end

        valid_planes = isfinite(cells_by_plane);

        if ~any(valid_planes)
            continue;
        end

        total_cells_day = sum( ...
            cells_by_plane(valid_planes), 'omitnan');

        for p = 1:n_planes

            if ~isfinite(cells_by_plane(p))
                continue;
            end

            new_row = table( ...
                string(current_type), ...
                string(line_id), ...
                string(animal_id), ...
                string(age_label), ...
                double(age_number), ...
                string(date_name), ...
                double(m), ...
                string(branch_name), ...
                string(source_field), ...
                double(p), ...
                double(position_z_by_plane(p)), ...
                double(cells_by_plane(p)), ...
                double(total_cells_day), ...
                'VariableNames', { ...
                    'Type', 'Line', 'Animal', 'Age', 'AgeNumber', 'Date', ...
                    'RecordingIndex', 'Branch', 'SourceField', ...
                    'Plane', 'PositionZ_um', ...
                    'CellsInPlane', 'TotalCellsDay'});

            day_table = [day_table; new_row]; %#ok<AGROW>
        end
    end
end

%% ========================================================================
% Find the best cellular field for each branch
% =========================================================================
function [planes_by_recording, source_field] = ...
        get_branch_planes(data, branch_name)

    planes_by_recording = {};
    source_field = "";

    if ~isfield(data, branch_name) || ...
            ~isstruct(data.(branch_name))

        return;
    end

    branch = data.(branch_name);

    switch branch_name

        case 'gcamp_plane'

            candidate_fields = { ...
                'Raster_gcamp_by_plane', ...
                'DF_gcamp_by_plane', ...
                'F_gcamp_by_plane', ...
                'DFF0_gcamp_by_plane'};

        case 'blue_plane'

            candidate_fields = { ...
                'Raster_blue_by_plane', ...
                'DF_blue_by_plane', ...
                'F_blue_by_plane', ...
                'DFF0_blue_by_plane'};

        otherwise

            candidate_fields = {};
    end

    for f = 1:numel(candidate_fields)

        current_field = candidate_fields{f};

        if ~isfield(branch, current_field)
            continue;
        end

        current_value = branch.(current_field);

        if isempty(current_value)
            continue;
        end

        if ~iscell(current_value)
            current_value = {current_value};
        end

        if contains_nonempty_recording(current_value)

            planes_by_recording = current_value;
            source_field = string(current_field);

            return;
        end
    end
end

function tf = contains_nonempty_recording(values)

    tf = false;

    if isempty(values)
        return;
    end

    for m = 1:numel(values)

        current_value = values{m};

        if isempty(current_value)
            continue;
        end

        if iscell(current_value)

            for p = 1:numel(current_value)

                if ~isempty(current_value{p})
                    tf = true;
                    return;
                end
            end

        else

            tf = true;
            return;
        end
    end
end

%% ========================================================================
% Count cells in one plane
% =========================================================================
function n_cells = count_cells_in_plane(current_data)

    n_cells = NaN;

    if isempty(current_data)
        return;
    end

    if istable(current_data)

        n_cells = height(current_data);
        return;
    end

    if isnumeric(current_data) || islogical(current_data)

        if ismatrix(current_data)

            % Cellular matrices are expected as:
            %
            %   cells x frames
            %
            % Therefore the number of cells is the number of rows.
            n_cells = size(current_data, 1);
        end

        return;
    end

    if iscell(current_data)

        n_cells = numel(current_data);
    end
end

%% ========================================================================
% Build one summary row per animal and branch
% =========================================================================
function animal_table = build_animal_summary(day_table)

    animal_table = initialize_animal_table();

    if isempty(day_table)
        return;
    end

    % day_table contains one row per plane.
    %
    % Keep only one row per recording before averaging the daily totals.
    session_table = unique( ...
        day_table(:, { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'Age', ...
            'AgeNumber', ...
            'Date', ...
            'RecordingIndex', ...
            'Branch', ...
            'TotalCellsDay'}), ...
        'rows', ...
        'stable');

    group_keys = unique( ...
        session_table(:, { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'Branch'}), ...
        'rows', ...
        'stable');

    for i = 1:height(group_keys)

        current_type = group_keys.Type(i);
        current_line = group_keys.Line(i);
        current_animal = group_keys.Animal(i);
        current_branch = group_keys.Branch(i);

        rows = ...
            session_table.Type == current_type & ...
            session_table.Line == current_line & ...
            session_table.Animal == current_animal & ...
            session_table.Branch == current_branch;

        current_sessions = session_table(rows, :);

        total_cells = double(current_sessions.TotalCellsDay);
        total_cells = total_cells(isfinite(total_cells));

        if isempty(total_cells)

            mean_cells = NaN;
            median_cells = NaN;
            min_cells = NaN;
            max_cells = NaN;

        else

            mean_cells = mean(total_cells, 'omitnan');
            median_cells = median(total_cells, 'omitnan');
            min_cells = min(total_cells);
            max_cells = max(total_cells);
        end

        age_numbers = double(current_sessions.AgeNumber);
        age_numbers = age_numbers(isfinite(age_numbers));

        if isempty(age_numbers)

            min_age = NaN;
            max_age = NaN;
            unique_ages = "";

        else

            min_age = min(age_numbers);
            max_age = max(age_numbers);

            unique_age_values = unique( ...
                age_numbers, ...
                'sorted');

            unique_ages = strjoin( ...
                "P" + string(unique_age_values), ...
                ", ");
        end

        n_recordings = height(current_sessions);

        valid_dates = current_sessions.Date;
        valid_dates = valid_dates(strlength(valid_dates) > 0);

        if isempty(valid_dates)
            n_days = n_recordings;
        else
            n_days = numel(unique(valid_dates));
        end

        new_row = table( ...
            current_type, ...
            current_line, ...
            current_animal, ...
            current_branch, ...
            double(n_recordings), ...
            double(n_days), ...
            double(mean_cells), ...
            double(median_cells), ...
            double(min_cells), ...
            double(max_cells), ...
            double(min_age), ...
            double(max_age), ...
            string(unique_ages), ...
            'VariableNames', { ...
                'Type', ...
                'Line', ...
                'Animal', ...
                'Branch', ...
                'NRecordings', ...
                'NDays', ...
                'MeanCellsPerDay', ...
                'MedianCellsPerDay', ...
                'MinCellsPerDay', ...
                'MaxCellsPerDay', ...
                'MinAge', ...
                'MaxAge', ...
                'Ages'});

        animal_table = [animal_table; new_row]; %#ok<AGROW>
    end

    animal_table = sortrows( ...
        animal_table, ...
        {'Type', 'Line', 'Animal', 'Branch'});
end

%% ========================================================================
% Plot one combined GCaMP + mTOR overview
% =========================================================================
function fig = plot_combined_overview( ...
        day_table, ...
        animal_table, ...
        legend_table, ...
        include_blue_cells, ...
        current_type)

    if isempty(day_table)
        fig = [];
        return;
    end

    if nargin < 5 || strlength(string(current_type)) == 0
        current_type = "Selected groups";
    end

    %==============================================================%
    % One row per recording and branch
    %==============================================================%
    session_table = unique( ...
        day_table(:, { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'Age', ...
            'AgeNumber', ...
            'Date', ...
            'RecordingIndex', ...
            'Branch', ...
            'TotalCellsDay'}), ...
        'rows', ...
        'stable');

    session_table.DisplayAnimal = create_animal_labels( ...
        session_table.Type, ...
        session_table.Line, ...
        session_table.Animal);

    animal_table.DisplayAnimal = create_animal_labels( ...
        animal_table.Type, ...
        animal_table.Line, ...
        animal_table.Animal);

    animal_labels = unique( ...
        session_table.DisplayAnimal, ...
        'stable');

    n_animals = numel(animal_labels);

    if n_animals == 0
        fig = [];
        return;
    end

    %==============================================================%
    % Ages
    %==============================================================%
    finite_ages = session_table.AgeNumber( ...
        isfinite(session_table.AgeNumber));

    if isempty(finite_ages)

        age_ticks = 1;
        age_tick_labels = "";

    else

        min_age = floor(min(finite_ages));
        max_age = ceil(max(finite_ages));

        age_ticks = min_age:max_age;
        age_tick_labels = "P" + string(age_ticks);
    end

    % Y positions must increase because MATLAB requires increasing ticks.
    %
    % YDir = reverse will place the first animal at the top.
    y_positions = 1:n_animals;

    %==============================================================%
    % Extract means by animal
    %==============================================================%
    mean_gcamp = nan(n_animals, 1);
    mean_mtor = nan(n_animals, 1);

    for a = 1:n_animals

        current_animal = animal_labels(a);

        %----------------------------------------------------------%
        % GCaMP
        %----------------------------------------------------------%
        gcamp_rows = ...
            animal_table.DisplayAnimal == current_animal & ...
            animal_table.Branch == "gcamp_plane";

        if any(gcamp_rows)

            current_values = ...
                animal_table.MeanCellsPerDay(gcamp_rows);

            current_values = ...
                current_values(isfinite(current_values));

            if ~isempty(current_values)
                mean_gcamp(a) = current_values(1);
            end
        end

        %----------------------------------------------------------%
        % mTOR-electroporated cells
        %----------------------------------------------------------%
        blue_rows = ...
            animal_table.DisplayAnimal == current_animal & ...
            animal_table.Branch == "blue_plane";

        if any(blue_rows)

            current_values = ...
                animal_table.MeanCellsPerDay(blue_rows);

            current_values = ...
                current_values(isfinite(current_values));

            if ~isempty(current_values)
                mean_mtor(a) = current_values(1);
            end
        end
    end

    has_mtor_data = ...
        include_blue_cells && ...
        any(isfinite(mean_mtor));

    %==============================================================%
    % Figure
    %==============================================================%
    figure_height = max(400, 120 + 60 * n_animals);

    fig = figure( ...
        'Color', 'w', ...
        'Name', 'Selected groups overview', ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'OuterPosition', [0, 0, 1, 1]);

    main_ax = axes( ...
        fig, ...
        'Position', [0.10, 0.17, 0.56, 0.70]);

    bar_ax = axes( ...
        fig, ...
        'Position', [0.72, 0.17, 0.23, 0.70]);

    hold(main_ax, 'on');
    hold(bar_ax, 'on');

    %==============================================================%
    % Grid
    %==============================================================%
    x_limits = [ ...
        age_ticks(1) - 0.5, ...
        age_ticks(end) + 0.5];

    for y = 0.5:1:(n_animals + 0.5)

        plot( ...
            main_ax, ...
            x_limits, ...
            [y, y], ...
            'Color', [0.82, 0.82, 0.82], ...
            'LineWidth', 0.8);
    end

    for x = (age_ticks(1) - 0.5):1:(age_ticks(end) + 0.5)

        plot( ...
            main_ax, ...
            [x, x], ...
            [0.5, n_animals + 0.5], ...
            'Color', [0.82, 0.82, 0.82], ...
            'LineWidth', 0.8);
    end

    %==============================================================%
    % Recording-age dots
    %==============================================================%
    for a = 1:n_animals

        current_animal = animal_labels(a);

        current_rows = ...
            session_table.DisplayAnimal == current_animal;

        current_ages = ...
            session_table.AgeNumber(current_rows);

        current_ages = ...
            current_ages(isfinite(current_ages));

        current_ages = ...
            unique(current_ages, 'sorted');

        if isempty(current_ages)
            continue;
        end

        animal_color = get_animal_color( ...
            legend_table, current_animal);

        scatter( ...
            main_ax, ...
            current_ages, ...
            repmat(y_positions(a), size(current_ages)), ...
            65, ...
            'filled', ...
            'MarkerFaceColor', animal_color, ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.5, ...
            'HandleVisibility', 'off');
    end

    %==============================================================%
    % Cell-count bars
    %==============================================================%
    if has_mtor_data

        bar_values = [mean_gcamp, mean_mtor];

        bar_handles = barh( ...
            bar_ax, ...
            y_positions, ...
            bar_values, ...
            'grouped');

        % GCaMP cells (vert)
        bar_handles(1).FaceColor = [0.20 0.70 0.20];
        bar_handles(1).EdgeColor = 'none';
        
        % mTOR-electroporated cells (bleu)
        bar_handles(2).FaceColor = [0.10 0.40 0.90];
        bar_handles(2).EdgeColor = 'none';

        % Manual legend at figure level.
        % It does not resize bar_ax, so both axes remain aligned.
        annotation( ...
            fig, ...
            'rectangle', ...
            [0.70, 0.895, 0.015, 0.018], ...
            'FaceColor', [0.20 0.70 0.20], ...
            'EdgeColor', 'none');
        
        annotation( ...
            fig, ...
            'textbox', ...
            [0.717, 0.884, 0.11, 0.04], ...
            'String', 'GCaMP cells', ...
            'EdgeColor', 'none', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 10);
        
        annotation( ...
            fig, ...
            'rectangle', ...
            [0.82, 0.895, 0.015, 0.018], ...
            'FaceColor', [0.10 0.40 0.90], ...
            'EdgeColor', 'none');
        
        annotation( ...
            fig, ...
            'textbox', ...
            [0.837, 0.884, 0.15, 0.04], ...
            'String', 'mTOR-electroporated cells', ...
            'EdgeColor', 'none', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 10);

    else

        bar_handles = barh( ...
            bar_ax, ...
            y_positions, ...
            mean_gcamp, ...
            0.58);

        bar_handles.FaceColor = [0.20, 0.48, 0.75];
        bar_handles.EdgeColor = 'none';

        annotation( ...
            fig, ...
            'rectangle', ...
            [0.70, 0.895, 0.015, 0.018], ...
            'FaceColor', [0.20 0.70 0.20], ...
            'EdgeColor', 'none');
        
        annotation( ...
            fig, ...
            'textbox', ...
            [0.807, 0.884, 0.12, 0.04], ...
            'String', 'GCaMP cells', ...
            'EdgeColor', 'none', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 10);
    end

    %==============================================================%
    % Determine x limit for the bar axis
    %==============================================================%
    all_values = [mean_gcamp; mean_mtor];
    all_values = all_values(isfinite(all_values));

    if isempty(all_values)

        max_value = 1;

    else

        max_value = max(all_values);

        if max_value <= 0
            max_value = 1;
        end
    end

    text_offset = max(1, 0.025 * max_value);

    %==============================================================%
    % Numeric labels
    %==============================================================%
    if has_mtor_data

        % For grouped barh, first series is slightly above and
        % second series slightly below when YDir is reversed.
        gcamp_y_offset = -0.18;
        mtor_y_offset = 0.18;

        for a = 1:n_animals

            if isfinite(mean_gcamp(a))

                text( ...
                    bar_ax, ...
                    mean_gcamp(a) + text_offset, ...
                    y_positions(a) + gcamp_y_offset, ...
                    sprintf('%.0f', mean_gcamp(a)), ...
                    'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 9);
            end

            if isfinite(mean_mtor(a))

                text( ...
                    bar_ax, ...
                    mean_mtor(a) + text_offset, ...
                    y_positions(a) + mtor_y_offset, ...
                    sprintf('%.0f', mean_mtor(a)), ...
                    'HorizontalAlignment', 'left', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 9);
            end
        end

    else

        for a = 1:n_animals

            if ~isfinite(mean_gcamp(a))
                continue;
            end

            text( ...
                bar_ax, ...
                mean_gcamp(a) + text_offset, ...
                y_positions(a), ...
                sprintf('%.0f', mean_gcamp(a)), ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'middle', ...
                'FontSize', 9);
        end
    end

    %==============================================================%
    % Format main axis
    %==============================================================%
    xlim(main_ax, x_limits);
    ylim(main_ax, [0.5, n_animals + 0.5]);

    main_ax.XTick = age_ticks;
    main_ax.XTickLabel = age_tick_labels;

    main_ax.YTick = 1:n_animals;
    main_ax.YTickLabel = animal_labels;

    main_ax.YDir = 'reverse';

    main_ax.FontSize = 11;
    main_ax.TickLength = [0, 0];
    main_ax.Box = 'on';
    main_ax.Layer = 'top';

    xlabel( ...
        main_ax, ...
        'Postnatal age', ...
        'FontSize', 12);

    ylabel( ...
        main_ax, ...
        'Mouse', ...
        'FontSize', 12);

    %==============================================================%
    % Format bar axis
    %==============================================================%
    ylim(bar_ax, [0.5, n_animals + 0.5]);

    bar_ax.YTick = 1:n_animals;
    bar_ax.YTickLabel = {};

    bar_ax.YDir = 'reverse';

    bar_ax.FontSize = 11;
    bar_ax.TickLength = [0, 0];
    bar_ax.Box = 'off';

    xlim(bar_ax, [0, max_value * 1.30]);

    xlabel( ...
        bar_ax, ...
        'Mean number of cells per day', ...
        'FontSize', 12);

    title( ...
        bar_ax, ...
        'N cells', ...
        'FontSize', 12);

    %==============================================================%
    % Global title
    %==============================================================%
    annotation( ...
        fig, ...
        'textbox', ...
        [0.10, 0.92, 0.85, 0.05], ...
        'String', sprintf('%s overview', char(current_type)), ...
        'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontWeight', 'bold', ...
        'FontSize', 14);

    hold(main_ax, 'off');
    hold(bar_ax, 'off');
end

%% ========================================================================
% Create unique animal display labels
% =========================================================================
function labels = create_animal_labels(types, lines, animals)

    types = string(types);
    lines = string(lines);
    animals = string(animals);

    labels = animals;

    has_line = strlength(strtrim(lines)) > 0;
    labels(has_line) = ...
        strtrim(lines(has_line)) + "_" + strtrim(animals(has_line));

    unique_labels = unique(labels);

    for i = 1:numel(unique_labels)

        current_label = unique_labels(i);
        rows = labels == current_label;
        associated_types = unique(types(rows));

        % Ajouter le type uniquement si le même couple ligne-animal
        % apparaît dans plusieurs types expérimentaux.
        if numel(associated_types) > 1
            labels(rows) = types(rows) + " - " + labels(rows);
        end
    end
end

%% ========================================================================
% Extract line ID
% =========================================================================
function line_id = get_line_id(current_group)

    line_id = "";

    candidate_fields = { ...
        'line', ...
        'Line', ...
        'line_group', ...
        'LineID'};

    for f = 1:numel(candidate_fields)

        field_name = candidate_fields{f};

        if ~isfield(current_group, field_name)
            continue;
        end

        current_value = current_group.(field_name);

        if isempty(current_value)
            continue;
        end

        if iscell(current_value)
            current_value = current_value{1};
        end

        line_id = string(current_value);

        if strlength(strtrim(line_id)) > 0
            line_id = strtrim(line_id);
            return;
        end
    end
end

%% ========================================================================
% Extract animal ID
% =========================================================================
function animal_id = get_animal_id( ...
        current_group, ...
        current_type, ...
        group_index)

    animal_id = "";

    candidate_fields = { ...
        'animal_group', ...
        'animal', ...
        'Animal', ...
        'animal_id', ...
        'AnimalID'};

    for f = 1:numel(candidate_fields)

        field_name = candidate_fields{f};

        if ~isfield(current_group, field_name)
            continue;
        end

        current_value = current_group.(field_name);

        if isempty(current_value)
            continue;
        end

        if iscell(current_value)
            current_value = current_value{1};
        end

        animal_id = string(current_value);

        if strlength(animal_id) > 0
            return;
        end
    end

    animal_id = ...
        string(current_type) + "_" + string(group_index);
end

%% ========================================================================
% Extract ages
% =========================================================================
function ages = get_group_ages(current_group)

    ages = [];

    candidate_fields = { ...
        'ages', ...
        'age', ...
        'Age'};

    for f = 1:numel(candidate_fields)

        field_name = candidate_fields{f};

        if isfield(current_group, field_name)

            ages = current_group.(field_name);
            return;
        end
    end

    if isfield(current_group, 'metadata') && ...
            isstruct(current_group.metadata)

        for f = 1:numel(candidate_fields)

            field_name = candidate_fields{f};

            if isfield(current_group.metadata, field_name)

                ages = current_group.metadata.(field_name);
                return;
            end
        end
    end
end

function age_label = get_age_for_recording_local(ages, m)

    age_label = "";

    if isempty(ages)
        return;
    end

    current_age = [];

    if iscell(ages)

        if numel(ages) >= m
            current_age = ages{m};
        elseif isscalar(ages)
            current_age = ages{1};
        end

    elseif isstring(ages)

        if numel(ages) >= m
            current_age = ages(m);
        elseif isscalar(ages)
            current_age = ages;
        end

    elseif ischar(ages)

        current_age = ages;

    elseif isnumeric(ages)

        if numel(ages) >= m
            current_age = ages(m);
        elseif isscalar(ages)
            current_age = ages;
        end
    end

    if isempty(current_age)
        return;
    end

    if isnumeric(current_age)

        age_label = "P" + string(current_age);

    else

        age_label = string(current_age);
    end
end

function age_number = extract_age_number_local(age_label)

    age_number = NaN;

    age_label = string(age_label);

    if strlength(age_label) == 0
        return;
    end

    token = regexp( ...
        char(age_label), ...
        '[-+]?\d*\.?\d+', ...
        'match', ...
        'once');

    if ~isempty(token)
        age_number = str2double(token);
    end
end

%% ========================================================================
% Extract dates
% =========================================================================
function dates = get_group_dates(current_group)

    dates = {};

    %==============================================================%
    % Direct fields
    %==============================================================%
    candidate_fields = { ...
        'date_group_paths', ...
        'dates', ...
        'date_paths'};

    for f = 1:numel(candidate_fields)

        field_name = candidate_fields{f};

        if isfield(current_group, field_name) && ...
                ~isempty(current_group.(field_name))

            dates = current_group.(field_name);
            return;
        end
    end

    %==============================================================%
    % Paths structure
    %==============================================================%
    if isfield(current_group, 'paths') && ...
            isstruct(current_group.paths)

        path_fields = { ...
            'date', ...
            'dates', ...
            'date_group_paths', ...
            'gcamp_root', ...
            'gcamp_output', ...
            'TSeries'};

        for f = 1:numel(path_fields)

            field_name = path_fields{f};

            if isfield(current_group.paths, field_name) && ...
                    ~isempty(current_group.paths.(field_name))

                dates = current_group.paths.(field_name);
                return;
            end
        end
    end

    %==============================================================%
    % Metadata
    %==============================================================%
    if isfield(current_group, 'metadata') && ...
            isstruct(current_group.metadata) && ...
            isfield(current_group.metadata, 'DateName')

        dates = current_group.metadata.DateName;
    end
end

function date_name = get_date_for_recording(dates, m)

    date_name = "Recording_" + string(m);

    if isempty(dates)
        return;
    end

    current_date = [];

    if iscell(dates)

        if numel(dates) >= m
            current_date = dates{m};
        elseif isscalar(dates)
            current_date = dates{1};
        end

    elseif isstring(dates)

        if numel(dates) >= m
            current_date = dates(m);
        elseif isscalar(dates)
            current_date = dates;
        end

    elseif ischar(dates)

        current_date = dates;

    elseif isnumeric(dates)

        if numel(dates) >= m
            current_date = dates(m);
        elseif isscalar(dates)
            current_date = dates;
        end
    end

    if isempty(current_date)
        return;
    end

    if isnumeric(current_date)

        date_name = string(current_date);
        return;
    end

    current_date = char(string(current_date));
    current_date = strip_trailing_filesep(current_date);

    [~, final_name] = fileparts(current_date);

    if isempty(final_name)
        final_name = current_date;
    end

    date_name = string(final_name);
end

function path_value = strip_trailing_filesep(path_value)

    while ~isempty(path_value) && ...
            (path_value(end) == '/' || ...
             path_value(end) == '\')

        path_value(end) = [];
    end
end

%% ========================================================================
% Parse include_blue_cells flag
% =========================================================================
function flag = parse_logical_flag(value)

    if islogical(value)

        flag = value(1);
        return;
    end

    if isnumeric(value)

        flag = value(1) ~= 0;
        return;
    end

    value = lower(strtrim(char(string(value))));

    flag = ismember(value, { ...
        '1', ...
        'true', ...
        'yes', ...
        'on'});
end

%% ========================================================================
% Initialize detailed table
% =========================================================================
function day_table = initialize_day_table()

    day_table = table( ...
        string.empty(0, 1), ... % Type
        string.empty(0, 1), ... % Line
        string.empty(0, 1), ... % Animal
        string.empty(0, 1), ... % Age
        nan(0, 1), ...          % AgeNumber
        string.empty(0, 1), ... % Date
        nan(0, 1), ...          % RecordingIndex
        string.empty(0, 1), ... % Branch
        string.empty(0, 1), ... % SourceField
        nan(0, 1), ...          % Plane
        nan(0, 1), ...          % PositionZ_um
        nan(0, 1), ...          % CellsInPlane
        nan(0, 1), ...          % TotalCellsDay
        'VariableNames', { ...
            'Type', 'Line', 'Animal', 'Age', 'AgeNumber', 'Date', ...
            'RecordingIndex', 'Branch', 'SourceField', ...
            'Plane', 'PositionZ_um', ...
            'CellsInPlane', 'TotalCellsDay'});
end

%% ========================================================================
% Initialize animal summary table
% =========================================================================
function animal_table = initialize_animal_table()

    animal_table = table( ...
        string.empty(0, 1), ... % Type
        string.empty(0, 1), ... % Line
        string.empty(0, 1), ... % Animal
        string.empty(0, 1), ... % Branch
        nan(0, 1), ...          % NRecordings
        nan(0, 1), ...          % NDays
        nan(0, 1), ...          % MeanCellsPerDay
        nan(0, 1), ...          % MedianCellsPerDay
        nan(0, 1), ...          % MinCellsPerDay
        nan(0, 1), ...          % MaxCellsPerDay
        nan(0, 1), ...          % MinAge
        nan(0, 1), ...          % MaxAge
        string.empty(0, 1), ... % Ages
        'VariableNames', { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'Branch', ...
            'NRecordings', ...
            'NDays', ...
            'MeanCellsPerDay', ...
            'MedianCellsPerDay', ...
            'MinCellsPerDay', ...
            'MaxCellsPerDay', ...
            'MinAge', ...
            'MaxAge', ...
            'Ages'});
end

%% ========================================================================
% Group metadata
% =========================================================================
function metadata = get_group_metadata(current_group)

    metadata = struct();

    if isfield(current_group, 'metadata') && ...
            isstruct(current_group.metadata)
        metadata = current_group.metadata;
    end
end

%% ========================================================================
% Position Z for one recording and plane
% =========================================================================
function z = get_position_z_for_plane(metadata, recording_index, plane_index)

    z = NaN;

    if isempty(metadata) || ~isstruct(metadata) || ...
            ~isfield(metadata, 'PositionZ') || ...
            isempty(metadata.PositionZ)
        return;
    end

    position_z = metadata.PositionZ;
    raw = [];

    if iscell(position_z)

        if size(position_z, 1) >= recording_index && ...
                size(position_z, 2) >= plane_index
            raw = position_z{recording_index, plane_index};
        elseif isvector(position_z) && recording_index == 1 && ...
                numel(position_z) >= plane_index
            raw = position_z{plane_index};
        end

    elseif isnumeric(position_z) || islogical(position_z)

        if isvector(position_z)
            if recording_index == 1 && numel(position_z) >= plane_index
                raw = position_z(plane_index);
            elseif plane_index == 1 && numel(position_z) >= recording_index
                raw = position_z(recording_index);
            end
        elseif size(position_z, 1) >= recording_index && ...
                size(position_z, 2) >= plane_index
            raw = position_z(recording_index, plane_index);
        end
    end

    z = parse_position_z_value_local(raw);
end

function z = parse_position_z_value_local(raw)

    z = NaN;

    if isempty(raw)
        return;
    end

    if isnumeric(raw) || islogical(raw)
        raw = double(raw(:));
        raw = raw(isfinite(raw));

        if ~isempty(raw)
            z = raw(1);
        end
        return;
    end

    if iscell(raw) && isscalar(raw)
        z = parse_position_z_value_local(raw{1});
        return;
    end

    raw = char(string(raw));
    raw = strrep(raw, ',', '.');

    token = regexp(raw, ...
        '[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?', ...
        'match', 'once');

    if ~isempty(token)
        candidate = str2double(token);
        if isfinite(candidate)
            z = candidate;
        end
    end
end

%% ========================================================================
% Shared animal legend table
% =========================================================================
function legend_table = build_animal_legend_table(day_table)

    legend_table = initialize_legend_table();

    if isempty(day_table)
        return;
    end

    display_labels = create_animal_labels( ...
        day_table.Type, ...
        day_table.Line, ...
        day_table.Animal);

    source_table = table( ...
        string(day_table.Type), ...
        string(day_table.Line), ...
        string(day_table.Animal), ...
        string(display_labels), ...
        double(day_table.AgeNumber), ...
        'VariableNames', { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'DisplayAnimal', ...
            'AgeNumber'});

    % Une seule entrée par combinaison Type x Animal.
    animal_keys = unique( ...
        source_table(:, { ...
            'Type', ...
            'Line', ...
            'Animal', ...
            'DisplayAnimal'}), ...
        'rows', ...
        'stable');

    % Ordre reproductible : WT, SHAM, FCD, puis les autres types.
    animal_keys = sort_animal_legend_keys(animal_keys);

    n_animals = height(animal_keys);

    if n_animals == 0
        return;
    end

    % Génération d'une couleur réellement différente pour chaque animal.
    % Contrairement à lines(), cette palette ne répète pas les couleurs
    % lorsque le nombre d'animaux dépasse sept.
    animal_colors = generate_unique_animal_colors(n_animals);

    for i = 1:n_animals

        current_type = string(animal_keys.Type(i));
        current_line = string(animal_keys.Line(i));
        current_animal = string(animal_keys.Animal(i));
        current_display = string(animal_keys.DisplayAnimal(i));

        rows = ...
            source_table.Type == current_type & ...
            source_table.Line == current_line & ...
            source_table.Animal == current_animal;

        current_ages = double(source_table.AgeNumber(rows));

        current_ages = unique( ...
            current_ages(isfinite(current_ages)), ...
            'sorted');

        if isempty(current_ages)

            age_min = NaN;
            age_max = NaN;
            age_text = "";

        else

            age_min = min(current_ages);
            age_max = max(current_ages);

            age_text = strjoin( ...
                "P" + string(current_ages), ...
                ", ");
        end

        new_row = table( ...
            current_type, ...
            current_line, ...
            current_animal, ...
            current_display, ...
            double(i), ...
            double(animal_colors(i, 1)), ...
            double(animal_colors(i, 2)), ...
            double(animal_colors(i, 3)), ...
            double(age_min), ...
            double(age_max), ...
            string(age_text), ...
            'VariableNames', { ...
                'Type', ...
                'Line', ...
                'Animal', ...
                'DisplayAnimal', ...
                'ColorIndex', ...
                'Red', ...
                'Green', ...
                'Blue', ...
                'AgeMin', ...
                'AgeMax', ...
                'Ages'});

        legend_table = [legend_table; new_row]; %#ok<AGROW>
    end

    % Vérification de sécurité : aucune couleur RGB ne doit être dupliquée.
    rgb_values = round( ...
        [legend_table.Red, ...
         legend_table.Green, ...
         legend_table.Blue], ...
        12);

    [~, unique_indices] = unique( ...
        rgb_values, ...
        'rows', ...
        'stable');

    if numel(unique_indices) ~= height(legend_table)
        error([ ...
            'Internal color-generation error: ', ...
            'two animals received the same RGB color.']);
    end
end

function animal_keys = sort_animal_legend_keys(animal_keys)

    if isempty(animal_keys)
        return;
    end

    preferred_order = [ ...
        "WT", ...
        "SHAM", ...
        "FCD"];

    type_values = string(animal_keys.Type);
    type_rank = nan(height(animal_keys), 1);

    for i = 1:height(animal_keys)

        current_type = type_values(i);

        preferred_index = find( ...
            strcmpi(preferred_order, current_type), ...
            1, ...
            'first');

        if isempty(preferred_index)
            type_rank(i) = numel(preferred_order) + 1;
        else
            type_rank(i) = preferred_index;
        end
    end

    animal_keys.TypeRankTemporary = type_rank;

    animal_keys = sortrows( ...
        animal_keys, ...
        { ...
            'TypeRankTemporary', ...
            'Type', ...
            'Line', ...
            'Animal'});

    animal_keys.TypeRankTemporary = [];
end


function colors = generate_unique_animal_colors(n_animals)

    if nargin < 1 || isempty(n_animals)
        n_animals = 0;
    end

    n_animals = round(double(n_animals));

    if ~isscalar(n_animals) || ...
            ~isfinite(n_animals) || ...
            n_animals < 0

        error('n_animals must be a finite non-negative integer.');
    end

    if n_animals == 0
        colors = zeros(0, 3);
        return;
    end

    if n_animals == 1
        colors = [0.00, 0.45, 0.74];
        return;
    end

    % turbo(n+2) donne des couleurs toutes différentes.
    % Les deux couleurs extrêmes sont retirées car elles sont souvent
    % très sombres et moins lisibles sur fond blanc.
    full_palette = turbo(n_animals + 2);
    colors = full_palette(2:end-1, :);

    colors = max(0, min(1, colors));
end

function color = get_animal_color( ...
        legend_table, display_animal, type_name, animal_name)

    color = [0.45, 0.45, 0.45];

    if isempty(legend_table)
        return;
    end

    row = [];

    % Recherche prioritaire par Type x Animal.
    if nargin >= 4 && ...
            strlength(string(type_name)) > 0 && ...
            strlength(string(animal_name)) > 0

        row = find( ...
            strcmpi(string(legend_table.Type), string(type_name)) & ...
            strcmpi(string(legend_table.Animal), string(animal_name)), ...
            1, ...
            'first');
    end

    % Recherche de repli par DisplayAnimal.
    if isempty(row)

        row = find( ...
            strcmpi( ...
                string(legend_table.DisplayAnimal), ...
                string(display_animal)), ...
            1, ...
            'first');
    end

    if isempty(row)
        warning( ...
            'No color found in legend_table for animal %s.', ...
            string(display_animal));
        return;
    end

    color = double([ ...
        legend_table.Red(row), ...
        legend_table.Green(row), ...
        legend_table.Blue(row)]);

    if numel(color) ~= 3 || any(~isfinite(color))
        color = [0.45, 0.45, 0.45];
    end
end

function legend_table = initialize_legend_table()

    legend_table = table( ...
        string.empty(0, 1), ... % Type
        string.empty(0, 1), ... % Line
        string.empty(0, 1), ... % Animal
        string.empty(0, 1), ... % DisplayAnimal
        nan(0, 1), ...          % ColorIndex
        nan(0, 1), ...          % Red
        nan(0, 1), ...          % Green
        nan(0, 1), ...          % Blue
        nan(0, 1), ...          % AgeMin
        nan(0, 1), ...          % AgeMax
        string.empty(0, 1), ... % Ages
        'VariableNames', { ...
            'Type', 'Line', 'Animal', 'DisplayAnimal', 'ColorIndex', ...
            'Red', 'Green', 'Blue', ...
            'AgeMin', 'AgeMax', 'Ages'});
end

%% ========================================================================
% Cortical layer figure
% =========================================================================
function fig = plot_selected_groups_layers(day_table, legend_table, current_type)

    fig = [];

    if nargin < 3 || strlength(string(current_type)) == 0
        current_type = "Selected groups";
    end

    if isempty(day_table) || ...
            ~ismember('PositionZ_um', day_table.Properties.VariableNames)
        fprintf('[OVERVIEW] PositionZ_um unavailable: layer figure skipped.\n');
        return;
    end

    layer_defs = { ...
        'I',       0,  80; ...
        'II/III', 80, 300; ...
        'IV',    300, 450};

    % GCaMP and blue rows can describe the same recording/plane.
    % Keep one unique point per animal, recording and plane.
    layer_table = unique( ...
        day_table(:, { ...
            'Type', 'Line', 'Animal', 'Age', 'AgeNumber', 'Date', ...
            'RecordingIndex', 'Plane', 'PositionZ_um'}), ...
        'rows', 'stable');

    layer_table = layer_table( ...
        isfinite(layer_table.AgeNumber) & ...
        isfinite(layer_table.PositionZ_um), :);

    if isempty(layer_table)
        fprintf('[OVERVIEW] No valid cortical depth found.\n');
        return;
    end

    layer_table.DisplayAnimal = create_animal_labels( ...
        layer_table.Type, layer_table.Line, layer_table.Animal);

    min_age = floor(min(layer_table.AgeNumber));
    max_age = ceil(max(layer_table.AgeNumber));
    age_ticks = min_age:max_age;
    x_limits = [min_age - 0.65, max_age + 0.65];

    fig = figure( ...
        'Color', 'w', ...
        'Name', 'Selected groups cortical layers', ...
        'NumberTitle', 'off', ...
        'Units', 'normalized', ...
        'OuterPosition', [0, 0, 1, 1]);

    ax = axes(fig, 'Position', [0.08, 0.13, 0.88, 0.78]);
    hold(ax, 'on');

    layer_colors = [ ...
        0.97, 0.97, 0.97; ...
        0.91, 0.91, 0.91; ...
        0.85, 0.85, 0.85];

    for l = 1:size(layer_defs, 1)

        z_min = layer_defs{l, 2};
        z_max = layer_defs{l, 3};

        patch(ax, ...
            [x_limits(1), x_limits(2), x_limits(2), x_limits(1)], ...
            [z_min, z_min, z_max, z_max], ...
            layer_colors(l, :), ...
            'EdgeColor', 'none', ...
            'HandleVisibility', 'off');

        yline(ax, z_min, '--k', 'HandleVisibility', 'off');

        text(ax, x_limits(1) + 0.04, mean([z_min, z_max]), ...
            layer_defs{l, 1}, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', ...
            'FontWeight', 'bold', ...
            'BackgroundColor', 'w', ...
            'Margin', 2, ...
            'Interpreter', 'none');
    end

    yline(ax, layer_defs{end, 3}, '--k', ...
        'HandleVisibility', 'off');

    unique_animals = unique(layer_table.DisplayAnimal, 'stable');

    for a = 1:numel(unique_animals)

        current_animal = unique_animals(a);
        rows = layer_table.DisplayAnimal == current_animal;

        animal_color = get_animal_color( ...
            legend_table, current_animal);

        x_values = double(layer_table.AgeNumber(rows));
        z_values = double(layer_table.PositionZ_um(rows));

        % Deterministic jitter: stable figure across executions.
        rng(a, 'twister');
        x_jitter = (rand(size(x_values)) - 0.5) * 0.20;

        scatter(ax, ...
            x_values + x_jitter, z_values, 75, ...
            'filled', ...
            'MarkerFaceColor', animal_color, ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.5, ...
            'HandleVisibility', 'off');
    end

    xlim(ax, x_limits);
    ylim(ax, [layer_defs{1, 2}, layer_defs{end, 3}]);

    ax.YDir = 'reverse';
    ax.XTick = age_ticks;
    ax.XTickLabel = "P" + string(age_ticks);
    ax.FontSize = 12;
    ax.TickLength = [0, 0];
    ax.Box = 'off';
    ax.Layer = 'top';

    xlabel(ax, 'Postnatal age', 'FontSize', 13);
    ylabel(ax, 'Cortical depth (\mum)', 'FontSize', 13);
    title(ax, ...
        sprintf('%s - recording depth by age and animal', ...
            char(current_type)), ...
        'FontSize', 15, ...
        'FontWeight', 'bold');

    hold(ax, 'off');
end

%% ========================================================================
% Shared animal legend figure
% =========================================================================
function fig = plot_selected_groups_legend(legend_table)

    fig = [];

    if isempty(legend_table)
        return;
    end

    n_animals = height(legend_table);
    figure_height = max(280, 80 + 42 * n_animals);

    fig = figure( ...
        'Color', 'w', ...
        'Name', 'Selected groups animal legend', ...
        'NumberTitle', 'off', ...
        'Position', [200, 150, 1000, figure_height]);

    ax = axes(fig, 'Position', [0.04, 0.07, 0.92, 0.86]);
    hold(ax, 'on');

    y_positions = n_animals:-1:1;

    for i = 1:n_animals

        animal_color = [ ...
            legend_table.Red(i), ...
            legend_table.Green(i), ...
            legend_table.Blue(i)];

        scatter(ax, 1, y_positions(i), 110, ...
            'filled', ...
            'MarkerFaceColor', animal_color, ...
            'MarkerEdgeColor', 'k');

        label_text = sprintf( ...
            '%s   |   Type: %s   |   Ages: %s', ...
            char(legend_table.DisplayAnimal(i)), ...
            char(legend_table.Type(i)), ...
            char(legend_table.Ages(i)));

        text(ax, 1.18, y_positions(i), label_text, ...
            'Interpreter', 'none', ...
            'FontSize', 11, ...
            'VerticalAlignment', 'middle');
    end

    xlim(ax, [0.8, 7]);
    ylim(ax, [0, n_animals + 1]);
    axis(ax, 'off');

    title(ax, 'Animal color legend', ...
        'FontSize', 14, 'FontWeight', 'bold');

    hold(ax, 'off');
end

%% ========================================================================
% Save one overview figure
% =========================================================================
function save_overview_figure(fig, output_folder, filename, maximize_figure)

    if nargin < 4
        maximize_figure = true;
    end

    if isempty(fig) || ~ishghandle(fig)
        return;
    end

    if exist(output_folder, 'dir') ~= 7
        mkdir(output_folder);
    end

    figure(fig);

    if maximize_figure
        set(fig, ...
            'Units', 'normalized', ...
            'OuterPosition', [0, 0, 1, 1]);
    end

    drawnow;

    output_path = fullfile(output_folder, filename);

    try
        exportgraphics(fig, output_path, 'Resolution', 300);
    catch ME
        warning('exportgraphics failed (%s). saveas used instead.', ...
            ME.message);
        saveas(fig, output_path);
    end

    fprintf('Figure saved:\n%s\n', output_path);
end

