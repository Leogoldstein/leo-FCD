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

for k = 1:length(selected_groups)
        gcamp_root_folders = selected_groups(k).gcamp_root_folders;
        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        current_animal_group   = selected_groups(k).animal_group;     
        current_ages_group     = selected_groups(k).ages;
        current_suite2p_group = selected_groups(k).suite2p_path;
        current_TSeries_group = selected_groups(k).TSeries_path;
        current_xml_group = selected_groups(k).xml_path;
        date_group_paths = selected_groups(k).date_group_path;
    
        meta_tbl = metadata_results{k};
        data = selected_groups(k).data;
    
        [sampling_rate_group, synchronous_frames_group] = fill_sampling_and_sync_frames( ...
            gcamp_root_folders, current_xml_group, meta_tbl, 0.2);
        
         meanImgs_gcamp = save_mean_images( ...
            'GCaMP', current_animal_group, current_ages_group, ...
            gcamp_output_folders, current_suite2p_group(:, 1));

        %===================%
        %   DF processing and peak detection
        %===================%
        % 
        % data = reset_detection_fields_in_data(data, numel(gcamp_output_folders));
        % clear_detection_outputs(gcamp_output_folders, {'gcamp','blue','combined'});

        data = run_gcamp_peak_detection( ...
            gcamp_output_folders, ...
            meta_tbl, ...
            sampling_rate_group, synchronous_frames_group, ...
            current_animal_group, current_ages_group, ...
            data, ...
            meanImgs_gcamp, ...
            current_TSeries_group(:, 1));
        
        selected_groups(k).data = data;

        %===================%
        %   Rasterplot
        %===================%
        build_rasterplot( ...
            data, gcamp_output_folders, current_animal_group, ...
            current_ages_group, sampling_rate_group);

end

%% Data visualization (concatenate planes)
PathSave = 'D:\Imaging\Outputs\';
all_results = [];  % tableau de structures vide
results_analysis_all = cell(length(selected_groups), 1);

% Perform analyses for each group
for k = 1:length(selected_groups)
    gcamp_root_folders = selected_groups(k).gcamp_root_folders;
    current_animal_group   = selected_groups(k).animal_group;
    current_animal_type    = selected_groups(k).animal_type;       
    current_ani_path_group = selected_groups(k).path;
    current_dates_group    = selected_groups(k).dates;
    current_ages_group     = selected_groups(k).ages;
    data     = selected_groups(k).data;

    % Compute basic metrcis
    results_analysis = compute_export_basic_metrics( ...
            current_animal_group, ...
            current_ages_group, ...
            gcamp_root_folders, ...
            data, ...
            sampling_rate_group);
    
    results_analysis_all{k} = results_analysis;

    plot_gcamp_histograms(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)

    plot_frequency_boxplot(results_analysis, gcamp_root_folders, current_animal_group, current_ages_group)

    plot_all_pairwise_corr_types( ...
        current_ages_group, ...
        data,...
        gcamp_root_folders, ...
        current_animal_group);

    plot_all_pairwise_corr_boxplots( ...
        current_ages_group, ...
        data, ...
        gcamp_root_folders, ...
        current_animal_group);


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

function clear_vars_in_matfile(filePath, vars_to_remove)

    if exist(filePath, 'file') ~= 2
        fprintf('Fichier absent, skip: %s\n', filePath);
        return;
    end

    S = load(filePath);
    removed_any = false;

    for k = 1:numel(vars_to_remove)
        fn = vars_to_remove{k};
        if isfield(S, fn)
            S = rmfield(S, fn);
            removed_any = true;
        end
    end

    if removed_any
        save(filePath, '-struct', 'S');
        fprintf('Champs supprimés de %s\n', filePath);
    else
        fprintf('Aucun champ à supprimer dans %s\n', filePath);
    end
end

function clear_detection_outputs(gcamp_output_folders, branches_to_clear)

    if nargin < 2 || isempty(branches_to_clear)
        branches_to_clear = {'gcamp','blue','combined'};
    end

    fields_detect_gcamp = { ...
        'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', ...
        'valid_gcamp_cells_by_plane', 'DF_gcamp_by_plane', ...
        'Raster_gcamp_by_plane', 'Acttmp2_gcamp_by_plane', ...
        'StartEnd_gcamp_by_plane', 'MAct_gcamp_by_plane', ...
        'thresholds_gcamp_by_plane', 'bad_segs_gcamp_plane', ...
        'opts_detection_gcamp_by_plane', ...
        'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', 'Sm_gcamp_by_plane' ...
    };

    fields_detect_blue = { ...
        'F0_blue_by_plane', 'noise_est_blue_by_plane', 'SNR_blue_by_plane', ...
        'valid_blue_cells_by_plane', 'DF_blue_by_plane', ...
        'Raster_blue_by_plane', 'Acttmp2_blue_by_plane', ...
        'StartEnd_blue_by_plane', 'MAct_blue_by_plane', ...
        'thresholds_blue_by_plane', 'bad_segs_blue_plane', ...
        'opts_detection_blue_by_plane', ...
        'isort1_blue_by_plane', 'isort2_blue_by_plane', 'Sm_blue_by_plane' ...
    };

    fields_detect_combined = { ...
        'F0_combined_by_plane', 'noise_est_combined_by_plane', ...
        'valid_combined_cells_by_plane', 'DF_combined_by_plane', ...
        'Raster_combined_by_plane', 'Acttmp2_combined_by_plane', ...
        'StartEnd_combined_by_plane', 'MAct_combined_by_plane', ...
        'thresholds_combined_by_plane', 'bad_segs_combined_plane', ...
        'opts_detection_combined_by_plane', ...
        'isort1_combined_by_plane', 'isort2_combined_by_plane', 'Sm_combined_by_plane' ...
    };

    for m = 1:numel(gcamp_output_folders)

        if isempty(gcamp_output_folders{m}) || ~iscell(gcamp_output_folders{m}) || isempty(gcamp_output_folders{m}{1})
            continue;
        end

        outdir_m = fileparts(gcamp_output_folders{m}{1});

        if ismember('gcamp', branches_to_clear)
            filePath = fullfile(outdir_m, 'results_gcamp.mat');
            clear_vars_in_matfile(filePath, fields_detect_gcamp);
        end

        if ismember('blue', branches_to_clear)
            filePath = fullfile(outdir_m, 'results_blue.mat');
            clear_vars_in_matfile(filePath, fields_detect_blue);
        end

        if ismember('combined', branches_to_clear)
            filePath = fullfile(outdir_m, 'results_combined.mat');
            clear_vars_in_matfile(filePath, fields_detect_combined);
        end
    end
end


function data = reset_detection_fields_in_data(data, numFolders)

    branches = { ...
        'gcamp_plane', { ...
            'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', ...
            'valid_gcamp_cells_by_plane', 'DF_gcamp_by_plane', ...
            'Raster_gcamp_by_plane', 'Acttmp2_gcamp_by_plane', ...
            'StartEnd_gcamp_by_plane', 'MAct_gcamp_by_plane', ...
            'thresholds_gcamp_by_plane', 'bad_segs_gcamp_plane', ...
            'opts_detection_gcamp_by_plane', ...
            'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', 'Sm_gcamp_by_plane' ...
        }; ...
        'blue_plane', { ...
            'F0_blue_by_plane', 'noise_est_blue_by_plane', 'SNR_blue_by_plane', ...
            'valid_blue_cells_by_plane', 'DF_blue_by_plane', ...
            'Raster_blue_by_plane', 'Acttmp2_blue_by_plane', ...
            'StartEnd_blue_by_plane', 'MAct_blue_by_plane', ...
            'thresholds_blue_by_plane', 'bad_segs_blue_plane', ...
            'opts_detection_blue_by_plane', ...
            'isort1_blue_by_plane', 'isort2_blue_by_plane', 'Sm_blue_by_plane' ...
        }; ...
        'combined_plane', { ...
            'F0_combined_by_plane', 'noise_est_combined_by_plane', ...
            'valid_combined_cells_by_plane', 'DF_combined_by_plane', ...
            'Raster_combined_by_plane', 'Acttmp2_combined_by_plane', ...
            'StartEnd_combined_by_plane', 'MAct_combined_by_plane', ...
            'thresholds_combined_by_plane', 'bad_segs_combined_plane', ...
            'opts_detection_combined_by_plane', ...
            'isort1_combined_by_plane', 'isort2_combined_by_plane', 'Sm_combined_by_plane' ...
        } ...
    };

    for b = 1:size(branches,1)
        branchName = branches{b,1};
        fieldsList = branches{b,2};

        if ~isfield(data, branchName)
            continue;
        end

        for f = 1:numel(fieldsList)
            fn = fieldsList{f};
            if isfield(data.(branchName), fn)
                tmp = cell(numFolders,1);
                [tmp{:}] = deal([]);
                data.(branchName).(fn) = tmp;
            end
        end
    end
end