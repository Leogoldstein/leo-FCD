function visualize_data( ...
        selected_groups, ...
        automatic_selection, ...
        include_electroporated, ...
        results_table, ...
        output_folders)

%VISUALIZE_DATA
%
% Génère les figures de synthèse et les figures individuelles à partir
% d'un ensemble de données déjà sélectionné.
%
% IMPORTANT :
% La séparation Development / Adult est effectuée AVANT l'appel à cette
% fonction avec split_analysis_by_development_adult.
%
% Par conséquent :
%   - selected_groups contient uniquement la période à analyser ;
%   - results_table contient uniquement cette même période ;
%   - output_folders pointe déjà vers :
%
%         ...\Development
%
%     ou
%
%         ...\Adult
%
% Cette fonction ne doit donc PAS ajouter elle-même de sous-dossier
% Development ou Adult.


    %==============================================================%
    % 1) Overview général et légende commune
    %==============================================================%
    [~, ~, ~, legend_table] = ...
        plot_selected_groups_overview( ...
            selected_groups, ...
            include_electroporated, ...
            automatic_selection, ...
            output_folders);
   
    %==============================================================
    % SUMMARY GLOBAL DF
    %==============================================================
    build_all_selected_DF_raster_summary( ...
        selected_groups, ...
        automatic_selection, ...
        output_folders, ...
        include_electroporated);

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
    % 2) Comparaison statistique entre types
    %
    % results_table est déjà filtré Development ou Adult.
    %==============================================================%
    if any(automatic_selection) && ...
            ~include_electroporated && ...
            numel(valid_types) >= 2 && ...
            ~isempty(results_table)

        compare_groups_barplots( ...
            results_table, ...
            3, ...
            'gcamp_plane', ...
            legend_table);
    end


    %==============================================================%
    % 3) Regrouper les métriques principales
    %
    % selected_groups est déjà filtré Development ou Adult.
    %==============================================================%
    [ ...
        grouped_by_type, ...
        ages_by_type, ...
        valid_type_names ...
    ] = ...
        collect_basic_metrics_by_type( ...
            selected_groups, ...
            include_electroporated);


    %==============================================================%
    % 4) Figures radar par type
    %==============================================================%
    if ~isempty(valid_type_names)

        %==========================================================%
        % Normalisation
        %
        % La normalisation est faite entre les types présents
        % DANS LA PÉRIODE ACTUELLE.
        %
        % Exemple :
        %
        %   appel Development :
        %       normalisation entre WT / SHAM / FCD Development
        %
        %   appel Adult :
        %       normalisation entre WT / SHAM / FCD Adult
        %==========================================================%
        if numel(valid_type_names) > 1

            global_maxima = ...
                compute_global_radar_maxima( ...
                    grouped_by_type, ...
                    valid_type_names);


            normalization_label = ...
                sprintf( ...
                    'Normalization across %s', ...
                    strjoin( ...
                        valid_type_names, ...
                        ' & '));


            types_filename_prefix = ...
                strjoin( ...
                    valid_type_names, ...
                    '_');

        else

            global_maxima = ...
                [];


            normalization_label = ...
                sprintf( ...
                    'Normalization within %s', ...
                    valid_type_names{1});


            types_filename_prefix = ...
                valid_type_names{1};
        end


        %==========================================================%
        % Une figure radar par type
        %==========================================================%
        for t = 1:numel(type_names)

            current_type = ...
                type_names{t};


            %------------------------------------------------------%
            % Type absent des données regroupées
            %------------------------------------------------------%
            if ~isfield( ...
                    grouped_by_type, ...
                    current_type)

                continue;
            end


            %------------------------------------------------------%
            % Vérifier output folder
            %------------------------------------------------------%
            if t > numel(output_folders) || ...
                    isempty(output_folders{t})

                warning( ...
                    'Missing output folder for type: %s', ...
                    current_type);

                continue;
            end


            current_output_folder = ...
                output_folders{t};


            if exist( ...
                    current_output_folder, ...
                    'dir') ~= 7

                mkdir( ...
                    current_output_folder);
            end


            %------------------------------------------------------%
            % Radar
            %
            % current_output_folder est déjà :
            %
            %   ...\Development
            %
            % ou
            %
            %   ...\Adult
            %------------------------------------------------------%
            make_all_metrics_figures_by_age( ...
                grouped_by_type.(current_type), ...
                ages_by_type.(current_type), ...
                current_output_folder, ...
                current_type, ...
                global_maxima, ...
                normalization_label, ...
                types_filename_prefix);
        end
    end


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


        %----------------------------------------------------------%
        % Vérifier output folder
        %----------------------------------------------------------%
        if t > numel(output_folders) || ...
                isempty(output_folders{t})

            warning( ...
                'Missing output folder for type: %s', ...
                current_type);

            continue;
        end


        current_output_folder = ...
            output_folders{t};


        if exist( ...
                current_output_folder, ...
                'dir') ~= 7

            mkdir( ...
                current_output_folder);
        end


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

            fprintf( ...
                'Output: %s\n', ...
                current_output_folder);

            fprintf('==============================\n');


            %======================================================%
            % Extraire uniquement les variables nécessaires
            %======================================================%

            %------------------------------------------------------%
            % Paths
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


            %------------------------------------------------------%
            % Résultats
            %
            % results_analysis est lui aussi déjà filtré.
            %------------------------------------------------------%
            results_analysis = ...
                animal_struct.results_analysis;


            %======================================================%
            % Figures nécessitant les cellules électroporées
            %======================================================%
            if include_electroporated

                %--------------------------------------------------%
                % Representative GCaMP / blue traces
                %--------------------------------------------------%
                plot_representative_gcamp_blue_traces( ...
                    animal_struct, ...
                    current_type, ...
                    current_output_folder);


                %--------------------------------------------------%
                % Frequency comparison GCaMP / mTOR
                %--------------------------------------------------%
                plot_frequency_boxplot( ...
                    results_analysis, ...
                    current_output_folder, ...
                    gcamp_output_folders, ...
                    current_line, ...
                    current_animal, ...
                    current_dates, ...
                    current_ages);
            end
        
            %--------------------------------------------------%
            % Mean images
            %--------------------------------------------------%
            save_mean_image_overviews( ...
                current_line, ...
                current_animal, ...
                current_dates, ...
                current_ages, ...
                gcamp_root_folders, ...
                current_output_folder, ...
                meanImgs_gcamp, ...
                alignedImgs_blue);

            %======================================================%
            % Representative traces by burst rate
            %======================================================%
            plot_representative_traces_by_burst_rate( ...
                animal_struct, ...
                current_type, ...
                gcamp_output_folders, ...
                include_electroporated);


            %======================================================%
            % Corrélations
            %
            % Les figures locales restent enregistrées dans les
            % gcamp_root_folders propres aux recordings.
            %======================================================%
            plot_all_pairwise_corr_types( ...
                current_ages, ...
                results_analysis, ...
                gcamp_root_folders, ...
                current_animal);


            %======================================================%
            % Couplage fonctionnel
            %
            % La figure de synthèse sera enregistrée dans
            % current_output_folder, donc directement dans
            % Development ou Adult.
            %======================================================%
            plot_functional_coupling( ...
                results_analysis, ...
                current_output_folder, ...
                gcamp_output_folders, ...
                current_line, ...
                current_animal, ...
                current_dates, ...
                current_ages);


            %======================================================%
            % Histogrammes GCaMP
            %======================================================%
            plot_gcamp_histograms( ...
                results_analysis, ...
                gcamp_root_folders, ...
                current_animal, ...
                current_ages);
        end
    end
end