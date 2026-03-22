%% Initialization

clear
setup_python_env()

processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
if strcmp(processing_choice1, '2')
    % If the answer is 'no', prompt for the second choice
    processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
else
    processing_choice2 = [];
end        

%% Preprocessing

[animal_date_list, selected_groups, metadata_results] = pipeline_for_data_preprocessing(processing_choice1, processing_choice2);


%%
%checking_choice1 = input('Do you want to check your data? (1/2): ', 's');
checking_choice1 = '2';
if strcmp(checking_choice1, '1')
    % If the answer is '1', prompt for the second choice
    checking_choice2 = input('Do you want to check:\n1 = gcamp\n2 = blue with gcamp\n3 = both\nChoice (1/2/3): ', 's');
else
    checking_choice2 = [];
end

%check_data = input('Do you want to analyse blue cells? (1/2): ', 's');
include_blue_cells = '2';

[selected_groups, daytime, results_analysis, plots_data, sampling_rate_group] = process_selected_group(selected_groups, metadata_results, checking_choice2, include_blue_cells);

% Processing and analysis
PathSave = 'D:\Imaging\Outputs\';
all_results = [];  % tableau de structures vide

%%
% Perform analyses 
% (in the loop = one recording per animal at a time, out of the loop =
% all the recordings of an animal at a time)
% selected_indices = select_animal_groups(selected_groups);
% for k = 1:length(selected_indices)
   

% Perform analyses for each group
for k = 1:length(selected_groups)
    current_animal_group   = selected_groups(k).animal_group;
    current_animal_type    = selected_groups(k).animal_type;       
    current_ani_path_group = selected_groups(k).path;
    current_dates_group    = selected_groups(k).dates;
    current_ages_group     = selected_groups(k).ages;
    gcamp_output_folders   = selected_groups(k).gcamp_output_folders;
    data                   = selected_groups(k).data;
    
    % Correlation analysis
    [max_corr_gcamp_gcamp, max_corr_gcamp_mtor, max_corr_mtor_mtor] = load_or_process_corr_data(gcamp_output_folders, data);

    plot_pairwise_corr(current_ages_group, ...
        max_corr_gcamp_gcamp, ...
        gcamp_output_folders, ...
        current_animal_group);

%     corr_groups_boxplots_corr(selected_groups, data.max_corr_gcamp_gcamp_by_plane, data.max_corr_gcamp_mtor_by_plane, data.max_corr_mtor_mtor_by_plane)
% 
%         % SCEs analysis
%         data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data);
%         selected_groups(k).data = data;
% 
        results_analysis = compute_export_basic_metrics(selected_groups, k, sampling_rate_group);
        
        plot_gcamp_histograms(results_analysis, gcamp_output_folders)

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
