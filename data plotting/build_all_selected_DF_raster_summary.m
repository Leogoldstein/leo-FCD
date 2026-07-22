function build_all_selected_DF_raster_summary( ...
        selected_groups, ...
        output_folders, ...
        include_blue_cells)
%BUILD_ALL_SELECTED_DF_RASTER_SUMMARY
%
% Crée une figure DF séparée pour chaque type d'animal.
%
% Entrées :
%   selected_groups
%       Structure contenant les animaux sélectionnés, organisés par type.
%
%   output_folders
%       Cellule contenant un dossier de sortie pour chaque type.
%       L'ordre doit correspondre à :
%
%           fieldnames(selected_groups)
%
%       Ces dossiers peuvent être générés avec :
%
%           output_folders = build_output_folders( ...
%               selected_groups, ...
%               root_folders, ...
%               automatic_selection, ...
%               include_blue_cells);
%
%   include_blue_cells
%       Indique si les cellules électroporées doivent être incluses.
%
% Exemple :
%
%   output_folders = build_output_folders( ...
%       selected_groups, ...
%       root_folders, ...
%       automatic_selection, ...
%       include_blue_cells);
%
%   build_all_selected_DF_raster_summary( ...
%       selected_groups, ...
%       output_folders, ...
%       include_blue_cells);

    %==============================================================%
    % Vérification de selected_groups
    %==============================================================%
    if nargin < 1 || isempty(selected_groups)

        fprintf('Global DF summary: selected_groups vide.\n');
        return;
    end

    if ~isstruct(selected_groups)

        error( ...
            'build_all_selected_DF_raster_summary:InvalidSelectedGroups', ...
            'selected_groups doit être une structure.');
    end

    type_names = fieldnames(selected_groups);
    n_types = numel(type_names);

    if n_types == 0

        fprintf('Global DF summary: aucun type trouvé.\n');
        return;
    end

    %==============================================================%
    % Vérification de output_folders
    %==============================================================%
    if nargin < 2 || isempty(output_folders)

        error( ...
            'build_all_selected_DF_raster_summary:MissingOutputFolders', ...
            ['output_folders doit être fourni. Utiliser ', ...
             'build_output_folders avant cette fonction.']);
    end

    output_folders = normalize_output_folders_DF( ...
        output_folders, ...
        n_types);

    %==============================================================%
    % Vérification de include_blue_cells
    %==============================================================%
    if nargin < 3 || isempty(include_blue_cells)
        include_blue_cells = false;
    end

    include_blue_cells = parse_logical_scalar_DF( ...
        include_blue_cells, ...
        false);

    %==============================================================%
    % Une figure par type
    %==============================================================%
    for t = 1:n_types

        current_type = type_names{t};
        current_animals = selected_groups.(current_type);
        current_output_folder = output_folders{t};

        %==========================================================%
        % Création du dossier de sortie
        %==========================================================%
        if exist(current_output_folder, 'dir') ~= 7

            [mkdir_success, mkdir_message] = mkdir( ...
                current_output_folder);

            if ~mkdir_success

                warning( ...
                    'build_all_selected_DF_raster_summary:FolderCreationFailed', ...
                    ['Impossible de créer le dossier pour le type %s :\n', ...
                     '%s\n%s'], ...
                    current_type, ...
                    current_output_folder, ...
                    mkdir_message);

                continue;
            end
        end

        fprintf('\n');
        fprintf('============================================\n');
        fprintf('GLOBAL DF RASTER SUMMARY\n');
        fprintf('Type: %s\n', current_type);
        fprintf('Output folder: %s\n', current_output_folder);
        fprintf('Include electroporated cells: %d\n', ...
            include_blue_cells);
        fprintf('============================================\n');

        if isempty(current_animals)

            fprintf( ...
                'Aucun animal pour le type %s.\n', ...
                current_type);

            continue;
        end

        %==========================================================%
        % Vérifier si la figure existe avant tout recalcul
        %==========================================================%
        safe_type = sanitize_filename_DF(current_type);

        figure_save_path = fullfile( ...
            current_output_folder, ...
            sprintf( ...
                '%s_all_animals_all_dates_DF_rasters.png', ...
                safe_type));

        if exist(figure_save_path, 'file') == 2

            fprintf([ ...
                'Global DF raster summary already exists, ', ...
                'all processing skipped:\n%s\n'], ...
                figure_save_path);

            continue;
        end

        %==========================================================%
        % Collecter les données uniquement si la figure manque
        %==========================================================%
        records = collect_DF_records( ...
            current_animals, ...
            current_type);

        if isempty(records)

            fprintf( ...
                'Aucun raster DF valide pour le type %s.\n', ...
                current_type);

            continue;
        end

        plot_DF_records( ...
            records, ...
            current_type, ...
            current_output_folder);
    end
end

%==============================================================
% NORMALISER LES DOSSIERS RACINES
%==============================================================
function root_folders = normalize_root_folders_DF( ...
        root_folders, n_types)

    if ischar(root_folders) || ...
            (isstring(root_folders) && isscalar(root_folders))

        root_folders = repmat( ...
            {char(string(root_folders))}, ...
            n_types, ...
            1);

    elseif isstring(root_folders)

        root_folders = cellstr(root_folders(:));

    elseif iscell(root_folders)

        root_folders = root_folders(:);

    else

        error([ ...
            'root_folders doit être un chemin texte ou une cellule ', ...
            'de chemins texte.']);
    end

    if numel(root_folders) == 1 && n_types > 1
        root_folders = repmat(root_folders, n_types, 1);
    end

    if numel(root_folders) ~= n_types
        error([ ...
            'Le nombre de root_folders (%d) doit correspondre au ', ...
            'nombre de types dans selected_groups (%d).'], ...
            numel(root_folders), ...
            n_types);
    end

    for i = 1:n_types

        current_root = root_folders{i};

        if isempty(current_root)
            current_root = pwd;
        end

        current_root = char(string(current_root));

        if exist(current_root, 'dir') ~= 7
            error( ...
                'Dossier racine introuvable pour le type %d : %s', ...
                i, ...
                current_root);
        end

        root_folders{i} = current_root;
    end
end

%==============================================================
% NORMALISER AUTOMATIC_SELECTION
%==============================================================
function automatic_selection = normalize_automatic_selection_DF( ...
        automatic_selection, n_types)

    if iscell(automatic_selection)

        normalized_values = false(numel(automatic_selection), 1);

        for i = 1:numel(automatic_selection)
            normalized_values(i) = parse_logical_scalar_DF( ...
                automatic_selection{i}, false);
        end

        automatic_selection = normalized_values;

    elseif isstring(automatic_selection)

        normalized_values = false(numel(automatic_selection), 1);

        for i = 1:numel(automatic_selection)
            normalized_values(i) = parse_logical_scalar_DF( ...
                automatic_selection(i), false);
        end

        automatic_selection = normalized_values;

    elseif isnumeric(automatic_selection) || ...
            islogical(automatic_selection)

        automatic_selection = ...
            logical(automatic_selection(:));

    else

        error([ ...
            'automatic_selection doit être logique, numérique, ', ...
            'texte ou une cellule.']);
    end

    if numel(automatic_selection) == 1 && n_types > 1
        automatic_selection = repmat( ...
            automatic_selection, ...
            n_types, ...
            1);
    end

    if numel(automatic_selection) ~= n_types
        error([ ...
            'Le nombre de valeurs automatic_selection (%d) doit ', ...
            'correspondre au nombre de types (%d).'], ...
            numel(automatic_selection), ...
            n_types);
    end
end

%==============================================================
% CONVERTIR UNE VALEUR EN LOGIQUE SCALAIRE
%==============================================================
function flag = parse_logical_scalar_DF(value, default_value)

    if nargin < 2
        default_value = false;
    end

    if isempty(value)
        flag = logical(default_value);
        return;
    end

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
        'oui', ...
        'on'});
end

%==============================================================
% COLLECTER TOUS LES RASTERS DF
%==============================================================
function records = collect_DF_records( ...
        current_animals, current_type)

    records = struct( ...
        'type', {}, ...
        'animal', {}, ...
        'animal_index', {}, ...
        'date_index', {}, ...
        'date_name', {}, ...
        'age_text', {}, ...
        'age_number', {}, ...
        'sampling_rate', {}, ...
        'DF', {}, ...
        'isort', {});

    record_counter = 0;

    for k = 1:numel(current_animals)

        animal_struct = current_animals(k);

        animal_name = sprintf('Animal_%d', k);

        if isfield(animal_struct, 'animal_group') && ...
                ~isempty(animal_struct.animal_group)

            animal_name = char(string( ...
                animal_struct.animal_group));
        end

        if ~isfield(animal_struct, 'data') || ...
                isempty(animal_struct.data)

            fprintf('Animal %s: data vide, skip.\n', ...
                animal_name);
            continue;
        end

        data = animal_struct.data;

        if isfield(animal_struct, 'metadata')
            metadata = animal_struct.metadata;
        else
            metadata = struct();
        end

        if isfield(animal_struct, 'ages')
            ages_group = animal_struct.ages;
        else
            ages_group = {};
        end

        num_dates = determine_number_of_dates_DF( ...
            data, metadata, ages_group);

        for m = 1:num_dates

            sampling_rate = extract_sampling_rate_DF( ...
                metadata, m);

            if ~isfinite(sampling_rate) || sampling_rate <= 0

                fprintf( ...
                    ['Animal %s date %d: sampling rate ' ...
                     'invalide, skip.\n'], ...
                    animal_name, m);

                continue;
            end

            [DF_concat, isort_concat] = ...
                get_concat_DF_global(data, m);

            if isempty(DF_concat)
                continue;
            end

            date_name = extract_date_name_DF(metadata, m);
            age_text = extract_age_text_DF(ages_group, m);
            age_number = extract_age_number_DF(age_text);

            record_counter = record_counter + 1;

            records(record_counter).type = current_type;
            records(record_counter).animal = animal_name;
            records(record_counter).animal_index = k;
            records(record_counter).date_index = m;
            records(record_counter).date_name = date_name;
            records(record_counter).age_text = age_text;
            records(record_counter).age_number = age_number;
            records(record_counter).sampling_rate = sampling_rate;
            records(record_counter).DF = DF_concat;
            records(record_counter).isort = isort_concat;
        end
    end

    if isempty(records)
        return;
    end

    %--------------------------------------------------------------
    % Trier d'abord par animal, puis par âge
    %--------------------------------------------------------------
    animal_values = string({records.animal})';
    age_values = [records.age_number]';
    date_values = string({records.date_name})';
    original_indices = (1:numel(records))';

    age_values(~isfinite(age_values)) = inf;

    sorting_table = table( ...
        animal_values, ...
        age_values, ...
        date_values, ...
        original_indices, ...
        'VariableNames', { ...
            'Animal', ...
            'Age', ...
            'Date', ...
            'OriginalIndex'});

    sorting_table = sortrows( ...
        sorting_table, ...
        {'Animal', 'Age', 'Date'}, ...
        {'ascend', 'ascend', 'ascend'});

    records = records(sorting_table.OriginalIndex);
end


%==============================================================
% PLOT GLOBAL DF
%==============================================================
function plot_DF_records( ...
        records, current_type, output_folder)

    nRows = numel(records);

    if nRows == 0
        return;
    end

    safe_type = sanitize_filename_DF(current_type);

    figure_save_path = fullfile( ...
        output_folder, ...
        sprintf( ...
            '%s_all_animals_all_dates_DF_rasters.png', ...
            safe_type));

    if exist(figure_save_path, 'file') == 2

        fprintf( ...
            'Global DF raster summary already exists, skipped:\n%s\n', ...
            figure_save_path);

        return;
    end

    fig = [];

    try
        row_height = 220;
        figure_height = max(700, row_height * nRows);

        fig = figure( ...
            'Color', 'w', ...
            'Units', 'pixels', ...
            'Position', [50 50 1800 figure_height]);

        layout = tiledlayout( ...
            fig, ...
            nRows, ...
            1, ...
            'TileSpacing', 'compact', ...
            'Padding', 'compact');

        for idx = 1:nRows

            current_record = records(idx);

            DF_concat = double(current_record.DF);

            if isempty(DF_concat)
                continue;
            end

            [NCell, Nz] = size(DF_concat);

            if NCell == 0 || Nz == 0
                continue;
            end

            isort_concat = sanitize_isort_DF( ...
                current_record.isort, NCell);

            sampling_rate = current_record.sampling_rate;

            total_time = Nz / sampling_rate;
            t_sec = (0:Nz-1) / sampling_rate;

            A = DF_concat(isort_concat, :);
            A_z = robust_zscore_rows_DF(A);

            ax = nexttile(layout);

            imagesc( ...
                ax, ...
                t_sec, ...
                1:NCell, ...
                A_z);

            axis(ax, 'tight');

            set(ax, ...
                'YDir', 'normal', ...
                'TickLength', [0 0], ...
                'FontSize', 11);

            colormap(ax, parula);
            clim(ax, [0 2]);

            xlim(ax, [0 total_time]);

            ylabel(ax, sprintf('%d neurons', NCell));

            title(ax, sprintf( ...
                '%s | %s | %s', ...
                current_record.animal, ...
                current_record.date_name, ...
                current_record.age_text), ...
                'Interpreter', 'none', ...
                'FontSize', 13, ...
                'FontWeight', 'bold');

            if idx == nRows
                xlabel(ax, 'Time (s)', 'FontSize', 13);
            else
                set(ax, 'XTickLabel', []);
            end
        end

        title(layout, sprintf( ...
            '%s - all selected animals and dates - DF rasters', ...
            current_type), ...
            'Interpreter', 'none', ...
            'FontSize', 18, ...
            'FontWeight', 'bold');

        exportgraphics( ...
            fig, ...
            figure_save_path, ...
            'Resolution', 200);

        fprintf( ...
            'Global DF raster summary saved in:\n%s\n', ...
            figure_save_path);

        close(fig);
        fig = [];

    catch ME

        fprintf( ...
            '\nError for global DF raster summary (%s):\n%s\n', ...
            current_type, ME.message);

        if ~isempty(fig) && ishghandle(fig)
            close(fig);
        end
    end
end


%==============================================================
% RÉCUPÉRER ET CONCATÉNER LES DF DES PLANS
%==============================================================
function [DF_concat, isort_concat] = ...
        get_concat_DF_global(data, m)

    DF_concat = [];
    isort_concat = [];

    if ~isfield(data, 'gcamp_plane') || ...
            ~isstruct(data.gcamp_plane)
        return;
    end

    branch = data.gcamp_plane;

    if isfield(branch, 'DF_gcamp_by_plane') && ...
            numel(branch.DF_gcamp_by_plane) >= m && ...
            ~isempty(branch.DF_gcamp_by_plane{m})

        DF_concat = concat_DF_planes( ...
            branch.DF_gcamp_by_plane{m});

    elseif isfield(branch, 'DF_gcamp') && ...
            numel(branch.DF_gcamp) >= m

        DF_concat = branch.DF_gcamp{m};
    end

    if isempty(DF_concat)
        return;
    end

    ops_concat = [];

    if isfield(branch, 'ops_suite2p_by_plane') && ...
            numel(branch.ops_suite2p_by_plane) >= m && ...
            ~isempty(branch.ops_suite2p_by_plane{m})

        current_ops = branch.ops_suite2p_by_plane{m};

        if iscell(current_ops) && ~isempty(current_ops)
            ops_concat = current_ops{1};
        elseif isstruct(current_ops)
            ops_concat = current_ops;
        end
    end

    if ~isempty(ops_concat)

        try
            [isort_concat, ~, ~] = ...
                raster_processing( ...
                    double(DF_concat), ...
                    ops_concat);

        catch ME
            warning( ...
                'GlobalDFSummary:RasterProcessing', ...
                'Raster sorting failed for date %d: %s', ...
                m, ME.message);

            isort_concat = [];
        end
    end

    isort_concat = sanitize_isort_DF( ...
        isort_concat, size(DF_concat, 1));
end


function DF_concat = concat_DF_planes(DF_planes)

    DF_concat = [];

    if isempty(DF_planes)
        return;
    end

    if ~iscell(DF_planes)

        if isnumeric(DF_planes)
            DF_concat = DF_planes;
        end

        return;
    end

    valid_planes = ~cellfun(@isempty, DF_planes);
    DF_planes = DF_planes(valid_planes);

    if isempty(DF_planes)
        return;
    end

    valid_numeric = cellfun( ...
        @(x) isnumeric(x) && ismatrix(x), ...
        DF_planes);

    DF_planes = DF_planes(valid_numeric);

    if isempty(DF_planes)
        return;
    end

    frame_counts = cellfun( ...
        @(x) size(x, 2), ...
        DF_planes);

    minimum_frame_count = min(frame_counts);

    if minimum_frame_count < 1
        return;
    end

    for p = 1:numel(DF_planes)
        DF_planes{p} = ...
            DF_planes{p}(:, 1:minimum_frame_count);
    end

    DF_concat = cat(1, DF_planes{:});
end


%==============================================================
% HELPERS
%==============================================================
function num_dates = determine_number_of_dates_DF( ...
        data, metadata, ages_group)

    candidates = [];

    if isfield(metadata, 'SamplingRatePlane')
        candidates(end+1) = ...
            numel(metadata.SamplingRatePlane);
    end

    if isfield(metadata, 'DateName')
        candidates(end+1) = ...
            numel(metadata.DateName);
    end

    if ~isempty(ages_group)
        candidates(end+1) = ...
            numel(ages_group);
    end

    if isfield(data, 'gcamp_plane') && ...
            isstruct(data.gcamp_plane)

        if isfield(data.gcamp_plane, 'DF_gcamp_by_plane')
            candidates(end+1) = ...
                numel(data.gcamp_plane.DF_gcamp_by_plane);
        end

        if isfield(data.gcamp_plane, 'DF_gcamp')
            candidates(end+1) = ...
                numel(data.gcamp_plane.DF_gcamp);
        end
    end

    if isempty(candidates)
        num_dates = 0;
    else
        num_dates = max(candidates);
    end
end


function sampling_rate = extract_sampling_rate_DF(metadata, m)

    sampling_rate = NaN;

    if ~isfield(metadata, 'SamplingRatePlane') || ...
            isempty(metadata.SamplingRatePlane) || ...
            numel(metadata.SamplingRatePlane) < m
        return;
    end

    sampling_values = metadata.SamplingRatePlane;

    if iscell(sampling_values)
        current_value = sampling_values{m};
    else
        current_value = sampling_values(m);
    end

    if isempty(current_value)
        return;
    end

    sampling_rate = double(current_value(1));
end


function date_name = extract_date_name_DF(metadata, m)

    date_name = sprintf('Date_%d', m);

    if ~isfield(metadata, 'DateName') || ...
            isempty(metadata.DateName) || ...
            numel(metadata.DateName) < m
        return;
    end

    if iscell(metadata.DateName)
        current_value = metadata.DateName{m};
    else
        current_value = metadata.DateName(m);
    end

    if ~isempty(current_value)
        date_name = char(string(current_value));
    end
end


function age_text = extract_age_text_DF(ages_group, m)

    age_text = 'Age unknown';

    if isempty(ages_group) || numel(ages_group) < m
        return;
    end

    if iscell(ages_group)
        current_value = ages_group{m};
    else
        current_value = ages_group(m);
    end

    if ~isempty(current_value)
        age_text = char(string(current_value));
    end
end


function age_number = extract_age_number_DF(age_value)

    age_number = NaN;

    if isempty(age_value)
        return;
    end

    age_text = char(string(age_value));

    token = regexp( ...
        age_text, ...
        '\d+(\.\d+)?', ...
        'match', ...
        'once');

    if ~isempty(token)
        age_number = str2double(token);
    end
end


function isort = sanitize_isort_DF(isort, NCell)

    if isempty(isort)
        isort = (1:NCell)';
        return;
    end

    isort = double(isort(:));

    invalid_values = ...
        ~isfinite(isort) | ...
        isort < 1 | ...
        isort > NCell;

    isort(invalid_values) = [];

    if numel(isort) ~= NCell || ...
            numel(unique(isort)) ~= NCell

        isort = (1:NCell)';
    end
end


function Z = robust_zscore_rows_DF(A)

    Z = nan(size(A));

    for i = 1:size(A, 1)

        x = A(i, :);

        center_value = median(x, 'omitnan');
        scale_value = 1.4826 * mad(x, 1);

        if isfinite(scale_value) && scale_value > eps
            Z(i, :) = ...
                (x - center_value) / scale_value;
        else
            Z(i, :) = x - center_value;
        end
    end
end


function safe_name = sanitize_filename_DF(input_name)

    safe_name = char(string(input_name));

    safe_name = regexprep( ...
        safe_name, ...
        '[<>:"/\\|?*]', ...
        '_');

    safe_name = strrep(safe_name, ' ', '_');
end