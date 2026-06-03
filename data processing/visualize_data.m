function figs_by_type = visualize_data(selected_groups)

    if nargin < 1 || isempty(selected_groups)
        figs_by_type = struct();
        return;
    end

    type_names = fieldnames(selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        for k = 1:numel(selected_groups.(current_type))

            fprintf('\n==============================\n');
            fprintf('Visualisation\n');
            fprintf('Type: %s\n', current_type);
            fprintf('Animal %d / %d: %s\n', ...
                k, numel(selected_groups.(current_type)), ...
                char(string(selected_groups.(current_type)(k).animal_group)));
            fprintf('==============================\n');

            animal = selected_groups.(current_type)(k);

            gcamp_root_folders   = animal.paths.gcamp_root;
            current_animal_group = animal.animal_group;
            current_ages_group   = animal.ages;
            data                 = animal.data;
            results_analysis     = animal.results_analysis;

            plot_all_pairwise_corr_types( ...
                current_ages_group, ...
                data, ...
                gcamp_root_folders, ...
                current_animal_group);

            plot_frequency_boxplot( ...
                results_analysis, ...
                gcamp_root_folders, ...
                current_animal_group, ...
                current_ages_group);

            plot_gcamp_histograms( ...
                results_analysis, ...
                gcamp_root_folders, ...
                current_animal_group, ...
                current_ages_group);
        end
    end

    % ======================================================
    % Pooled basic metrics by type
    % ======================================================
    figs_by_type = plot_basic_metrics_by_type(selected_groups);
end