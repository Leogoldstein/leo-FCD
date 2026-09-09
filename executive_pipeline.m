%% Choix du type
clearvars -except choices group_order selected_groups
clc
setup_python_env()

if ~exist('selected_groups','var')
    selected_groups = [];
end

% Choix du type (jm, FCD, SHAM)
[choices, group_order] = choose_group_selection();

% Choix du ou des animaux
[root_folders, dataFolders_by_group, include_electroporated, automatic_selection] = select_data_folders_by_group(choices, group_order);
%%
[selected_groups, animal_date_list] = folder_selection(choices, group_order, dataFolders_by_group, selected_groups, automatic_selection, include_electroporated);

selected_groups = create_data(selected_groups);

[selected_groups, metadata_table] = create_metadata(selected_groups);

recap_all = create_summary_sheets(selected_groups);

%% Data processing
selected_groups = process_selected_groups(selected_groups, include_electroporated, automatic_selection);
%%
selected_groups = DF_peak_detection(selected_groups, include_electroporated, automatic_selection);

[selected_groups, results_table] = compute_DF(selected_groups, include_electroporated);
%%
visualize_data(selected_groups, automatic_selection, include_electroporated, results_table);





%%
[grouped_data_by_age, barplots] = barplots_by_type(selected_groups); % SCEs analysis required
    %%
corr_boxplots = corr_groups_boxplots_all(selected_groups); % correlation analysis required

%%


%%

figs = plot_by_type_no_age(selected_groups);
%%


%%
figs = RasterChange_around_SCEs(selected_groups);
figs = FiringRateChange_around_SCEs(selected_groups);



%%
close all
create_ppt_from_figs(selected_groups, daytime)

%%
which isempty

%%

