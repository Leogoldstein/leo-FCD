function [selected_groups, metadata_table] = create_metadata(selected_groups)

    metadata_table = table();

    if nargin < 1 || isempty(selected_groups)
        return;
    end

    save_to_excel = true;
    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            fprintf('\n==============================\n');
            fprintf('Metadata extraction\n');
            fprintf('Type: %s\n', current_type);
            fprintf('Animal %d / %d: %s\n', ...
                k, ...
                numel(selected_groups.(current_type)), ...
                char(string( ...
                    selected_groups.(current_type)(k).animal)));
            fprintf('==============================\n');

            % Réinitialiser les métadonnées de l'animal courant
            selected_groups.(current_type)(k).metadata = ...
                empty_metadata_struct();

            current_paths = ...
                selected_groups.(current_type)(k).paths;

            % ==========================================================
            % Dossier de l'animal
            % ==========================================================
            if isfield(current_paths, 'animal')
                current_ani_path_group = ...
                    force_char_path(current_paths.animal);
            else
                current_ani_path_group = '';
            end

            % ==========================================================
            % Liste des XML
            % ==========================================================
            if isfield(current_paths, 'xml') && ...
                    ~isempty(current_paths.xml)

                current_xml_group = current_paths.xml;

            else

                current_xml_group = {};

            end

            if isrow(current_xml_group)
                current_xml_group = current_xml_group(:);
            end

            nXml = numel(current_xml_group);

            % ==========================================================
            % Dossiers GCaMP associés aux enregistrements
            % ==========================================================
            if isfield(current_paths, 'gcamp_root') && ...
                    ~isempty(current_paths.gcamp_root)

                this_group_folders = current_paths.gcamp_root;

            else

                this_group_folders = {};

            end

            if isrow(this_group_folders)
                this_group_folders = this_group_folders(:);
            end

            % ==========================================================
            % Chemin du fichier groupé
            % ==========================================================
            group_output_path = '';

            if save_to_excel && ...
                    ~isempty(current_ani_path_group)

                group_output_path = fullfile( ...
                    current_ani_path_group, ...
                    'metadata_results_group.xlsx');
            end

            % ==========================================================
            % Charger l'ancien fichier groupé si disponible
            % ==========================================================
            group_table = table();

            group_file_existed = ...
                save_to_excel && ...
                ~isempty(group_output_path) && ...
                exist(group_output_path, 'file') == 2;

            if group_file_existed

                fprintf( ...
                    'Existing grouped metadata found -> checking: %s\n', ...
                    group_output_path);

                try

                    group_table = readtable( ...
                        group_output_path, ...
                        'VariableNamingRule', 'preserve');

                    group_table = ...
                        normalize_metadata_table(group_table);

                    fprintf( ...
                        'Existing grouped metadata loaded: %d rows\n', ...
                        height(group_table));

                catch ME

                    warning( ...
                        ['Impossible de relire ', ...
                         'metadata_results_group.xlsx : %s'], ...
                        ME.message);

                    fprintf([ ...
                        'Grouped metadata ignored, ', ...
                        'will rebuild from current selection only.\n']);

                    group_table = table();

                    % Le fichier devra être recréé
                    group_file_existed = false;

                end
            end

            % Indique si au moins une nouvelle ligne est ajoutée
            group_table_modified = false;

            % ==========================================================
            % Boucle sur les XML sélectionnés
            % ==========================================================
            for idx = 1:nXml

                xml_file = ...
                    force_char_path(current_xml_group{idx});

               % ======================================================
                % Nom de la date
                % ======================================================
                date_name = '';
                
                if isfield(selected_groups.(current_type)(k), 'dates') && ...
                        numel(selected_groups.(current_type)(k).dates) >= idx && ...
                        ~isempty(selected_groups.(current_type)(k).dates{idx})
                
                    date_name = force_char_path( ...
                        selected_groups.(current_type)(k).dates{idx});
                end

                % ======================================================
                % Dossier local de l'enregistrement
                % ======================================================
                this_folder = '';

                if idx <= numel(this_group_folders) && ...
                        ~isempty(this_group_folders{idx})

                    this_folder = ...
                        force_char_path( ...
                            this_group_folders{idx});
                end

                output_path_single = '';

                if ~isempty(this_folder)

                    if ~exist(this_folder, 'dir')
                        mkdir(this_folder);
                    end

                    output_path_single = fullfile( ...
                        this_folder, ...
                        'metadata_results.xlsx');
                end

                loaded_from_single_file = false;
                rowTable = table();

                % ======================================================
                % 1) Relire metadata_results.xlsx local s'il existe
                % ======================================================
                if save_to_excel && ...
                        ~isempty(output_path_single) && ...
                        exist(output_path_single, 'file') == 2

                    fprintf( ...
                        'Metadata rec %d already exists -> checking: %s\n', ...
                        idx, ...
                        output_path_single);

                    try

                        rowTable = readtable( ...
                            output_path_single, ...
                            'VariableNamingRule', 'preserve');

                        rowTable = ...
                            normalize_metadata_table(rowTable);

                        % Un fichier local doit contenir une seule ligne
                        if height(rowTable) > 1
                            rowTable = rowTable(1,:);
                        end

                        % Compléter DateName si elle est absente
                        if ~isempty(rowTable) && ...
                                isempty_value( ...
                                    rowTable.DateName{1}) && ...
                                ~isempty(date_name)

                            rowTable.DateName{1} = date_name;
                        end

                        loaded_from_single_file = true;

                        fprintf( ...
                            'Metadata rec %d loaded from Excel\n', ...
                            idx);

                    catch ME

                        warning( ...
                            'Impossible de relire %s : %s', ...
                            output_path_single, ...
                            ME.message);

                        fprintf( ...
                            'Deleting corrupted metadata Excel: %s\n', ...
                            output_path_single);

                        try
                            delete(output_path_single);
                        catch
                        end

                        rowTable = table();
                        loaded_from_single_file = false;

                    end
                end

                % ======================================================
                % 2) Lire le XML si aucun fichier local valide
                % ======================================================
                if ~loaded_from_single_file

                    if isempty(xml_file) || ...
                            exist(xml_file, 'file') ~= 2

                        warning( ...
                            ['XML introuvable | Type %s | ', ...
                             'Animal %s | Date %s'], ...
                            current_type, ...
                            char(string( ...
                                selected_groups. ...
                                (current_type)(k).animal)), ...
                            char(string(date_name)));

                        continue;
                    end

                    meta_xml = find_key_value(xml_file);
                    meta_xml.DateName = date_name;

                    rowTable = struct2table( ...
                        meta_xml, ...
                        'AsArray', true);

                    rowTable = ...
                        normalize_metadata_table(rowTable);

                    if save_to_excel && ...
                            ~isempty(output_path_single)

                        writetable( ...
                            rowTable, ...
                            output_path_single, ...
                            'FileType', 'spreadsheet');

                        fprintf( ...
                            'Metadata rec %d saved -> %s\n', ...
                            idx, ...
                            output_path_single);
                    end
                end

                if isempty(rowTable) || height(rowTable) < 1
                    warning( ...
                        'Aucune métadonnée valide pour rec %d.', ...
                        idx);
                    continue;
                end

                rowTable = normalize_metadata_table(rowTable);

                % ======================================================
                % 3) Ajouter dans selected_groups.metadata
                % ======================================================
                selected_groups.(current_type)(k).metadata = ...
                    add_row_to_metadata_struct( ...
                        selected_groups. ...
                            (current_type)(k).metadata, ...
                        rowTable, ...
                        idx);

                % ======================================================
                % 4) Ajouter au tableau récapitulatif global
                % ======================================================
                current_mtor = '';

                if isfield( ...
                        selected_groups.(current_type)(k), ...
                        'line')

                    current_mtor = char(string( ...
                        selected_groups. ...
                            (current_type)(k).line));
                end

                current_animal = '';

                if isfield( ...
                        selected_groups.(current_type)(k), ...
                        'animal')

                    current_animal = char(string( ...
                        selected_groups. ...
                            (current_type)(k).animal));
                end

                summary_row = table( ...
                    string(current_type), ...
                    string(current_mtor), ...
                    string(current_animal), ...
                    string(get_metadata_value( ...
                        rowTable, 'DateName')), ...
                    get_metadata_value( ...
                        rowTable, 'NumPlanes'), ...
                    get_metadata_value( ...
                        rowTable, 'OpticalZoom'), ...
                    get_metadata_value( ...
                        rowTable, 'SamplingRatePlane'), ...
                    get_metadata_value( ...
                        rowTable, 'TimeMinutes'), ...
                    'VariableNames', { ...
                        'Type', ...
                        'mTOR', ...
                        'Animal', ...
                        'Date', ...
                        'NumPlanes', ...
                        'OpticalZoom', ...
                        'SamplingRate_Hz', ...
                        'RecordingDuration_min'});

                if isempty(metadata_table)

                    metadata_table = summary_row;

                else

                    metadata_table = [ ...
                        metadata_table; ...
                        summary_row]; %#ok<AGROW>

                end

                % ======================================================
                % 5) Ajouter au fichier groupé seulement si date absente
                % ======================================================
                if isempty(group_table)

                    group_table = rowTable;
                    group_table_modified = true;

                    current_date = ...
                        get_metadata_value(rowTable, 'DateName');

                    fprintf( ...
                        'Adding metadata for new date: %s\n', ...
                        char(string(current_date)));

                else

                    group_table = ...
                        normalize_metadata_table(group_table);

                    current_date = ...
                        get_metadata_value(rowTable, 'DateName');

                    if isempty_value(current_date)

                        warning([ ...
                            'DateName vide pour rec %d : ', ...
                            'ligne non ajoutée au fichier groupé.'], ...
                            idx);

                    else

                        date_col = group_table.DateName;

                        if ~iscell(date_col)
                            date_col = num2cell(date_col);
                        end

                        idx_same_date = ...
                            strcmp( ...
                                string(date_col), ...
                                string(current_date));

                        if any(idx_same_date)

                            fprintf( ...
                                ['Metadata already present for ', ...
                                 'date %s -> skipped\n'], ...
                                char(string(current_date)));

                        else

                            group_table = [ ...
                                group_table; ...
                                rowTable]; %#ok<AGROW>

                            group_table_modified = true;

                            fprintf( ...
                                'Adding metadata for new date: %s\n', ...
                                char(string(current_date)));

                        end
                    end
                end
            end

            % ==========================================================
            % Sauver uniquement si le fichier doit être créé ou modifié
            % ==========================================================
            if save_to_excel && ...
                    ~isempty(current_ani_path_group) && ...
                    ~isempty(group_table)

                if ~exist(current_ani_path_group, 'dir')
                    mkdir(current_ani_path_group);
                end

                selected_groups.(current_type)(k).metadata.source_file = ...
                    group_output_path;

                if ~group_file_existed || group_table_modified

                    group_table = ...
                        normalize_metadata_table(group_table);

                    writetable( ...
                        group_table, ...
                        group_output_path, ...
                        'FileType', 'spreadsheet');

                    if group_file_existed

                        fprintf( ...
                            'Grouped metadata updated -> %s\n', ...
                            group_output_path);

                    else

                        fprintf( ...
                            'Grouped metadata created -> %s\n', ...
                            group_output_path);

                    end

                else

                    fprintf( ...
                        'Grouped metadata unchanged -> writing skipped\n');

                end
            end
        end
    end
end

%% ========================================================================
function metadata = empty_metadata_struct()

    fields = metadata_field_list();

    metadata = struct();

    for i = 1:numel(fields)
        metadata.(fields{i}) = {};
    end

    metadata.source_file = '';

end

%% ========================================================================
function fields = metadata_field_list()

    fields = { ...
        'DateName', ...
        'RecordingTime', ...
        'ActiveMode', ...
        'BitDepth', ...
        'SamplingRate', ...
        'FramePeriod', ...
        'SamplingRatePlane', ...
        'InterplaneDelay_s', ...
        'PixelsPerLine', ...
        'LinesPerFrame', ...
        'ImageSize', ...
        'DwellTime_us', ...
        'ScanLinePeriod_s', ...
        'SamplesPerPixel', ...
        'OpticalZoom', ...
        'ObjectiveLens', ...
        'ObjectiveLensMag', ...
        'ObjectiveLensNA', ...
        'PixelSizeX_um', ...
        'PixelSizeY_um', ...
        'PixelSize_um', ...
        'PositionX_um', ...
        'PositionY_um', ...
        'PositionZ', ...
        'NumPlanes', ...
        'ZStep_um', ...
        'ZMin_um', ...
        'ZMax_um', ...
        'LaserWavelength_nm', ...
        'LaserPower_Pockels', ...
        'LaserPowerByPlane_Pockels', ...
        'PMTGain_Red', ...
        'PMTGain_Green', ...
        'PMTGain_Blue', ...
        'TimeMinutes', ...
        'NumFrames', ...
        'ChannelNames', ...
        'NumChannels', ...
        'BidirectionalZ'};

end

%% ========================================================================
function T = normalize_metadata_table(T)

    expected_fields = metadata_field_list();

    T = remove_unused_metadata_columns(T);

    if isempty(T)

        T = cell2table( ...
            cell(0, numel(expected_fields)), ...
            'VariableNames', expected_fields);

        return;
    end

    nRows = height(T);

    % Ajouter les colonnes manquantes
    for i = 1:numel(expected_fields)

        field = expected_fields{i};

        if ~any(strcmp( ...
                T.Properties.VariableNames, ...
                field))

            T.(field) = cell(nRows, 1);
        end
    end

    % Supprimer les colonnes non officielles
    current_fields = T.Properties.VariableNames;

    for i = 1:numel(current_fields)

        field = current_fields{i};

        if ~any(strcmp(expected_fields, field))
            T(:, field) = [];
        end
    end

    % Réordonner les colonnes
    T = T(:, expected_fields);

    % Convertir chaque colonne en cellule pour permettre
    % la concaténation de tableaux hétérogènes
    for i = 1:numel(expected_fields)

        field = expected_fields{i};

        if ~iscell(T.(field))
            T.(field) = num2cell(T.(field));
        end
    end
end

%% ========================================================================
function metadata = add_row_to_metadata_struct(metadata, T, idx)

    wanted_fields = metadata_field_list();

    T = normalize_metadata_table(T);

    for i = 1:numel(wanted_fields)

        field = wanted_fields{i};

        if ~isfield(metadata, field)
            metadata.(field) = {};
        end

        if isempty(T) || height(T) < 1

            metadata.(field){idx,1} = [];

        else

            metadata.(field){idx,1} = T.(field){1};

        end
    end
end

%% ========================================================================
function T = remove_unused_metadata_columns(T)

    remove_fields = { ...
        'RastersPerFrame', ...
        'LaserPower_1040', ...
        'LaserPowerByPlane_1040', ...
        'PMTGainByPlane_Red', ...
        'PMTGainByPlane_Green', ...
        'PMTGainByPlane_Blue'};

    for i = 1:numel(remove_fields)

        field = remove_fields{i};

        if any(strcmp( ...
                T.Properties.VariableNames, ...
                field))

            T(:, field) = [];

        end
    end
end

%% ========================================================================
function tf = isempty_value(x)

    if isempty(x)

        tf = true;

    elseif isstring(x)

        tf = all(strlength(x) == 0);

    elseif ischar(x)

        tf = isempty(strtrim(x));

    elseif iscell(x)

        tf = isempty(x) || isempty_value(x{1});

    elseif ismissing(x)

        tf = true;

    else

        tf = false;

    end
end

%% ========================================================================
function path_char = force_char_path(path_in)

    path_char = path_in;

    if isempty(path_char)
        path_char = '';
        return;
    end

    if istable(path_char)
        path_char = path_char{1,1};
    end

    if iscell(path_char)
        path_char = path_char{1};
    end

    if isstring(path_char)
        path_char = char(path_char);
    end

    if iscategorical(path_char)
        path_char = char(path_char);
    end

    if ~ischar(path_char)
        error( ...
            'Chemin invalide : type %s', ...
            class(path_char));
    end
end

%% ========================================================================
function value = get_metadata_value(T, field)

    value = [];

    if isempty(T) || height(T) < 1
        return;
    end

    if ~any(strcmp( ...
            T.Properties.VariableNames, ...
            field))

        return;
    end

    current_value = T.(field);

    if iscell(current_value)

        if ~isempty(current_value)
            value = current_value{1};
        end

    else

        value = current_value(1);

    end
end