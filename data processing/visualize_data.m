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
    [output_folders_type, output_folders_line] = ...
    build_visualization_output_folders( ...
        selected_groups, ...
        type_names);


    %==============================================================%
    % 1) Overview général et légende commune
    %==============================================================%
    % [~, ~, ~, legend_table] = ...
    %     plot_selected_groups_overview( ...
    %         selected_groups, ...
    %         include_electroporated, ...
    %         automatic_selection, ...
    %         output_folders_type);


    %==============================================================%
    % 2) Summary global DF
    %==============================================================%
    build_all_selected_DF_raster_summary( ...
        selected_groups, ...
        automatic_selection, ...
        output_folders_line, ...
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
    % 4) Figures violin par type et âge
    %==============================================================%
    plot_basic_metrics_by_line( ...
        selected_groups, ...
        include_electroporated, ...
        output_folders_line);

    %==============================================================%
    % 5) Figures radar par type et âge
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