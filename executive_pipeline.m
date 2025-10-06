%% Preprocessing

clear
close all

% % Définir le chemin vers Python dans l'environnement Suite2p
pyExec = "C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe";
%pyExec = "C:\Users\goldstein\AppData\Local\anaconda3\envs\cellpose\python.exe"; 

% Initialiser pyenv uniquement s’il n’est pas encore chargé
pe = pyenv;
if pe.Status == "NotLoaded"
    pyenv('Version', pyExec);
    fprintf("pyenv défini sur l’environnement\n");
else

    fprintf("Python déjà chargé depuis : %s\n", pe.Executable);
end

% Chemin où se trouve le fichier python_function.py
new_path = 'D:/local-repo/Python';

%Vérifiez si le chemin est déjà dans le sys.path Python, sinon l'ajouter
if count(py.sys.path, new_path) == 0
    insert(py.sys.path, int32(0), new_path);
end

[animal_date_list, selected_groups] = pipeline_for_data_preprocessing();
%
% env_paths_all = selected_groups.env;
% for idx = 1:length(env_paths_all)
%     [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(env_paths_all{idx});
%     disp(optical_zoom)
%     disp(position)
% end
%%
%processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
processing_choice1 = '1';
if strcmp(processing_choice1, '2')
    % If the answer is 'no', prompt for the second choice
    %processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
    processing_choice2 = '2';
else
    processing_choice2 = [];
end        

%checking_choice1 = input('Do you want to check your data? (1/2): ', 's');
checking_choice1 = '2';
if strcmp(checking_choice1, '1')
    % If the answer is '1', prompt for the second choice
    %checking_choice2 = input('Do you want to check:\n1 = gcamp\n2 = blue with gcamp\n3 = both\nChoice (1/2/3): ', 's');
    checking_choice2 = '1';
else
    checking_choice2 = [];
end 

%check_data = input('Do you want to analyse blue cells? (1/2): ', 's');
include_blue_cells = '2';

[selected_groups, daytime] = process_selected_group(selected_groups, processing_choice1, processing_choice2, checking_choice2, include_blue_cells);

% Processing and analysis
PathSave = 'D:\Imaging\Outputs\';
all_results = [];  % tableau de structures vide

% Perform analyses 
% (in the loop = one recording per animal at a time, out of the loop =
% all the recordings of an animal at a time)
for k = 1:length(selected_groups)
    current_animal_group = selected_groups(k).animal_group;
    current_animal_type = selected_groups(k).animal_type;
    current_ani_path_group = selected_groups(k).path;
    current_dates_group = selected_groups(k).dates;
    date_group_paths = cell(length(current_dates_group), 1);  % Store paths for each date
    for l = 1:length(current_dates_group)
        date_path = fullfile(current_ani_path_group, current_dates_group{l});
        date_group_paths{l} = date_path;
    end
    current_gcamp_TSeries_path = cellfun(@string, selected_groups(k).pathTSeries(:, 1), 'UniformOutput', false);

    if ~strcmp(current_animal_type, 'jm')
        current_gcamp_folders_group = selected_groups(k).folders(:, 1);            
        current_gcamp_folders_names_group = selected_groups(k).folders_names(:, 1);           
    else    
        current_gcamp_folders_group = selected_groups(k).folders;
        current_gcamp_folders_names_group = cell(1, length(current_gcamp_TSeries_path)); % Preallocate the cell array
        for l = 1:length(current_gcamp_TSeries_path)
            [~, lastFolderName] = fileparts(current_gcamp_TSeries_path{l}); % Extract last folder name               
            current_gcamp_folders_names_group{l} = lastFolderName; % Store the folder name at index l
        end
    end

    current_ages_group = selected_groups(k).ages;
    current_env_group = selected_groups(k).env; 
    gcamp_output_folders = selected_groups(k).gcamp_output_folders;
    data = selected_groups(k).data; 

    %plot_threshold_frequency_all_neurons(data.thresholds_gcamp, data.Acttmp2_gcamp, data.F_gcamp, data.sampling_rate, current_animal_group, current_ages_group)

    % Correlation analysis
    data = load_or_process_corr_data(gcamp_output_folders, data);
    selected_groups(k).data = data;
    % plot_pairwise_corr(current_ages_group, data.max_corr_gcamp_gcamp, current_ani_path_group, current_animal_group)
    % corr_groups_boxplots_corr(selected_groups, data.max_corr_gcamp_gcamp, data.max_corr_gcamp_mtor, data.max_corr_mtor_mtor)

    % SCEs analysis
    data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data);
    selected_groups(k).data = data;

    %Global analysis of activity
    pathexcel = [PathSave 'analysis.xlsx'];
    compute_export_basic_metrics(current_animal_group, data, gcamp_output_folders, current_env_group, current_gcamp_folders_names_group, current_ages_group, pathexcel, current_animal_type, daytime)

     % Cluster analysis
     % data = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_env_group, data);
     % selected_groups(k).data = data;
     % plot_assemblies(data, current_gcamp_folders_group, gcamp_output_folders);
     % plot_clusters_metrics(gcamp_output_folders, data, current_animal_group, current_dates_group);

end
%%
corr_boxplots = corr_groups_boxplots_all(selected_groups); % correlation analysis required

%%
[grouped_data_by_age, barplots] = barplots_by_type(selected_groups); % SCEs analysis required
%%
comparison_barplots = compare_groups_barplots(grouped_data_by_age); % several animal type required (jm, FCD, WT)
%%
figs = RasterChange_around_SCEs(selected_groups);
figs = FiringRateChange_around_SCEs(selected_groups);



%%
close all
create_ppt_from_figs(selected_groups, daytime)

%%
which kmeansopttest -all
which kmeansoptrnd -all
