%% Choix du type
clearvars -except choices group_order selected_groups
clc

setup_python_env()

% Choix du type (jm, FCD, SHAM)
[choices, group_order] = choose_group_selection();

% Choix du ou des animaux
dataFolders_by_group = select_data_folders_by_group(choices, group_order);

if ~exist('selected_groups','var')
    selected_groups = [];
end
[selected_groups, animal_date_list] = folder_selection( ...
    choices, group_order, dataFolders_by_group, selected_groups);

selected_groups = create_data(selected_groups);

selected_groups = create_metadata(selected_groups);

%recap_all = create_summary_sheets(selected_gr0oups);

% Data processing
include_blue_cells = '1';
selected_groups = process_selected_groups(selected_groups, include_blue_cells);

selected_groups = DF_peak_detection(selected_groups, include_blue_cells);

%selected_groups = data_checking(selected_groups, include_blue_cells);

selected_groups = compute_DF(selected_groups, include_blue_cells);

%%plot_traces_sorted_by_burst_rate(selected_groups)
%%
% Data visualization (Grouped by layers)
figs_by_type = visualize_data(selected_groups);


%%

build_rasterplot_DF_random_traces(selected_groups)

    %%
corr_boxplots = corr_groups_boxplots_all(selected_groups); % correlation analysis required

%%
[grouped_data_by_age, barplots] = barplots_by_type(selected_groups); % SCEs analysis required

%%

figs = plot_by_type_no_age(selected_groups);
%%
figs = compare_groups_barplots(selected_groups, 4, 'gcamp_plane');

%%
figs = RasterChange_around_SCEs(selected_groups);
figs = FiringRateChange_around_SCEs(selected_groups);



%%
close all
create_ppt_from_figs(selected_groups, daytime)

%%
which isempty

%%

