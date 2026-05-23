%% Choix du type

clear
setup_python_env()

% Choix du type (jm, FCD, SHAM)
[choices, group_order] = choose_group_selection();

%% Choix du ou des animaux
clearvars -except choices group_order animal_date_list
dataFolders_by_group = select_data_folders_by_group(choices, group_order);
selected_groups = folder_selection(choices, group_order, dataFolders_by_group);

%% Gestion des dossiers de sorties

[selected_groups, gcamp_output_folders_all, gcamp_root_folders_all, daytime] = create_gcamp_output_folders(selected_groups);
selected_groups = create_data(selected_groups);
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

[selected_groups, results_analysis_all] = visualize_data(selected_groups, metadata_results);














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

