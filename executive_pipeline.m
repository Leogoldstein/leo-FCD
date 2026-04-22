%% Choix du type

clear
setup_python_env()

% Choix du type (jm, FCD, SHAM)
[choices, group_order] = choose_group_selection();

%% Choix du ou des animaux
clearvars -except choices group_order animal_date_list
dataFolders_by_group = select_data_folders_by_group(choices, group_order);

%% Organisation des informations spécifiques

selected_groups = folder_selection(choices, group_order, dataFolders_by_group);

%% Gestion des dossiers de sorties

[selected_groups, gcamp_output_folders_all, gcamp_root_folders_all, daytime] = create_gcamp_output_folders(selected_groups);
selected_groups = create_data(selected_groups);
%%
metadata_results = save_metadata_results(selected_groups);

%% Data processing

%checking_choice1 = input('Do you want to check your data? (1/2): ', 's');
% checking_choice1 = '2';
% if strcmp(checking_choice1, '1')
%     % If the answer is '1', prompt for the second choice
%     checking_choice2 = input('Do you want to check:\n1 = gcamp\n2 = blue with gcamp\n3 = both\nChoice (1/2/3): ', 's');
% else
%     checking_choice2 = [];
% 
% end

%check_data = input('Do you want to analyse blue cells? (1/2): ', 's');
include_blue_cells = '1';
selected_groups = process_selected_groups(selected_groups, metadata_results, include_blue_cells);

%%
selected_groups = DF_peak_detection(selected_groups, metadata_results);

%% Data visualization (concatenate planes)
PathSave = 'D:\Imaging\Outputs\';
all_results = [];  % tableau de structures vide
results_analysis_all = cell(length(selected_groups), 1);

% Perform analyses for each group
for k = 1:length(selected_groups)
    gcamp_root_folders = selected_groups(k).gcamp_root_folders;
    gcamp_output_folders = selected_groups(k).gcamp_output_folders;
    current_animal_group   = selected_groups(k).animal_group;
    current_ani_path_group = selected_groups(k).animal_path;
    current_ages_group     = selected_groups(k).ages;
    current_suite2p_group = selected_groups(k).suite2p_path;
    current_TSeries_group = selected_groups(k).TSeries_path;
    current_xml_group = selected_groups(k).xml_path;
    date_group_paths = selected_groups(k).date_group_path;
    meta_tbl = metadata_results{k};
    data = selected_groups(k).data;

    [sampling_rate_group, synchronous_frames_group] = fill_sampling_and_sync_frames( ...
                gcamp_root_folders, current_xml_group, meta_tbl, 0.2);
    
    %===================%
    %   Pairwise correlation
    %===================%
    data = load_or_process_corr_data( ...
        gcamp_root_folders, data);

    %===================%
    %   SCEs
    %===================%
    data = load_or_process_sce_data( ...
        current_animal_group, date_group_paths, ...
        gcamp_root_folders, synchronous_frames_group, data);
    
    selected_groups(k).data = data;

    % Compute basic metrcis
    results_analysis = compute_export_basic_metrics( ...
            gcamp_root_folders, ...
            data, ...
            sampling_rate_group, ...
            current_xml_group);
    
    results_analysis_all{k} = results_analysis;

    [grouped_data_by_age, fig] = plot_basic_metrics_boxplots_by_age(current_ages_group, results_analysis, current_ani_path_group, current_animal_group);

    plot_frequency_boxplot(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)

    plot_all_pairwise_corr_types( ...
        current_ages_group, ...
        data,...
        gcamp_root_folders, ...
        current_animal_group);

    plot_gcamp_histograms(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)


%         % Cluster analysis
%      % data = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_xml_group, data);
%      % selected_groups(k).data = data;
%      % plot_assemblies(data, current_gcamp_folders_group, gcamp_output_folders);
%      % plot_clusters_metrics(gcamp_output_folders, data, current_animal_group, current_dates_group);
% 
%         selected_groups(k).results_analysis = results_analysis;
end
    %%
corr_boxplots = corr_groups_boxplots_all(selected_groups); % correlation analysis required

%%
[grouped_data_by_age, barplots] = barplots_by_type(selected_groups); % SCEs analysis required

%%

figs = plot_by_type_no_age(selected_groups);
%%
pooled_level = 2; % 1 = pas de pooling
comparison_barplots = compare_groups_barplots(grouped_data_by_age, pooled_level); % several animal type required (jm, FCD, WT)
%%
figs = RasterChange_around_SCEs(selected_groups);
figs = FiringRateChange_around_SCEs(selected_groups);



%%
close all
create_ppt_from_figs(selected_groups, daytime)

%%
which isempty

%%

