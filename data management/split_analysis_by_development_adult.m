function [ ...
    selected_groups_development, ...
    selected_groups_adult, ...
    results_table_development, ...
    results_table_adult, ...
    output_folders_development, ...
    output_folders_adult ...
    ] = ...
    split_analysis_by_development_adult( ...
        selected_groups, ...
        results_table, ...
        output_folders)

%SPLIT_ANALYSIS_BY_DEVELOPMENT_ADULT
%
% Sépare les données calculées en deux périodes :
%
%   Development : âge <= P15
%   Adult       : âge >  P15
%
% Cette fonction doit être appelée après compute_DF afin que
% results_analysis soit déjà présent dans selected_groups.
%
% Entrées :
%
%   selected_groups
%   results_table
%   output_folders
%
% Sorties :
%
%   selected_groups_development
%   selected_groups_adult
%
%   results_table_development
%   results_table_adult
%
%   output_folders_development
%   output_folders_adult
%
% Les output folders deviennent :
%
%   output_folder\Development
%   output_folder\Adult


    %==============================================================%
    % Paramètre
    %==============================================================%
    development_max_age = 15;


    %==============================================================%
    % Initialisation
    %==============================================================%
    selected_groups_development = ...
        struct();

    selected_groups_adult = ...
        struct();


    %==============================================================%
    % Types
    %==============================================================%
    type_names = ...
        fieldnames(selected_groups);


    %==============================================================%
    % Boucle types
    %==============================================================%
    for t = 1:numel(type_names)

        current_type = ...
            type_names{t};


        animals = ...
            selected_groups.(current_type);


        development_animals = ...
            animals([]);

        adult_animals = ...
            animals([]);


        %==========================================================%
        % Animaux
        %==========================================================%
        for k = 1:numel(animals)

            animal_struct = ...
                animals(k);


            %------------------------------------------------------%
            % Vérifier les âges
            %------------------------------------------------------%
            if ~isfield( ...
                    animal_struct, ...
                    'ages') || ...
                    isempty(animal_struct.ages)

                fprintf( ...
                    ['%s | animal %d: no ages, ' ...
                     'excluded from Development/Adult split.\n'], ...
                    current_type, ...
                    k);

                continue;
            end


            current_ages = ...
                animal_struct.ages(:);


            nRec = ...
                numel(current_ages);


            %------------------------------------------------------%
            % Convertir les âges en valeurs numériques
            %------------------------------------------------------%
            age_values = ...
                nan( ...
                    nRec, ...
                    1);


            for m = 1:nRec

                age_values(m) = ...
                    parse_age_for_split( ...
                        current_ages{m});
            end


            %------------------------------------------------------%
            % Sélections
            %------------------------------------------------------%
            development_idx = ...
                isfinite(age_values) & ...
                age_values <= development_max_age;


            adult_idx = ...
                isfinite(age_values) & ...
                age_values > development_max_age;


            %======================================================%
            % Development
            %======================================================%
            if any(development_idx)

                animal_development = ...
                    subset_animal_recordings_for_age_split( ...
                        animal_struct, ...
                        development_idx, ...
                        nRec);


                development_animals(end + 1) = ...
                    animal_development; %#ok<AGROW>
            end


            %======================================================%
            % Adult
            %======================================================%
            if any(adult_idx)

                animal_adult = ...
                    subset_animal_recordings_for_age_split( ...
                        animal_struct, ...
                        adult_idx, ...
                        nRec);


                adult_animals(end + 1) = ...
                    animal_adult; %#ok<AGROW>
            end
        end


        %==========================================================%
        % Sauvegarder le type
        %==========================================================%
        selected_groups_development.(current_type) = ...
            development_animals;


        selected_groups_adult.(current_type) = ...
            adult_animals;
    end


    %==============================================================%
    % Séparer results_table
    %==============================================================%
    [ ...
        results_table_development, ...
        results_table_adult ...
    ] = ...
        split_results_table_by_age( ...
            results_table, ...
            development_max_age);


    %==============================================================%
    % Output folders
    %==============================================================%
    output_folders_development = ...
        append_age_folder( ...
            output_folders, ...
            'Development');


    output_folders_adult = ...
        append_age_folder( ...
            output_folders, ...
            'Adult');
end


%% ========================================================================
% Sous-sélection d'un animal
% =========================================================================
function animal_out = ...
    subset_animal_recordings_for_age_split( ...
        animal_in, ...
        keep_idx, ...
        nRec)

    animal_out = ...
        animal_in;


    %==============================================================%
    % Ages
    %==============================================================%
    if isfield( ...
            animal_out, ...
            'ages')

        animal_out.ages = ...
            subset_recording_indexed_value( ...
                animal_out.ages, ...
                keep_idx, ...
                nRec);
    end


    %==============================================================%
    % Dates
    %==============================================================%
    if isfield( ...
            animal_out, ...
            'dates')

        animal_out.dates = ...
            subset_recording_indexed_value( ...
                animal_out.dates, ...
                keep_idx, ...
                nRec);
    end


    %==============================================================%
    % Paths
    %==============================================================%
    if isfield( ...
            animal_out, ...
            'paths') && ...
            isstruct(animal_out.paths)

        path_fields = ...
            fieldnames( ...
                animal_out.paths);


        for f = 1:numel(path_fields)

            field_name = ...
                path_fields{f};


            value = ...
                animal_out.paths.(field_name);


            animal_out.paths.(field_name) = ...
                subset_recording_indexed_value( ...
                    value, ...
                    keep_idx, ...
                    nRec);
        end
    end


    %==============================================================%
    % Data
    %
    % data contient également de nombreux champs indexés
    % par recording :
    %
    %   motion
    %   stim
    %   gcamp_plane
    %   electroporated_plane
    %   ...
    %==============================================================%
    if isfield( ...
            animal_out, ...
            'data') && ...
            isstruct(animal_out.data)

        animal_out.data = ...
            subset_struct_recordings_for_age_split( ...
                animal_out.data, ...
                keep_idx, ...
                nRec);
    end


    %==============================================================%
    % Results analysis
    %==============================================================%
    if isfield( ...
            animal_out, ...
            'results_analysis') && ...
            isstruct(animal_out.results_analysis)

        animal_out.results_analysis = ...
            subset_struct_recordings_for_age_split( ...
                animal_out.results_analysis, ...
                keep_idx, ...
                nRec);
    end
end


%% ========================================================================
% Filtrage récursif d'une structure
% =========================================================================
function S_out = ...
    subset_struct_recordings_for_age_split( ...
        S_in, ...
        keep_idx, ...
        nRec)

    S_out = ...
        S_in;


    if isempty(S_in) || ...
            ~isstruct(S_in)

        return;
    end


    %==============================================================%
    % Cas struct array indexé directement par recording
    %==============================================================%
    if numel(S_in) == nRec && ...
            ~isscalar(S_in)

        S_out = ...
            S_in(keep_idx);

        return;
    end


    %==============================================================%
    % Structure scalaire
    %==============================================================%
    field_names = ...
        fieldnames(S_in);


    for f = 1:numel(field_names)

        field_name = ...
            field_names{f};


        value = ...
            S_in.(field_name);


        if isstruct(value)

            S_out.(field_name) = ...
                subset_struct_recordings_for_age_split( ...
                    value, ...
                    keep_idx, ...
                    nRec);

        else

            S_out.(field_name) = ...
                subset_recording_indexed_value( ...
                    value, ...
                    keep_idx, ...
                    nRec);
        end
    end
end


%% ========================================================================
% Filtrer une variable indexée par recording
% =========================================================================
function value_out = ...
    subset_recording_indexed_value( ...
        value_in, ...
        keep_idx, ...
        nRec)

    value_out = ...
        value_in;


    if isempty(value_in)
        return;
    end


    %==============================================================%
    % Cell
    %==============================================================%
    if iscell(value_in)

        %----------------------------------------------------------%
        % Vecteur de cellules :
        % une cellule par recording
        %----------------------------------------------------------%
        if isvector(value_in) && ...
                numel(value_in) == nRec

            value_out = ...
                value_in(keep_idx);

            return;
        end


        %----------------------------------------------------------%
        % Matrice :
        % première dimension = recordings
        %----------------------------------------------------------%
        if size(value_in, 1) == nRec

            value_out = ...
                value_in(keep_idx, :);

            return;
        end


        return;
    end


    %==============================================================%
    % String
    %==============================================================%
    if isstring(value_in)

        if isvector(value_in) && ...
                numel(value_in) == nRec

            value_out = ...
                value_in(keep_idx);

            return;
        end


        if size(value_in, 1) == nRec

            value_out = ...
                value_in(keep_idx, :);
        end

        return;
    end


    %==============================================================%
    % Numeric / logical
    %==============================================================%
    if isnumeric(value_in) || ...
            islogical(value_in)

        %----------------------------------------------------------%
        % Un vecteur ayant exactement nRec éléments est considéré
        % comme indexé par recording.
        %----------------------------------------------------------%
        if isvector(value_in) && ...
                numel(value_in) == nRec

            value_out = ...
                value_in(keep_idx);

            return;
        end


        %----------------------------------------------------------%
        % Première dimension = recording
        %----------------------------------------------------------%
        if ~isvector(value_in) && ...
                size(value_in, 1) == nRec

            value_out = ...
                value_in(keep_idx, :);

            return;
        end

        return;
    end


    %==============================================================%
    % Datetime
    %==============================================================%
    if isdatetime(value_in)

        if numel(value_in) == nRec

            value_out = ...
                value_in(keep_idx);
        end

        return;
    end
end


%% ========================================================================
% Séparation de results_table
% =========================================================================
function [ ...
    development_table, ...
    adult_table ...
    ] = ...
    split_results_table_by_age( ...
        results_table, ...
        development_max_age)

    development_table = ...
        results_table([],:);


    adult_table = ...
        results_table([],:);


    if isempty(results_table)
        return;
    end


    variable_names = ...
        results_table.Properties.VariableNames;


    %==============================================================%
    % AgeNumber disponible
    %==============================================================%
    if ismember( ...
            'AgeNumber', ...
            variable_names)

        age_values = ...
            double( ...
                results_table.AgeNumber);


    %==============================================================%
    % Sinon utiliser Age
    %==============================================================%
    elseif ismember( ...
            'Age', ...
            variable_names)

        age_values = ...
            nan( ...
                height(results_table), ...
                1);


        for i = 1:height(results_table)

            if iscell(results_table.Age)

                current_age = ...
                    results_table.Age{i};

            else

                current_age = ...
                    results_table.Age(i);
            end


            age_values(i) = ...
                parse_age_for_split( ...
                    current_age);
        end

    else

        warning( ...
            ['results_table has neither AgeNumber nor Age. ' ...
             'Unable to split results_table by age.']);

        return;
    end


    %==============================================================%
    % Development / Adult
    %==============================================================%
    development_idx = ...
        isfinite(age_values) & ...
        age_values <= development_max_age;


    adult_idx = ...
        isfinite(age_values) & ...
        age_values > development_max_age;


    development_table = ...
        results_table( ...
            development_idx, ...
            :);


    adult_table = ...
        results_table( ...
            adult_idx, ...
            :);
end


%% ========================================================================
% Output folders
% =========================================================================
function output_folders_out = ...
    append_age_folder( ...
        output_folders, ...
        folder_name)

    output_folders_out = ...
        output_folders;


    for t = 1:numel(output_folders)

        current_folder = ...
            output_folders{t};


        if isempty(current_folder)
            continue;
        end


        current_folder = ...
            fullfile( ...
                current_folder, ...
                folder_name);


        if exist( ...
                current_folder, ...
                'dir') ~= 7

            mkdir(current_folder);
        end


        output_folders_out{t} = ...
            current_folder;
    end
end


%% ========================================================================
% Age -> valeur numérique
% =========================================================================
function age_value = ...
    parse_age_for_split( ...
        age_raw)

    age_value = ...
        NaN;


    if isempty(age_raw)
        return;
    end


    %==============================================================%
    % Numeric
    %==============================================================%
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


    %==============================================================%
    % Cell
    %==============================================================%
    if iscell(age_raw)

        if ~isempty(age_raw)

            age_value = ...
                parse_age_for_split( ...
                    age_raw{1});
        end

        return;
    end


    %==============================================================%
    % Text
    %
    % P10 -> 10
    % P15 -> 15
    % P30 -> 30
    %==============================================================%
    age_text = ...
        char(string(age_raw));


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