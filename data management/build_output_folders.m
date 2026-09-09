function selected_groups = build_output_folders( ...
        selected_groups, ...
        root_folders, ...
        automatic_selection, ...
        include_electroporated)

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
    % Paramètre période
    %==============================================================%

    development_max_age = ...
        15;


    %==============================================================%
    % Boucle types
    %==============================================================%

    for t = 1:n_types

        current_type = ...
            type_names{t};
    
    
        current_root_folder = ...
            root_folders{t};
    
    
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
        % Dossiers Development / Adult
        %----------------------------------------------------------%

        development_folder = ...
            fullfile( ...
                current_output_root, ...
                'Development');


        adult_folder = ...
            fullfile( ...
                current_output_root, ...
                'Adult');


        if exist( ...
                development_folder, ...
                'dir') ~= 7

            mkdir( ...
                development_folder);
        end


        if exist( ...
                adult_folder, ...
                'dir') ~= 7

            mkdir( ...
                adult_folder);
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
            % Vérifier ages
            %------------------------------------------------------%

            if ~isfield( ...
                    animal_struct, ...
                    'ages') || ...
                    isempty(animal_struct.ages)

                warning( ...
                    'build_output_folders:MissingAges', ...
                    ['%s | animal %d : aucun âge disponible. ' ...
                     'paths.output_folders sera vide.'], ...
                    current_type, ...
                    k);


                selected_groups.(current_type)(k). ...
                    paths.output_folders = ...
                    {};

                continue;
            end


            %------------------------------------------------------%
            % Vérifier dates
            %------------------------------------------------------%

            if ~isfield( ...
                    animal_struct, ...
                    'dates') || ...
                    isempty(animal_struct.dates)

                warning( ...
                    'build_output_folders:MissingDates', ...
                    ['%s | animal %d : aucune date disponible. ' ...
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


            current_ages = ...
                animal_struct.ages;


            current_dates = ...
                animal_struct.dates;


            %------------------------------------------------------%
            % Nombre de recordings
            %------------------------------------------------------%

            n_recordings = ...
                numel(current_ages);


            if numel(current_dates) ~= n_recordings

                warning( ...
                    'build_output_folders:AgeDateCountMismatch', ...
                    ['%s | animal %s : %d âges mais %d dates. ' ...
                     'Le nombre d''âges est utilisé.'], ...
                    current_type, ...
                    char(string(current_animal)), ...
                    n_recordings, ...
                    numel(current_dates));
            end


            current_output_folders = ...
                cell( ...
                    n_recordings, ...
                    1);


            %======================================================%
            % Recordings
            %======================================================%

            for m = 1:n_recordings

                %--------------------------------------------------%
                % Age
                %--------------------------------------------------%

                if iscell(current_ages)

                    current_age = ...
                        current_ages{m};

                else

                    current_age = ...
                        current_ages(m);
                end


                age_value = ...
                    parse_age_for_output_folder( ...
                        current_age);


                %--------------------------------------------------%
                % Age invalide
                %--------------------------------------------------%

                if ~isfinite(age_value)

                    warning( ...
                        'build_output_folders:InvalidAge', ...
                        ['%s | animal %s | recording %d : ' ...
                         'âge non interprétable.'], ...
                        current_type, ...
                        char(string(current_animal)), ...
                        m);


                    current_output_folders{m} = ...
                        '';

                    continue;
                end


                %--------------------------------------------------%
                % Date
                %--------------------------------------------------%

                if m > numel(current_dates)

                    warning( ...
                        'build_output_folders:MissingRecordingDate', ...
                        ['%s | animal %s | recording %d : ' ...
                         'date absente.'], ...
                        current_type, ...
                        char(string(current_animal)), ...
                        m);


                    current_output_folders{m} = ...
                        '';

                    continue;
                end


                if iscell(current_dates)

                    current_date = ...
                        current_dates{m};

                else

                    current_date = ...
                        current_dates(m);
                end


                %--------------------------------------------------%
                % Choisir Development / Adult
                %--------------------------------------------------%

                if age_value <= development_max_age

                    current_output_folder = ...
                        development_folder;

                else

                    current_output_folder = ...
                        adult_folder;
                end


                %--------------------------------------------------%
                % Dossier final du recording
                %
                % ...\<periode>\<line>\<animal>\<date>
                %--------------------------------------------------%

                current_output_folders{m} = ...
                    fullfile( ...
                        current_output_folder, ...
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
% HELPER : âge -> valeur numérique
%==========================================================================%
function age_value = ...
    parse_age_for_output_folder( ...
        age_raw)

    age_value = ...
        NaN;


    if isempty(age_raw)
        return;
    end


    %----------------------------------------------------------------------%
    % Numérique
    %----------------------------------------------------------------------%

    if isnumeric(age_raw) || ...
            islogical(age_raw)

        age_raw = ...
            double(age_raw);


        if isscalar(age_raw) && ...
                isfinite(age_raw)

            age_value = ...
                age_raw;
        end

        return;
    end


    %----------------------------------------------------------------------%
    % Cellule
    %----------------------------------------------------------------------%

    if iscell(age_raw)

        if ~isempty(age_raw)

            age_value = ...
                parse_age_for_output_folder( ...
                    age_raw{1});
        end

        return;
    end


    %----------------------------------------------------------------------%
    % Texte
    %
    % P10 -> 10
    % P15 -> 15
    % P30 -> 30
    %----------------------------------------------------------------------%

    age_text = ...
        char( ...
            string(age_raw));


    token = ...
        regexp( ...
            age_text, ...
            '[-+]?\d*\.?\d+', ...
            'match', ...
            'once');


    if ~isempty(token)

        age_value = ...
            str2double(token);
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


    %----------------------------------------------------------------------%
    % Conversion vers cellule
    %----------------------------------------------------------------------%

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


    %----------------------------------------------------------------------%
    % Validation
    %----------------------------------------------------------------------%

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


    %----------------------------------------------------------------------%
    % Adaptation au nombre de types
    %----------------------------------------------------------------------%

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


    %----------------------------------------------------------------------%
    % Cellule
    %----------------------------------------------------------------------%

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


    %----------------------------------------------------------------------%
    % Logique
    %----------------------------------------------------------------------%

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


    %----------------------------------------------------------------------%
    % Numérique
    %----------------------------------------------------------------------%

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


    %----------------------------------------------------------------------%
    % String
    %----------------------------------------------------------------------%

    if isstring(input_value)

        if ~isscalar(input_value)

            error( ...
                'build_output_folders:NonScalarStringLogical', ...
                'Le string à convertir doit être scalaire.');
        end


        input_value = ...
            char(input_value);
    end


    %----------------------------------------------------------------------%
    % Texte
    %----------------------------------------------------------------------%

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


        warning( ...
            'build_output_folders:UnknownLogicalText', ...
            ['Valeur logique textuelle non reconnue : "%s". ', ...
             'La valeur par défaut est utilisée.'], ...
            input_value);


        logical_value = ...
            default_value;

        return;
    end


    warning( ...
        'build_output_folders:UnsupportedLogicalType', ...
        ['Type non pris en charge pour la conversion logique. ', ...
         'La valeur par défaut est utilisée.']);


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