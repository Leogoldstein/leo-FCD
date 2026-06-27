%% Choix du type
clearvars -except choices group_order animal_date_list selected_groups
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

%recap_all = create_summary_sheets(selected_groups);

% Data processing
include_blue_cells = '2';
selected_groups = process_selected_groups(selected_groups, include_blue_cells);

selected_groups = DF_peak_detection(selected_groups, include_blue_cells);

selected_groups = compute_DF(selected_groups);

%%
plot_traces_sorted_by_burst_rate(selected_groups)
%%
% Data visualization (Grouped by layers)
figs_by_type = visualize_data(selected_groups);





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

