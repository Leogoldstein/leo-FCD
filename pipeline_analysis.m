%% If you want to preprocess Jure's data (.npy files)

clearvars
initial_folder = '\\10.51.106.5\data\Data\jm\'; % folders where data are (this must end by animal id)
destinationFolder = 'D:/imaging/jm/'; 

dataFolders = select_folders(initial_folder);

[statPaths, FPaths, iscellPaths, opsPaths, canceledIndices] = find_npy_folders(dataFolders); % find folders with files required for analysis

[newFPaths, newStatPaths, newIscellPaths, newOpsPaths, truedataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, destinationFolder); % copy npy files in a destination folder

%% If you want to preporcess Leo data's (Fall.mat files)

clearvars
initial_folder = 'D:\imaging\FCD'; % folders where data are (this must end by animal id)

% If data are yet organized, skip this part
% dataFolders = select_folders(initial_folder);
%[truedataFolders] = organize_data_by_animal(dataFolders);

% Starting folder for selection
dataFolders = select_folders(initial_folder);
[truedataFolders, canceledIndices] = find_Fall_folders(dataFolders);

%% Create directories for saving with the present date

PathSave = 'D:/after_processing/Synchrony peaks/';
[daytime, directories, animal_date_list] = create_directories_for_analysis(truedataFolders, PathSave); % create directories for saving and save paths in path.mat

save_paths(truedataFolders,directories, newFPaths, newStatPaths, newIscellPaths, newOpsPaths)
%%

% Load datas (and save npy paths in paths.mat)

% % Chemin où se trouve le fichier python_function.py
% new_path = 'D:/analysis/mes codes/data processing';
% Vérifiez si le chemin est déjà dans le sys.path Python, sinon l'ajouter
% if count(py.sys.path, new_path) == 0
%     insert(py.sys.path, int32(0), new_path);
% end

[all_F, all_DF, all_ops, ~, ~] = load_and_preprocess_data(truedataFolders, newFPaths, newStatPaths, newIscellPaths, newOpsPaths);

                %%%%%%%%%%%%%%%%%%%%%% End of data preprocessing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Data processing

% Load settings
% Define the sampling rate and synchronous frames
MinPeakDistance = 5; % Example value, adjust based on your data characteristics
MinPeakDistancesce=3 ;
sampling_rate = 29.87373388; % already loaded in nwb
synchronous_frames = round(0.2 * sampling_rate); % 200ms *sampling rate
WinActive=[];%find(speed>1);
%sce_n_cells_threshold = 20;

kmean_iter = 100;
kmeans_surrogate = 100;
%%
[all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = raster_processing(all_DF, all_ops, MinPeakDistance, synchronous_frames, directories);

%If you want to retrieve datas
% clearvars
% PathSave = 'D:/after_processing/Synchrony peaks/FCD';
% [directories] = retrieve_results(PathSave);
% [all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, truedataFolders, all_data, animal_date_list, newStatPaths, newIscellPaths, newOpsPaths, validDirectories] = load_results(directories);
%%
process_data(all_DF, all_ops, all_isort1, all_MAct, animal_date_list) 

% % Compare rasters two by two
% %clearvars
% 
% % PathSave = 'D:/after_processing/Synchrony peaks/';
% % [directories_comp, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_prop_MAct, animal_date_list] = retrieve_and_load_results_for_comp(PathSave);
% % %[all_isort1, all_MAct, all_prop_MAct] = match_size_raster(all_isort1, all_DF, all_ops, all_Raster, synchronous_frames, all_MAct, all_prop_MAct);
% compare_rasterplots(all_DF, all_isort1, all_prop_MAct, directories_comp, animal_date_list)
% 

                       % %%%%%%%%%%%%%%%%%%%%% End of data processing %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%% Synchronies

[all_sce_n_cells_threshold, all_Race, all_RasterRace] = select_synchronies(directories, all_DF, MinPeakDistancesce, all_Raster, all_MAct, animal_date_list, synchronous_frames, WinActive);

%% Clustering
tic
[validDirectories, all_clusterMatrix, all_NClOK] = cluster_synchronies(directories, all_DF, all_MAct, all_Raster, all_Race, kmean_iter, kmeans_surrogate);
toc
% Plot clustering
%plot_valid_directories(validDirectories, animal_date_list, all_sce_n_cells_threshold, synchronous_frames)
clearvars -except validDirectories dataFolders newStatPaths newIscellPaths newOpsPaths canceledIndices

%% Distances between assemblies

% Choose which type of assembly to process
%[data_clust, assemblies, nbassemblies] = choose_assembly(validDirectories);

% Load data
[stat_list, iscell_list, ops_list] = load_data_mat_npy(truedataFolders, newStatPaths, newIscellPaths, newOpsPaths);

% Load calcium mask from suite2p (from Fall.mat) or npy files
[all_outline_gcampx, all_outline_gcampy, all_neuropil, all_Coomasqx, all_Coomasqy] = load_calcium_mask(truedataFolders, iscell_list, stat_list);

% generation of poly2mask (binary mask) for using regionprops and measure area and centroid
all_gcamp_props = process_poly2mask(truedataFolders, iscell_list, stat_list, all_outline_gcampx, all_outline_gcampy, directories);

% % Calculation distance centroid with gcamp only
% canceledIndices = [];
% [all_meandistance_gcamp, all_meandistance_assembly, all_mean_mean_distance_assembly] = distance_btw_centroid(truedataFolders, canceledIndices, all_gcamp_props, assemblies, validDirectories);
% 
% % Plot assemblies 
% plot_assemblies(truedataFolders, ops_list, assemblies, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly, validDirectories);

%% Evolution of the number of SCEs as a function of field size and number of neurons

% If you want to retrieve datas
clearvars
PathSave = 'D:/after_processing/Synchrony peaks/'; % change the last folder of the path
[directories] = retrieve_results(PathSave);
%%
[dataFolders, animal_date_list, newStatPaths, newIscellPaths, newOpsPaths, validDirectories, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race] = load_results(directories);
%%
num_samples = 10;
field_width_microm = 750;
sce_n_cells_threshold = 20;
fractions = [0.1, 0.25, 0.5, 0.75, 1];

% %plot_threshold_sce_evolution1(all_DF, directories, animal_date_list, fractions, NShfl, synchronous_frames, MinPeakDistance, MinPeakDistancesce)
plot_threshold_sce_evolution2(gcamp_mask, all_DF, all_MAct, animal_date_list, fractions, sce_n_cells_threshold, num_samples, field_width_microm, synchronous_frames, MinPeakDistance, MinPeakDistancesce, directories)

%%
fit_linear_model(directories, field_size_fraction, num_cells_fraction, num_SCEs, animal_date_list);





%% SCEs analysis
sampling_rate = 29.87373388;
SCEs_analysis(directories, all_DF, all_data, all_Race, all_Raster, sampling_rate, animal_date_list)
%% Clusters analysis
[num_clusters_list, all_cells_per_cluster] = clusters_analysis(directories, all_Raster, animal_date_list, all_data);

%%