function [selected_groups, results_analysis_all] = compute_DF(selected_groups, metadata_results)

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
        fprintf('Compute data from group %d / %d\n', k, nGroups);
        fprintf('Animal: %s\n', char(string(selected_groups(k).animal_group)));
        fprintf('==============================\n');

        gcamp_root_folders   = selected_groups(k).gcamp_root_folders;
        current_animal_group = selected_groups(k).animal_group;
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
            date_group_paths, ...
            data, ...
            sampling_rate_group, ...
            current_xml_group);

        results_analysis_all{k} = results_analysis;
    end
end