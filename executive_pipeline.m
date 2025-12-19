%% Preprocessing

clear
setup_python_env()

processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
if strcmp(processing_choice1, '2')
    % If the answer is 'no', prompt for the second choice
    processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
else
    processing_choice2 = [];
end        

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
include_blue_cells = '1';

[selected_groups, daytime, results_analysis, plots_data] = process_selected_group(selected_groups, metadata_results, checking_choice2, include_blue_cells);

% Processing and analysis
PathSave = 'D:\Imaging\Outputs\';
all_results = [];  % tableau de structures vide


%% Perform analyses 
% (in the loop = one recording per animal at a time, out of the loop =
% all the recordings of an animal at a time)
% selected_indices = select_animal_groups(selected_groups);
% for k = 1:length(selected_indices)
  
% Perform analyses for each group
for k = 1:length(selected_groups)
    current_animal_group = selected_groups(k).animal_group;
    current_animal_type = selected_groups(k).animal_type;       
    current_ani_path_group = selected_groups(k).path;
    current_dates_group = selected_groups(k).dates;
    current_ages_group = selected_groups(k).ages;
    
    % Create paths for each date group
    date_group_paths = cell(length(current_dates_group), 1);  
    for l = 1:length(current_dates_group)
        date_path = fullfile(current_ani_path_group, current_dates_group{l});
        date_group_paths{l} = date_path;
    end

    current_gcamp_TSeries_path = selected_groups(k).pathTSeries(:, 1);
    current_blue_TSeries_path = selected_groups(k).pathTSeries(:, 3);

    if ~strcmp(current_animal_type, 'jm')
        current_gcamp_folders_group = selected_groups(k).Fallmat_folders(:, 1);
        current_red_folders_group   = selected_groups(k).Fallmat_folders(:, 2);
        current_blue_folders_group  = selected_groups(k).Fallmat_folders(:, 3);
        current_green_folders_group = selected_groups(k).Fallmat_folders(:, 4);
    
        current_gcamp_folders_names_group  = selected_groups(k).TSeries_folders_names(:, 1);
        current_red_folders_names_group    = selected_groups(k).TSeries_folders_names(:, 2);
        current_blue_folders_names_group   = selected_groups(k).TSeries_folders_names(:, 3);
        current_green_folders_names_group  = selected_groups(k).TSeries_folders_names(:, 4);
    else
        current_gcamp_folders_group = selected_groups(k).Fallmat_folders;
        current_red_folders_group   = cell(size(current_gcamp_folders_group));
        current_blue_folders_group  = cell(size(current_gcamp_folders_group));
        current_green_folders_group = cell(size(current_gcamp_folders_group));
    
        current_gcamp_folders_names_group = cell(size(current_gcamp_folders_group));
        current_red_folders_names_group   = cell(size(current_gcamp_folders_group));
        current_blue_folders_names_group  = cell(size(current_gcamp_folders_group));
        current_green_folders_names_group = cell(size(current_gcamp_folders_group));
    
        for l = 1:length(current_gcamp_TSeries_path)
            [~, lastFolderName] = fileparts(current_gcamp_TSeries_path{l});
            current_gcamp_folders_names_group{l} = lastFolderName;
    
            current_red_folders_group{l}   = [];
            current_blue_folders_group{l}  = [];
            current_green_folders_group{l} = [];
            current_red_folders_names_group{l}   = [];
            current_blue_folders_names_group{l}  = [];
            current_green_folders_names_group{l} = [];
        end
    end

    current_xml_group = selected_groups(k).xml;
    gcamp_output_folders = selected_groups(k).gcamp_output_folders;
    data = selected_groups(k).data; 
    numFolders = length(date_group_paths);
   
    % Explore traces gcamp
    % for m = 1:numFolders
    %          [~, baseline_gcamp, noise_est_gcamp, SNR_gcamp, valid_gcamp_cells, DF_gcamp, Raster_gcamp, Acttmp2_gcamp, MAct_gcamp, thresholds_gcamp] = peak_detection_tuner(data.F_gcamp{m}, data.sampling_rate{m}, data.synchronous_frames{m}, current_animal_group, current_ages_group{m}, 'nogui', false);
    % end
    % 
    % % Explore traces bleues
    % for m = 1:numFolders
    %      [~, baseline_blue, noise_est_blue, SNR_blue, valid_blue_cells, DF_blue, Raster_blue, Acttmp2_blue, StartEnd, MAct_blue, thresholds_blue] = peak_detection_tuner(data.F_blue{m}, data.sampling_rate{m}, data.synchronous_frames{m}, current_animal_group, current_ages_group{m}, 'nogui', false);
    % end

    % Correlation analysis
    data = load_or_process_corr_data(gcamp_output_folders, data);
    selected_groups(k).data = data;
    % plot_pairwise_corr(current_ages_group, data.max_corr_gcamp_gcamp, current_ani_path_group, current_animal_group)
    % corr_groups_boxplots_corr(selected_groups, data.max_corr_gcamp_gcamp, data.max_corr_gcamp_mtor, data.max_corr_mtor_mtor)

    % SCEs analysis
    data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data);
    selected_groups(k).data = data;

    for m = 1:numFolders
        plot_frequency_scatter( ...
            plots_data(m).freq_gcamp, ...
            plots_data(m).freq_blue, ...
            plots_data(m).folder_name, ...
            gcamp_output_folders{m});
    
        plot_amplitude_scatter( ...
            plots_data(m).amp_gcamp, ...
            plots_data(m).amp_blue, ...
            plots_data(m).folder_name, ...
            gcamp_output_folders{m});
        
        plot_duration_per_cell_boxplot( ...
            plots_data(m).dur_non, ...
            plots_data(m).dur_ele, ...
            plots_data(m).folder_name);
    end

    % Cluster analysis
 % data = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_xml_group, data);
 % selected_groups(k).data = data;
 % plot_assemblies(data, current_gcamp_folders_group, gcamp_output_folders);
 % plot_clusters_metrics(gcamp_output_folders, data, current_animal_group, current_dates_group);
        
    selected_groups(k).results_analysis = results_analysis;
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
