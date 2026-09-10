function selected_groups = build_output_folders( ...
        selected_groups, ...
        root_folders, ...
        automatic_selection, ...
        include_electroporated, ...
        age_group)

    %==============================================================%
    % Vérification de selected_groups
    %==============================================================%
    if nargin < 1 || ...
            isempty(selected_groups)

        fprintf( ...
            'Output folders: selected_groups vide.\n');

        return;
    end


    if ~isstruct(selected_groups)

        error( ...
            'build_output_folders:InvalidSelectedGroups', ...
            'selected_groups doit être une structure.');
    end


    %==============================================================%
    % Types
    %==============================================================%
    type_names = ...
        fieldnames(selected_groups);


    n_types = ...
        numel(type_names);


    if n_types == 0

        fprintf( ...
            'Output folders: aucun type trouvé.\n');

        return;
    end


    %==============================================================%
    % Valeurs par défaut
    %==============================================================%
    if nargin < 2 || ...
            isempty(root_folders)

        root_folders = ...
            repmat( ...
                {pwd}, ...
                n_types, ...
                1);
    end


    if nargin < 3 || ...
            isempty(automatic_selection)

        automatic_selection = ...
            struct();


        for t = 1:n_types

            automatic_selection.(type_names{t}) = ...
                false;
        end
    end


    if ~isstruct(automatic_selection)

        error( ...
            'build_output_folders:InvalidAutomaticSelection', ...
            ['automatic_selection doit être une structure ', ...
             'indexée par type expérimental.']);
    end


    if nargin < 4 || ...
            isempty(include_electroporated)

        include_electroporated = ...
            false;
    end


    if nargin < 5 || ...
            isempty(age_group)

        age_group = ...
            struct();
    end


    if ~isstruct(age_group)

        error( ...
            'build_output_folders:InvalidAgeGroup', ...
            ['age_group doit être une structure ', ...
             'indexée par type expérimental.']);
    end


    %==============================================================%
    % Normalisation
    %==============================================================%
    root_folders = ...
        normalize_root_folders_DF( ...
            root_folders, ...
            n_types);


    include_electroporated = ...
        parse_logical_scalar_DF( ...
            include_electroporated, ...
            false);


    %==============================================================%
    % Boucle types
    %==============================================================%
    for t = 1:n_types

        current_type = ...
            type_names{t};


        current_root_folder = ...
            root_folders{t};


        %==========================================================%
        % Automatic selection
        %==========================================================%
        if ~isfield( ...
                automatic_selection, ...
                current_type)

            warning( ...
                'build_output_folders:MissingAutomaticSelection', ...
                'automatic_selection.%s absent. false utilisé.', ...
                current_type);


            current_automatic_selection = ...
                false;

        else

            current_automatic_selection = ...
                automatic_selection.(current_type);
        end


        current_automatic_selection = ...
            parse_logical_scalar_DF( ...
                current_automatic_selection, ...
                false);


        %==========================================================%
        % Groupe d'âge
        %
        % Utilisé directement.
        % Aucun calcul à partir de l'âge des animaux.
        %==========================================================%
        current_age_group = ...
            '';


        if isfield( ...
                age_group, ...
                current_type)

            current_age_group = ...
                age_group.(current_type);
        end


        %==========================================================%
        % Vérification du groupe d'âge
        %==========================================================%
        if isempty(current_age_group)

            warning( ...
                'build_output_folders:MissingAgeGroup', ...
                ['age_group.%s est vide. ', ...
                 'Aucun output folder ne sera créé pour ce type.'], ...
                current_type);

            continue;
        end


        if ~strcmpi( ...
                current_age_group, ...
                'Development') && ...
                ~strcmpi( ...
                    current_age_group, ...
                    'Adult')

            error( ...
                'build_output_folders:InvalidAgeGroupValue', ...
                ['age_group.%s doit être ', ...
                 '''Development'' ou ''Adult''.'], ...
                current_type);
        end


        %----------------------------------------------------------%
        % Racine Summary plots
        %----------------------------------------------------------%
        summary_root_folder = ...
            fullfile( ...
                current_root_folder, ...
                'Summary plots');


        %----------------------------------------------------------%
        % Sous-dossier selon mode
        %----------------------------------------------------------%
        summary_subfolder = ...
            get_summary_subfolder_DF( ...
                current_automatic_selection, ...
                include_electroporated);


        current_output_root = ...
            fullfile( ...
                summary_root_folder, ...
                summary_subfolder);


        %----------------------------------------------------------%
        % Dossier Development ou Adult
        %----------------------------------------------------------%
        current_age_folder = ...
            fullfile( ...
                current_output_root, ...
                current_age_group);


        if exist( ...
                current_age_folder, ...
                'dir') ~= 7

            mkdir( ...
                current_age_folder);
        end


        %==========================================================%
        % Animaux
        %==========================================================%
        num_animals = ...
            numel( ...
                selected_groups.(current_type));


        for k = 1:num_animals

            animal_struct = ...
                selected_groups.(current_type)(k);


            %------------------------------------------------------%
            % Vérifier dates
            %------------------------------------------------------%
            if ~isfield( ...
                    animal_struct, ...
                    'dates') || ...
                    isempty(animal_struct.dates)

                warning( ...
                    'build_output_folders:MissingDates', ...
                    ['%s | animal %d : aucune date disponible. ', ...
                     'paths.output_folders sera vide.'], ...
                    current_type, ...
                    k);


                selected_groups.(current_type)(k). ...
                    paths.output_folders = ...
                    {};

                continue;
            end


            %------------------------------------------------------%
            % Identité
            %------------------------------------------------------%
            current_line = ...
                animal_struct.line;


            current_animal = ...
                animal_struct.animal;


            current_dates = ...
                animal_struct.dates;


            %------------------------------------------------------%
            % Nombre de recordings
            %
            % Déduit uniquement du nombre de dates.
            %------------------------------------------------------%
            n_recordings = ...
                numel(current_dates);


            current_output_folders = ...
                cell( ...
                    n_recordings, ...
                    1);


            %======================================================%
            % Recordings
            %======================================================%
            for m = 1:n_recordings

                %--------------------------------------------------%
                % Date
                %--------------------------------------------------%
                if iscell(current_dates)

                    current_date = ...
                        current_dates{m};

                else

                    current_date = ...
                        current_dates(m);
                end


                %--------------------------------------------------%
                % Dossier final
                %
                % ...\<Development/Adult>\<line>\<animal>\<date>
                %--------------------------------------------------%
                current_output_folders{m} = ...
                    fullfile( ...
                        current_age_folder, ...
                        char(string(current_line)), ...
                        char(string(current_animal)), ...
                        char(string(current_date)));


                %--------------------------------------------------%
                % Création du dossier
                %--------------------------------------------------%
                if exist( ...
                        current_output_folders{m}, ...
                        'dir') ~= 7

                    mkdir( ...
                        current_output_folders{m});
                end
            end


            %======================================================%
            % Sauvegarder dans paths
            %======================================================%
            selected_groups.(current_type)(k). ...
                paths.output_folders = ...
                current_output_folders;
        end
    end
end


%==========================================================================%
% HELPER : normaliser les dossiers racines
%==========================================================================%
function root_folders = ...
    normalize_root_folders_DF( ...
        root_folders, ...
        n_types)

    if nargin < 2 || ...
            isempty(n_types) || ...
            n_types < 1

        root_folders = {};
        return;
    end


    if ischar(root_folders)

        root_folders = ...
            {root_folders};


    elseif isstring(root_folders)

        root_folders = ...
            cellstr( ...
                root_folders(:));


    elseif iscell(root_folders)

        root_folders = ...
            root_folders(:);


    else

        error( ...
            'build_output_folders:InvalidRootFolders', ...
            ['root_folders doit être un char, un string, ', ...
             'un string array ou une cellule.']);
    end


    for i = 1:numel(root_folders)

        current_folder = ...
            root_folders{i};


        if isstring(current_folder)

            if ~isscalar(current_folder)

                error( ...
                    'build_output_folders:InvalidRootFolderString', ...
                    ['Chaque élément de root_folders doit contenir ', ...
                     'un seul chemin.']);
            end


            current_folder = ...
                char(current_folder);
        end


        if ~ischar(current_folder)

            error( ...
                'build_output_folders:InvalidRootFolderElement', ...
                ['Chaque élément de root_folders doit être un char ', ...
                 'ou un string scalaire.']);
        end


        current_folder = ...
            strtrim(current_folder);


        if isempty(current_folder)

            current_folder = ...
                pwd;
        end


        root_folders{i} = ...
            current_folder;
    end


    if isempty(root_folders)

        root_folders = ...
            repmat( ...
                {pwd}, ...
                n_types, ...
                1);


    elseif numel(root_folders) == 1 && ...
            n_types > 1

        root_folders = ...
            repmat( ...
                root_folders, ...
                n_types, ...
                1);


    elseif numel(root_folders) ~= n_types

        error( ...
            'build_output_folders:RootFolderCountMismatch', ...
            ['Le nombre de dossiers racines (%d) doit être égal ', ...
             'au nombre de types (%d), ou être égal à 1.'], ...
            numel(root_folders), ...
            n_types);
    end
end


%==========================================================================%
% HELPER : convertir en logique scalaire
%==========================================================================%
function logical_value = ...
    parse_logical_scalar_DF( ...
        input_value, ...
        default_value)

    if nargin < 2 || ...
            isempty(default_value)

        default_value = ...
            false;
    end


    default_value = ...
        logical( ...
            default_value(1));


    if isempty(input_value)

        logical_value = ...
            default_value;

        return;
    end


    if iscell(input_value)

        if numel(input_value) ~= 1

            error( ...
                'build_output_folders:NonScalarLogicalCell', ...
                'La cellule à convertir doit contenir une seule valeur.');
        end


        logical_value = ...
            parse_logical_scalar_DF( ...
                input_value{1}, ...
                default_value);

        return;
    end


    if islogical(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarLogical', ...
                'La valeur logique doit être scalaire.');
        end


        logical_value = ...
            input_value;

        return;
    end


    if isnumeric(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarNumericLogical', ...
                'La valeur numérique à convertir doit être scalaire.');
        end


        if ~isfinite(input_value)

            logical_value = ...
                default_value;

            return;
        end


        logical_value = ...
            input_value ~= 0;

        return;
    end


    if isstring(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarStringLogical', ...
                'Le string à convertir doit être scalaire.');
        end


        input_value = ...
            char(input_value);
    end


    if ischar(input_value)

        normalized_value = ...
            lower( ...
                strtrim(input_value));


        true_values = { ...
            'true', ...
            'yes', ...
            'oui', ...
            'on', ...
            '1'};


        false_values = { ...
            'false', ...
            'no', ...
            'non', ...
            'off', ...
            '0'};


        if any( ...
                strcmp( ...
                    normalized_value, ...
                    true_values))

            logical_value = ...
                true;

            return;
        end


        if any( ...
                strcmp( ...
                    normalized_value, ...
                    false_values))

            logical_value = ...
                false;

            return;
        end


        logical_value = ...
            default_value;

        return;
    end


    logical_value = ...
        default_value;
end


%==========================================================================%
% HELPER : nom du sous-dossier summary
%==========================================================================%
function summary_subfolder = ...
    get_summary_subfolder_DF( ...
        automatic_selection, ...
        include_electroporated)

    automatic_selection = ...
        parse_logical_scalar_DF( ...
            automatic_selection, ...
            false);


    include_electroporated = ...
        parse_logical_scalar_DF( ...
            include_electroporated, ...
            false);


    if automatic_selection && ...
            include_electroporated

        summary_subfolder = ...
            'Pre-selection electroporated cells';


    elseif automatic_selection && ...
            ~include_electroporated

        summary_subfolder = ...
            'Pre-selection GCaMP only';


    elseif ~automatic_selection && ...
            include_electroporated

        summary_subfolder = ...
            'Manual selection electroporated cells';


    else

        summary_subfolder = ...
            'Manual selection GCaMP only';
    end
end