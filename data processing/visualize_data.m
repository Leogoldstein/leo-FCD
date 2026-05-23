function [selected_groups, results_analysis_all] = visualize_data(selected_groups, metadata_results)

% visualize_data
% Lance les analyses/visualisations pour chaque groupe sélectionné.
%
% Outputs
%   selected_groups       : structure mise à jour avec data et results_analysis
%   results_analysis_all  : cell array contenant les results_analysis par groupe

    nGroups = length(selected_groups);
    results_analysis_all = cell(nGroups, 1);

    for k = 1:nGroups

        fprintf('\n==============================\n');
        fprintf('Visualisation group %d / %d\n', k, nGroups);
        fprintf('Animal: %s\n', char(string(selected_groups(k).animal_group)));
        fprintf('==============================\n');

        gcamp_root_folders   = selected_groups(k).gcamp_root_folders;
        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        current_animal_group = selected_groups(k).animal_group;
        current_ani_path_group = selected_groups(k).animal_path;
        current_ages_group   = selected_groups(k).ages;
        current_xml_group    = selected_groups(k).xml_path;
        date_group_paths     = selected_groups(k).date_group_path;
        data                 = selected_groups(k).data;

        meta_tbl = metadata_results{k};

        % ======================================================
        % Sampling rate + synchronous frames
        % ======================================================
        [sampling_rate_group, synchronous_frames_group] = fill_sampling_and_sync_frames( ...
            gcamp_root_folders, current_xml_group, meta_tbl, 0.2);

        % ======================================================
        % Pairwise correlation
        % ======================================================
        data = load_or_process_corr_data( ...
            gcamp_root_folders, data);

        % ======================================================
        % SCEs
        % ======================================================
        data = load_or_process_sce_data( ...
            current_animal_group, date_group_paths, ...
            gcamp_root_folders, synchronous_frames_group, data);

        selected_groups(k).data = data;

        % ======================================================
        % Basic metrics
        % ======================================================
        results_analysis = compute_export_basic_metrics( ...
            gcamp_root_folders, ...
            data, ...
            sampling_rate_group, ...
            current_xml_group);

        results_analysis_all{k} = results_analysis;
        selected_groups(k).results_analysis = results_analysis;

        % ======================================================
        % Plots
        % ======================================================
        plot_basic_metrics_boxplots_by_age( ...
            current_ages_group, ...
            results_analysis, ...
            current_ani_path_group, ...
            current_animal_group);

        plot_frequency_boxplot( ...
            results_analysis, ...
            gcamp_root_folders, ...
            current_animal_group, ...
            current_ages_group);

        plot_all_pairwise_corr_types( ...
            current_ages_group, ...
            data, ...
            gcamp_root_folders, ...
            current_animal_group);

        plot_gcamp_histograms( ...
            results_analysis, ...
            gcamp_root_folders, ...
            current_animal_group, ...
            current_ages_group);

    end
end