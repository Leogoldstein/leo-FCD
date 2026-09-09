function visualize_data( ...
        selected_groups, ...
        automatic_selection, ...
        include_electroporated, ...
        results_table)

%VISUALIZE_DATA
%
% Génère les figures de synthèse et les figures individuelles à partir
% d'un ensemble de données déjà sélectionné.
%
% IMPORTANT :
% La séparation Development / Adult est effectuée AVANT l'appel à cette
% fonction.
%
% Les output folders ne sont plus fournis en argument.
%
% Ils sont récupérés directement depuis :
%
%   selected_groups.(type)(animal).paths.output_folders{m}
%
% Structure attendue :
%
%   ...\Summary plots\
%       <mode>\
%       Development|Adult\
%       line\
%       animal\
%       date
%
% Pour les figures par animal :
%
%   current_output_folders =
%       ...\Development|Adult\line\animal
%
% Pour les figures globales par type :
% le dossier commun aux paths.output_folders du type est utilisé.


    %==============================================================%
    % Types
    %==============================================================%
    type_names = ...
        fieldnames(selected_groups);


    valid_types = ...
        type_names( ...
            cellfun( ...
                @(type_name) ...
                    ~isempty(selected_groups.(type_name)), ...
                type_names));


    %==============================================================%
    % Rien à visualiser
    %==============================================================%
    if isempty(valid_types)

        fprintf( ...
            '[VISUALIZE] No valid experimental type, skipped.\n');

        return;
    end


    %==============================================================%
    % Output folders globaux par type
    %
    % Ils sont construits à partir de :
    %
    % selected_groups.(type)(k).paths.output_folders{m}
    %
    % plot_selected_groups_overview et
    % build_all_selected_DF_raster_summary utilisent encore une
    % cellule avec une entrée par type.
    %==============================================================%
    output_folders = ...
        build_visualization_output_folders( ...
            selected_groups, ...
            type_names);


    %==============================================================%
    % 1) Overview général et légende commune
    %==============================================================%
    [~, ~, ~, legend_table] = ...
        plot_selected_groups_overview( ...
            selected_groups, ...
            include_electroporated, ...
            automatic_selection, ...
            output_folders);


    %==============================================================%
    % 2) Summary global DF
    %==============================================================%
    build_all_selected_DF_raster_summary( ...
        selected_groups, ...
        automatic_selection, ...
        output_folders, ...
        include_electroporated);


    %==============================================================%
    % 3) Comparaison statistique entre types
    %
    % results_table est déjà filtré Development ou Adult.
    %==============================================================%
    % if any(automatic_selection) && ...
    %         ~include_electroporated && ...
    %         numel(valid_types) >= 2 && ...
    %         ~isempty(results_table)
    % 
    %     compare_groups_barplots( ...
    %         results_table, ...
    %         3, ...
    %         'gcamp_plane', ...
    %         legend_table);
    % end


    %==============================================================%
    % 4) Figures radar par type et âge
    %==============================================================%
    % plot_radar_metrics_by_type( ...
    %     selected_groups, ...
    %     include_electroporated, ...
    %     type_names, ...
    %     automatic_selection, ...
    %     output_folders);


    %==============================================================%
    % 5) Figures individuelles par animal
    %==============================================================%
    for t = 1:numel(type_names)

        current_type = ...
            type_names{t};


        %----------------------------------------------------------%
        % Aucun animal dans ce type après split
        %----------------------------------------------------------%
        if isempty( ...
                selected_groups.(current_type))

            continue;
        end


        current_automatic_selection = ...
            automatic_selection.(current_type);


        %----------------------------------------------------------%
        % Animaux
        %----------------------------------------------------------%
        animals = ...
            selected_groups.(current_type);


        for k = 1:numel(animals)

            animal_struct = ...
                animals(k);


            %======================================================%
            % results_analysis
            %======================================================%
            if ~isfield( ...
                    animal_struct, ...
                    'results_analysis') || ...
                    isempty(animal_struct.results_analysis)

                fprintf( ...
                    '%s | animal %d: no results_analysis, skip.\n', ...
                    current_type, ...
                    k);

                continue;
            end


            %======================================================%
            % Output folders du recording
            %======================================================%

            current_output_folders = ...
                animal_struct.paths.output_folders;

            %======================================================%
            % Dossier global de l'animal
            %
            % paths.output_folders{m}
            %     -> ...\animal\date
            %
            % current_output_folders
            %     -> ...\animal
            %======================================================%
            % current_output_folders = ...
            %     get_current_output_folders( ...
            %         current_output_folders);
            % 
            % 
            % if isempty(current_output_folders)
            % 
            %     warning( ...
            %         ['Unable to determine animal output folder ', ...
            %          'for %s - animal %s.'], ...
            %         current_type, ...
            %         string(animal_struct.animal));
            % 
            %     continue;
            % end
            % 
            % 
            % if exist(current_output_folders, 'dir') ~= 7
            % 
            %     mkdir( ...
            %         current_output_folders);
            % end


            %======================================================%
            % Informations
            %======================================================%
            fprintf('\n==============================\n');
            fprintf('Visualisation\n');
            fprintf('Type: %s\n', current_type);

            fprintf( ...
                'Animal %d / %d: %s\n', ...
                k, ...
                numel(animals), ...
                char(string(animal_struct.animal)));

            fprintf('==============================\n');


            %======================================================%
            % Extraire uniquement les variables nécessaires
            %======================================================%

            %------------------------------------------------------%
            % GCaMP output folders
            %------------------------------------------------------%
            gcamp_root_folders = ...
                animal_struct.paths.gcamp_root;

            gcamp_output_folders = ...
                animal_struct.paths.gcamp_output;


            %------------------------------------------------------%
            % Identité animal
            %------------------------------------------------------%
            current_line = ...
                animal_struct.line;


            current_animal = ...
                animal_struct.animal;


            %------------------------------------------------------%
            % Recordings
            %
            % Ces valeurs sont déjà filtrées par le split.
            %------------------------------------------------------%
            current_dates = ...
                animal_struct.dates;


            current_ages = ...
                animal_struct.ages;


            current_sampling_rates = ...
                animal_struct.metadata. ...
                    gcamp_plane. ...
                    SamplingRatePlane;


            %------------------------------------------------------%
            % Résultats
            %
            % results_analysis est lui aussi déjà filtré.
            %------------------------------------------------------%
            results_analysis = ...
                animal_struct.results_analysis;


            %======================================================%
            % Histogrammes GCaMP
            %
            % Cette fonction utilise directement les dossiers
            % GCaMP propres aux recordings.
            %======================================================%
            plot_gcamp_histograms( ...
                results_analysis, ...
                gcamp_output_folders, ...
                current_line, ...
                current_animal, ...
                current_dates, ...
                current_ages);


            %======================================================%
            % Recording metrics summary
            %======================================================%
            plot_recording_metrics_summary( ...
                results_analysis, ...
                current_automatic_selection, ...
                current_output_folders, ...
                gcamp_root_folders, ...
                current_line, ...
                current_animal, ...
                current_dates, ...
                current_ages);


            %======================================================%
            % Frequency comparison GCaMP / electroporated
            %======================================================%
            if include_electroporated

                plot_frequency_boxplot( ...
                    results_analysis, ...
                    current_automatic_selection, ...
                    current_output_folders, ...
                    gcamp_output_folders, ...
                    current_line, ...
                    current_animal, ...
                    current_dates, ...
                    current_ages);
            end


            %======================================================%
            % Representative traces by burst rate
            %======================================================%
            % plot_representative_traces_by_burst_rate( ...
            %     animal_struct.data, ...
            %     results_analysis, ...
            %     current_sampling_rates, ...
            %     current_type, ...
            %     current_output_folders, ...
            %     gcamp_output_folders, ...
            %     current_line, ...
            %     current_animal, ...
            %     include_electroporated);


            %======================================================%
            % Corrélations
            %======================================================%
            % plot_all_pairwise_corr_types( ...
            %     current_ages, ...
            %     results_analysis, ...
            %     gcamp_root_folders, ...
            %     current_animal);


            %======================================================%
            % Couplage fonctionnel
            %======================================================%
            % plot_functional_coupling( ...
            %     results_analysis, ...
            %     current_automatic_selection, ...
            %     current_output_folders, ...
            %     gcamp_output_folders, ...
            %     current_line, ...
            %     current_animal, ...
            %     current_dates, ...
            %     current_ages);
        end
    end
end


%% ========================================================================
% Build global visualization output folders
%
% Une entrée par type, compatible avec :
%
%   plot_selected_groups_overview
%   build_all_selected_DF_raster_summary
%
% Pour chaque type, on cherche le dossier commun à tous les
% paths.output_folders du type.
%
% Exemple :
%
%   ...\Adult\mtor41\2001\date1
%   ...\Adult\mtor41\2002\date2
%   ...\Adult\mtor42\2100\date3
%
% donne :
%
%   ...\Adult
%
% =========================================================================
function output_folders = ...
        build_visualization_output_folders( ...
            selected_groups, ...
            type_names)

    output_folders = ...
        cell(numel(type_names), 1);


    for t = 1:numel(type_names)

        current_type = ...
            type_names{t};


        current_groups = ...
            selected_groups.(current_type);


        all_output_paths = {};


        %==========================================================%
        % Collecter tous les output folders de ce type
        %==========================================================%
        for k = 1:numel(current_groups)

            current_group = ...
                current_groups(k);


            if ~isfield(current_group, 'paths') || ...
                    ~isstruct(current_group.paths) || ...
                    ~isfield( ...
                        current_group.paths, ...
                        'output_folders') || ...
                    isempty( ...
                        current_group.paths.output_folders)

                continue;
            end


            current_paths = ...
                current_group.paths.output_folders;


            if ~iscell(current_paths)

                current_paths = ...
                    {current_paths};
            end


            for m = 1:numel(current_paths)

                current_path = ...
                    current_paths{m};


                if isempty(current_path)
                    continue;
                end


                all_output_paths{end + 1, 1} = ...
                    char(string(current_path)); %#ok<AGROW>
            end
        end


        %==========================================================%
        % Aucun chemin
        %==========================================================%
        if isempty(all_output_paths)

            output_folders{t} = ...
                pwd;

            warning( ...
                ['No paths.output_folders found for type %s. ', ...
                 'Using pwd instead.'], ...
                current_type);

            continue;
        end


        %==========================================================%
        % Dossier commun
        %==========================================================%
        common_folder = ...
            find_common_folder( ...
                all_output_paths);


        %==========================================================%
        % Sécurité
        %
        % On ne veut pas que le dossier commun descende jusqu'au
        % dossier d'une date lorsqu'un seul animal/recording existe.
        %
        % Structure :
        %
        %   ...\Development|Adult\line\animal\date
        %
        % Pour une synthèse globale on remonte donc au minimum
        % de trois niveaux :
        %
        %   date   -> animal
        %   animal -> line
        %   line   -> Development|Adult
        %==========================================================%
        if numel(all_output_paths) == 1

            common_folder = ...
                all_output_paths{1};


            for level = 1:3

                parent_folder = ...
                    fileparts(common_folder);


                if isempty(parent_folder) || ...
                        strcmp(parent_folder, common_folder)

                    break;
                end


                common_folder = ...
                    parent_folder;
            end
        end


        if isempty(common_folder)

            output_folders{t} = ...
                pwd;

        else

            output_folders{t} = ...
                common_folder;
        end


        if exist(output_folders{t}, 'dir') ~= 7

            mkdir( ...
                output_folders{t});
        end
    end
end


%% ========================================================================
% Animal-level output folder
%
% paths.output_folders{m} :
%
%   ...\line\animal\date
%
% retourne :
%
%   ...\line\animal
%
% Si plusieurs dates sont présentes, le parent commun est utilisé.
% =========================================================================
function current_output_folders = ...
        get_current_output_folders( ...
            output_folders)

    current_output_folders = '';


    if isempty(output_folders)
        return;
    end


    if ~iscell(output_folders)

        output_folders = ...
            {output_folders};
    end


    animal_folders = {};


    for m = 1:numel(output_folders)

        current_folder = ...
            output_folders{m};


        if isempty(current_folder)
            continue;
        end


        current_folder = ...
            char(string(current_folder));


        %----------------------------------------------------------%
        % Enlever le niveau date
        %----------------------------------------------------------%
        current_animal_folder = ...
            fileparts(current_folder);


        if isempty(current_animal_folder)
            continue;
        end


        animal_folders{end + 1, 1} = ...
            current_animal_folder; %#ok<AGROW>
    end


    if isempty(animal_folders)
        return;
    end


    current_output_folders = ...
        find_common_folder( ...
            animal_folders);
end


%% ========================================================================
% Find common folder
%
% Retourne le dossier parent commun le plus profond.
% Fonction compatible avec des chemins Windows.
% =========================================================================
function common_folder = ...
        find_common_folder(paths)

    common_folder = '';


    if isempty(paths)
        return;
    end


    paths = ...
        paths(~cellfun(@isempty, paths));


    if isempty(paths)
        return;
    end


    %==============================================================%
    % Normaliser les séparateurs
    %==============================================================%
    normalized_paths = ...
        cell(size(paths));


    for i = 1:numel(paths)

        current_path = ...
            char(string(paths{i}));


        current_path = ...
            strrep( ...
                current_path, ...
                '/', ...
                filesep);


        while numel(current_path) > 3 && ...
                current_path(end) == filesep

            current_path(end) = [];
        end


        normalized_paths{i} = ...
            current_path;
    end


    %==============================================================%
    % Un seul chemin
    %==============================================================%
    if numel(normalized_paths) == 1

        common_folder = ...
            normalized_paths{1};

        return;
    end


    %==============================================================%
    % Commencer avec le premier chemin
    %==============================================================%
    candidate = ...
        normalized_paths{1};


    %==============================================================%
    % Remonter jusqu'à ce que tous les chemins soient contenus
    %==============================================================%
    while ~isempty(candidate)

        is_common = true;


        candidate_with_sep = ...
            [candidate, filesep];


        for i = 1:numel(normalized_paths)

            current_path = ...
                normalized_paths{i};


            same_folder = ...
                strcmpi( ...
                    current_path, ...
                    candidate);


            inside_folder = ...
                strncmpi( ...
                    current_path, ...
                    candidate_with_sep, ...
                    numel(candidate_with_sep));


            if ~same_folder && ...
                    ~inside_folder

                is_common = false;
                break;
            end
        end


        if is_common

            common_folder = ...
                candidate;

            return;
        end


        parent = ...
            fileparts(candidate);


        if isempty(parent) || ...
                strcmp(parent, candidate)

            break;
        end


        candidate = ...
            parent;
    end
end