%% Choix du type
% clearvars -except choices group_order selected_groups
% clc
clear 
clc

setup_python_env()

% Choix du type (jm, FCD, SHAM)
[choices, group_order] = choose_group_selection();

% Choix du ou des animaux
[root_folders, dataFolders_by_group, include_blue_cells, automatic_selection] = select_data_folders_by_group(choices, group_order);

if ~exist('selected_groups','var')
    selected_groups = [];
end

[selected_groups, animal_date_list] = folder_selection( ...
    choices, group_order, dataFolders_by_group, selected_groups);

output_folders = build_output_folders(selected_groups, root_folders, automatic_selection, include_blue_cells);

selected_groups = create_data(selected_groups);

[selected_groups, metadata_table] = create_metadata(selected_groups);

%recap_all = create_summary_sheets(selected_gr0oups);

% Data processing
selected_groups = process_selected_groups(selected_groups, include_blue_cells);
%%
[selected_groups, output_folders] = DF_peak_detection(selected_groups, include_blue_cells, output_folders);

%%
%selected_groups = data_checking(selected_groups, include_blue_cells);

[selected_groups, results_table] = compute_DF(selected_groups, include_blue_cells);


%plot_traces_sorted_by_burst_rate(selected_groups)

%build_rasterplot_DF_random_traces(selected_groups)

%% Plots during adulthood
visualize_data(selected_groups, automatic_selection, include_blue_cells, results_table, output_folders);











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

